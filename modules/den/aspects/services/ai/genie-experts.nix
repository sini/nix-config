# genie-experts: genie-agent's expert tiers in local mode (plan GI-6): per tier, a
# headless herdr server (genie-herdr@<tier>) and the dispatcher (genie-dispatcher@<tier>)
# that registers `genie-expert-<tier>` on the owner's xmsg bus and spawns one Claude
# session per escalated thread. Tier 1 (genie-tier1) routes its escalations here.
#
# Both tiers run as the system owner; they differ in what is cloned in, not in edit
# rights (plan §5.2):
#   public   the clean public clones (genie-expert's genie-public-repos) and
#            genie-agent's support-memory/ (the module defaults)
#   trusted  the owner's checkouts and ~/.claude/memory, read-only sources
#
# Both tiers sign in with the owner's `claude setup-token` token from the experts'
# token pool (kubernetes/services/ai/genie-experts.nix), never with the owner's
# ~/.claude credentials (GI-13). genie-expert-token renders it, root-only under /run,
# as the EnvironmentFile systemd reads for each genie-herdr@<tier>.
#
# The owner's xmsg admits each dispatcher by its executable and watches each tier's
# session dir (mcp/xmsg.nix), both read off this host's services.genie-agent.
{
  den,
  lib,
  rootPath,
  ...
}:
let
  secret = "genie-expert-token";
  tokenSource = rootPath + "/.secrets/env/prod/genie-experts/trusted/owner.age";
  envFile = "/run/${secret}/env";
in
{
  den.aspects.services.ai.genie-experts = {
    includes = [ den.aspects.services.ai.genie-tier1 ];

    nixos =
      {
        host,
        config,
        inputs',
        pkgs,
        ...
      }:
      let
        home = config.users.users.${host.system-owner}.home;
        node = "${host.system-owner}.${host.name}";
        # agenix-rekey refuses a rekeyFile that is not in git.
        enabled = builtins.pathExists tokenSource;
        tier =
          name: extra:
          {
            address = "genie-expert-${name}@${node}";
            tokenEnvironmentFile = envFile;
          }
          // extra;

        # The pool holds the bare `claude setup-token` output; an already
        # env-formatted value is taken as is.
        render = pkgs.writeShellScript "genie-expert-token" ''
          set -eu
          umask 077
          t=$(tr -d '\r\n' < ${config.age.secrets.${secret}.path})
          t=''${t#CLAUDE_CODE_OAUTH_TOKEN=}
          printf 'CLAUDE_CODE_OAUTH_TOKEN=%s\n' "$t" > "$RUNTIME_DIRECTORY/env.tmp"
          mv "$RUNTIME_DIRECTORY/env.tmp" ${envFile}
        '';
      in
      {
        warnings = lib.optional (!enabled) ''
          genie-experts: the expert token ${toString tokenSource} is absent, so the expert tiers are NOT enabled on ${host.name} and tier 1 routes to genie-support.
        '';

        age.secrets = lib.mkIf enabled {
          ${secret} = {
            rekeyFile = tokenSource;
            owner = "root";
            group = "root";
            mode = "0400";
          };
        };

        services.genie-agent.experts = lib.mkIf enabled {
          enable = true;
          herdrPackage = inputs'.llm-agents.packages.herdr;
          claudePackage = inputs'.llm-agents.packages.claude-code;
          public = tier "public" { };
          trusted = tier "trusted" {
            reposDir = "${home}/Documents/repos/sini";
            memoryDir = "${home}/.claude/memory";
          };
        };

        # agenix decrypts at activation, before any unit starts.
        systemd.services = lib.mkIf enabled (
          {
            ${secret} = {
              description = "genie: the experts' Claude token as an EnvironmentFile";
              serviceConfig = {
                Type = "oneshot";
                RemainAfterExit = true;
                RuntimeDirectory = secret;
                RuntimeDirectoryMode = "0700";
                ExecStart = render;
              };
            };

            # The public sources are fetched by genie-expert's unit.
            "genie-dispatcher@public" = {
              after = [ "genie-public-repos.service" ];
              wants = [ "genie-public-repos.service" ];
            };
          }
          // lib.genAttrs [ "genie-herdr@public" "genie-herdr@trusted" ] (_: {
            after = [ "${secret}.service" ];
            requires = [ "${secret}.service" ];
          })
        );
      };
  };
}
