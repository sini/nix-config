# genie-expert: the Opus tier of the @genie support bot. Claude Code runs as one
# OS user per sender tier, `genie-public` and `genie-trusted`, chosen by the
# sender's authenticated tier and never by a model. Neither holds any of the
# system owner's credentials: no wheel, no ssh login (so no forwarded agent), no
# gh/kube config, and no group that reaches the owner's files. Separate uids
# keep the tiers apart by construction: each has its own 0700 home and Claude
# state, and neither can reach the other's processes through /proc.
#
# Both see the owner's checkouts through read-only bind mounts under
# /var/lib/genie/repos; plain bind mounts keep the source permissions, so a
# file the owner keeps private stays unreadable. Each tier's instance,
# genie-expert@<tier>, mounts only its own memory view at /var/lib/genie/memory.
#
# The token is genie's own (a `claude setup-token` token, revocable alone),
# root-owned and read only by systemd for LoadCredential; the instance exports
# it as CLAUDE_CODE_OAUTH_TOKEN. The sandbox settings deny the tools a read of
# the secret, the credential directory and /proc/*/environ, and unset the
# variable for sandboxed commands.
#
# Attach with `sudo -u genie-<tier> tmux -S /run/genie-expert-<tier>/tmux.sock attach`.
{ lib, ... }:
let
  shared = "/var/lib/genie";
  secret = "genie-claude-token";
  tiers = [
    "public"
    "trusted"
  ];
  user = tier: "genie-${tier}";
  homeOf = tier: "/var/lib/${user tier}";
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
      description = "Checkouts under ~<system-owner>/Documents/repos/sini mounted read-only at /var/lib/genie/repos/<name> for both tiers. A missing one fails its mount unit without blocking boot.";
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

        # The memory view each tier sees at /var/lib/genie/memory: the owner's own
        # memory for trusted senders; for the public, the curated and pre-redacted
        # support-memory/ of the genie-agent checkout, admitted by a merged PR.
        # Each is bound only inside its own instance.
        views = {
          public = "${shared}/repos/genie-agent/support-memory";
          trusted = "${ownerHome}/.claude/memory";
        };

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
          # The same paths for Claude's own Read tool, which the sandbox does not wrap.
          permissions.deny = [
            "Read(/${tokenPath})"
            "Read(//run/agenix.d/**)"
            "Read(//run/credentials/**)"
            "Read(//proc/*/environ)"
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
        # The token slot as declared, readable whether or not the token exists yet
        # (age.secrets only carries it once it does); genie-expert-check.nix reads it.
        options.services.genie-expert.tokenSecret = lib.mkOption {
          internal = true;
          readOnly = true;
          type = lib.types.attrs;
          default = {
            rekeyFile = tokenFile;
            # Read only by systemd for LoadCredential, so no genie shell can read it.
            owner = "root";
            group = "root";
            mode = "0400";
          };
        };

        config = {
          users.groups = lib.genAttrs (map user tiers) (_: { });
          users.users = lib.listToAttrs (
            map (
              tier:
              lib.nameValuePair (user tier) {
                group = user tier;
                isSystemUser = true;
                useDefaultShell = true;
                home = homeOf tier;
                homeMode = "700";
                createHome = true;
                description = "@genie Opus expert, ${tier} tier";
              }
            ) tiers
          );

          services.openssh.settings.DenyUsers = map user tiers;

          warnings = lib.optional (!hasToken) ''
            genie-expert: ${secret}.age is absent on ${host.name}, so the expert service is NOT enabled.
            Mint a token with `claude setup-token`, then `agenix edit .secrets/hosts/${host.name}/${secret}.age`, `git add` it and `agenix rekey`.
          '';

          # The owner creates the value; nothing here generates it.
          age.secrets = lib.mkIf hasToken { ${secret} = config.services.genie-expert.tokenSecret; };

          fileSystems = lib.listToAttrs (
            map (
              name:
              lib.nameValuePair "${shared}/repos/${name}" (roBind "${ownerHome}/Documents/repos/sini/${name}")
            ) cfg.checkouts
          );

          assertions = [
            {
              assertion = lib.elem "genie-agent" cfg.checkouts;
              message = "genie-expert: the public tier's memory is genie-agent's support-memory/, so `checkouts` must include genie-agent.";
            }
          ];

          # The shared tree is root-owned: the tiers only read it.
          systemd.tmpfiles.rules = [
            "d ${shared} 0755 root root -"
            "d ${shared}/memory 0755 root root -"
          ]
          ++ map (tier: "L+ ${homeOf tier}/.claude/settings.json - - - - ${settings}") tiers;

          # Defined either way, enabled with the token, so the views stay checkable
          # (genie-expert-check.nix) before the owner has created it.
          systemd.services = {
            "genie-expert@" = {
              enable = hasToken;
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
                ExecStart = start;
                LoadCredential = "claude-token:${tokenPath}";
                ProtectHome = true;
                NoNewPrivileges = true;
                Restart = "on-failure";
              };
            };
          }
          // lib.listToAttrs (
            map (
              tier:
              lib.nameValuePair "genie-expert@${tier}" {
                overrideStrategy = "asDropin";
                enable = hasToken;
                wantedBy = [ "multi-user.target" ];
                # Here, not on the template: a drop-in's PATH replaces the template's.
                path = with pkgs; [
                  bubblewrap
                  socat
                  git
                  ripgrep
                  tmux
                ];
                serviceConfig = {
                  User = user tier;
                  Group = user tier;
                  RuntimeDirectory = "genie-expert-${tier}";
                  WorkingDirectory = homeOf tier;
                  BindReadOnlyPaths = [ "${views.${tier}}:${shared}/memory" ];
                };
              }
            ) tiers
          );
        };
      };

    persist.directories = map (tier: {
      directory = homeOf tier;
      user = user tier;
      group = user tier;
      mode = "0700";
    }) tiers;
  };
}
