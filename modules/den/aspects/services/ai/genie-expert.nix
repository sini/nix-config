# genie-expert: the Opus tier of the @genie support bot. Claude Code runs as the
# OS user `genie`, which holds none of the system owner's credentials: no wheel,
# no ssh login (so no forwarded agent), no gh/kube config, and no group that
# reaches the owner's files. It sees the owner's checkouts only through
# read-only bind mounts in its own home; plain bind mounts keep the source
# permissions, so a file the owner keeps private stays unreadable.
#
# One instance runs per sender tier, genie-expert@public and
# genie-expert@trusted, and each mounts only its own memory view (below).
#
# Its token is its own (`claude setup-token` as genie, revocable alone). It
# reaches the service as a systemd credential and is exported only into the
# expert's environment; the sandbox settings deny the tools a read of the
# secret, the credential directory and /proc/*/environ, and unset the variable
# for sandboxed commands.
#
# Attach with `sudo -u genie tmux -S /run/genie-expert-<tier>/tmux.sock attach`.
{ lib, ... }:
let
  home = "/var/lib/genie";
  secret = "genie-claude-token";
  supportMemory = "${home}/support-memory";
in
{
  den.aspects.services.ai.genie-expert = {
    settings.checkouts = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "[A-Za-z0-9._-]+");
      default = [
        "den-ag-design"
        "xmsg"
        "matrix-xmsg"
        "genie-agent"
        "genx"
        "gen"
        "gen-algebra"
        "gen-aspects"
        "gen-assemble"
        "gen-bind"
        "gen-class"
        "gen-delivery"
        "gen-demand"
        "gen-demo"
        "gen-differential"
        "gen-dispatch"
        "gen-edge"
        "gen-flake"
        "gen-graph"
        "gen-harness"
        "gen-identity"
        "gen-inspect"
        "gen-link"
        "gen-lsp"
        "gen-memo"
        "gen-merge"
        "gen-pipe"
        "gen-prelude"
        "gen-product"
        "gen-program"
        "gen-progress-report-v1"
        "gen-rebuild"
        "gen-resolve"
        "gen-rules"
        "gen-schema"
        "gen-scope"
        "gen-select"
        "gen-settings"
        "gen-types"
        "gen-vars"
        "gen-view"
      ];
      description = "Checkouts under ~<system-owner>/Documents/repos/sini mounted read-only at ~genie/repos/<name>. A missing one fails its mount unit without blocking boot.";
    };

    nixos =
      {
        config,
        host,
        inputs',
        pkgs,
        ...
      }:
      let
        cfg = host.settings.services.ai.genie-expert;
        ownerHome = "/home/${host.system-owner}";
        tokenFile = host.secretPath + "/${secret}.age";
        # agenix-rekey refuses a rekeyFile that is not in git, so the secret and the
        # expert stay off until the owner has created it.
        hasToken = builtins.pathExists tokenFile;
        tokenPath = "${config.age.secretsDir}/${secret}";

        # The memory view each tier sees at ~genie/memory, picked by the sender's
        # authenticated tier: the owner's own memory for trusted senders, the
        # curated and pre-redacted support memory for the public. Each view is
        # mounted only inside its own instance, never on the host, so no session
        # can see both.
        views = {
          public = supportMemory;
          trusted = "${ownerHome}/.claude/memory";
        };
        tierDir = tier: "${home}/tiers/${tier}";

        roBind = src: {
          device = src;
          fsType = "none";
          options = [
            "bind"
            "ro"
            "nofail"
          ];
          # The sources are themselves impermanence bind mounts.
          depends = [ src ];
        };

        settings = (pkgs.formats.json { }).generate "genie-claude-settings.json" {
          sandbox = {
            enabled = true;
            allowUnsandboxedCommands = false;
            filesystem.denyRead = [
              tokenPath
              "/run/agenix.d"
              "/run/credentials"
              "/proc/*/environ"
            ];
            credentials.envVars = [
              {
                name = "CLAUDE_CODE_OAUTH_TOKEN";
                mode = "deny";
              }
            ];
          };
          # Claude's own tools run outside the sandbox. All of /proc is denied to
          # them: /proc/<pid>/root of the other tier's expert, same uid, would
          # reach that tier's mount namespace.
          permissions.deny = [
            "Read(/${tokenPath})"
            "Read(//run/agenix.d/**)"
            "Read(//run/credentials/**)"
            "Read(//proc/**)"
          ];
        };

        start = pkgs.writeShellScript "genie-expert-start" ''
          CLAUDE_CODE_OAUTH_TOKEN="$(< "$CREDENTIALS_DIRECTORY/claude-token")"
          export CLAUDE_CODE_OAUTH_TOKEN
          exec tmux -S "$RUNTIME_DIRECTORY/tmux.sock" new-session -d -s expert \
            ${lib.getExe inputs'.llm-agents.packages.claude-code}
        '';
      in
      {
        users.groups.genie = { };
        users.users.genie = {
          group = "genie";
          isSystemUser = true;
          useDefaultShell = true;
          inherit home;
          createHome = true;
          description = "@genie Opus expert";
        };

        services.openssh.settings.DenyUsers = [ "genie" ];

        warnings = lib.optional (!hasToken) ''
          genie-expert: ${secret}.age is absent on ${host.name}, so the expert service is NOT enabled.
          As genie run `claude setup-token`, then `agenix edit .secrets/hosts/${host.name}/${secret}.age`, `git add` it and `agenix rekey`.
        '';

        # The owner creates the value; nothing here generates it.
        age.secrets = lib.mkIf hasToken {
          ${secret} = {
            rekeyFile = tokenFile;
            owner = "genie";
            group = "genie";
            mode = "0400";
          };
        };

        fileSystems = lib.listToAttrs (
          map (
            name: lib.nameValuePair "${home}/repos/${name}" (roBind "${ownerHome}/Documents/repos/sini/${name}")
          ) cfg.checkouts
        );

        # Each tier keeps its own Claude state, so a public session cannot read a
        # trusted session's transcripts. The support memory is root-owned: genie
        # reads it, a later curation unit writes it.
        systemd.tmpfiles.rules = [
          "d ${supportMemory} 0755 root root -"
          "d ${home}/memory 0755 root root -"
        ]
        ++ lib.concatMap (tier: [
          "d ${tierDir tier} 0700 genie genie -"
          "d ${tierDir tier}/claude 0700 genie genie -"
          "L+ ${tierDir tier}/claude/settings.json - - - - ${settings}"
        ]) (lib.attrNames views);

        systemd.services = lib.mkIf hasToken (
          {
            "genie-expert@" = {
              description = "genie: Claude Code Opus expert for @genie, %i tier";
              after = [ "network-online.target" ];
              wants = [ "network-online.target" ];
              # The checkouts belong to another user, so git refuses them without this.
              environment = {
                GIT_CONFIG_COUNT = "1";
                GIT_CONFIG_KEY_0 = "safe.directory";
                GIT_CONFIG_VALUE_0 = "*";
              };
              serviceConfig = {
                Type = "forking";
                User = "genie";
                Group = "genie";
                ExecStart = start;
                LoadCredential = "claude-token:${tokenPath}";
                ProtectHome = true;
                NoNewPrivileges = true;
                Restart = "on-failure";
              };
            };
          }
          // lib.mapAttrs' (
            tier: view:
            lib.nameValuePair "genie-expert@${tier}" {
              overrideStrategy = "asDropin";
              # Here, not on the template: a drop-in's PATH replaces the template's.
              path = with pkgs; [
                bubblewrap
                socat
                git
                ripgrep
                tmux
              ];
              wantedBy = [ "multi-user.target" ];
              environment.CLAUDE_CONFIG_DIR = "${tierDir tier}/claude";
              serviceConfig = {
                RuntimeDirectory = "genie-expert-${tier}";
                WorkingDirectory = tierDir tier;
                BindReadOnlyPaths = [ "${view}:${home}/memory" ];
                InaccessiblePaths = map tierDir (lib.remove tier (lib.attrNames views));
              };
            }
          ) views
        );
      };

    persist = {
      directories = [
        {
          directory = "${home}/tiers";
          user = "genie";
          group = "genie";
          mode = "0700";
        }
        {
          directory = supportMemory;
          user = "root";
          group = "root";
          mode = "0755";
        }
      ];
    };
  };
}
