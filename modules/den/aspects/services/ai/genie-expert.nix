# genie-expert: the Opus tier of the @genie support bot. Claude Code runs as the
# OS user `genie`, which holds none of the system owner's credentials: no wheel,
# no ssh login (so no forwarded agent), no gh/kube config, and no group that
# reaches the owner's files. It sees the owner's memory and checkouts only
# through read-only bind mounts in its own home; plain bind mounts keep the
# source permissions, so a file the owner keeps private stays unreadable.
#
# Its token is its own (`claude setup-token` as genie, revocable alone). It
# reaches the service as a systemd credential and is exported only into the
# expert's environment; the sandbox settings deny the tools a read of the
# secret, the credential directory and /proc/*/environ, and unset the variable
# for sandboxed commands.
#
# Attach with `sudo -u genie tmux -S /run/genie-expert/tmux.sock attach`.
{ lib, ... }:
let
  home = "/var/lib/genie";
  secret = "genie-claude-token";
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
        credential = "/run/credentials/genie-expert.service";
        tokenFile = host.secretPath + "/${secret}.age";
        # agenix-rekey refuses a rekeyFile that is not in git, so the secret and the
        # expert stay off until the owner has created it.
        hasToken = builtins.pathExists tokenFile;
        tokenPath = "${config.age.secretsDir}/${secret}";

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
              credential
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
            "Read(/${credential}/**)"
            "Read(//proc/*/environ)"
          ];
        };

        start = pkgs.writeShellScript "genie-expert-start" ''
          CLAUDE_CODE_OAUTH_TOKEN="$(< "$CREDENTIALS_DIRECTORY/claude-token")"
          export CLAUDE_CODE_OAUTH_TOKEN
          exec tmux -S "$RUNTIME_DIRECTORY/tmux.sock" new-session -d -s expert -c ${home} \
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

        fileSystems = {
          "${home}/memory" = roBind "${ownerHome}/.claude/memory";
        }
        // lib.listToAttrs (
          map (
            name: lib.nameValuePair "${home}/repos/${name}" (roBind "${ownerHome}/Documents/repos/sini/${name}")
          ) cfg.checkouts
        );

        systemd.tmpfiles.rules = [ "L+ ${home}/.claude/settings.json - - - - ${settings}" ];

        systemd.services.genie-expert = lib.mkIf hasToken {
          description = "genie: Claude Code Opus expert for @genie";
          wantedBy = [ "multi-user.target" ];
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          # The checkouts belong to another user, so git refuses them without this.
          environment = {
            GIT_CONFIG_COUNT = "1";
            GIT_CONFIG_KEY_0 = "safe.directory";
            GIT_CONFIG_VALUE_0 = "*";
          };
          path = with pkgs; [
            bubblewrap
            socat
            git
            ripgrep
            tmux
          ];
          serviceConfig = {
            Type = "forking";
            User = "genie";
            Group = "genie";
            ExecStart = start;
            LoadCredential = "claude-token:${tokenPath}";
            RuntimeDirectory = "genie-expert";
            WorkingDirectory = home;
            ProtectHome = true;
            NoNewPrivileges = true;
            Restart = "on-failure";
          };
        };
      };

    persist = {
      directories = [
        {
          directory = "${home}/.claude";
          user = "genie";
          group = "genie";
          mode = "0700";
        }
      ];
      files = [ "${home}/.claude.json" ];
    };
  };
}
