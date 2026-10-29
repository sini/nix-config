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
# Each tier signs in with its own `claude setup-token` token, a root-only agenix secret
# systemd reads as an EnvironmentFile (GI-13); no tier sees the owner's ~/.claude
# credentials. Until both secrets exist the tiers stay off and tier 1 keeps routing
# to genie-support.
#
# The owner's xmsg admits each dispatcher by its executable and watches each tier's
# session dir (mcp/xmsg.nix), both read off this host's services.genie-agent.
{ den, lib, ... }:
let
  tiers = [
    "public"
    "trusted"
  ];
  secret = tier: "genie-expert-${tier}-token";
in
{
  den.aspects.services.ai.genie-experts = {
    includes = [ den.aspects.services.ai.genie-tier1 ];

    nixos =
      {
        host,
        config,
        inputs',
        ...
      }:
      let
        home = config.users.users.${host.system-owner}.home;
        node = "${host.system-owner}.${host.name}";
        tokenFile = tier: host.secretPath + "/${secret tier}.age";
        # agenix-rekey refuses a rekeyFile that is not in git, so both tiers wait for
        # the owner to create both tokens.
        missing = lib.filter (tier: !builtins.pathExists (tokenFile tier)) tiers;
        enabled = missing == [ ];
        tier =
          name: extra:
          {
            address = "genie-expert-${name}@${node}";
            tokenEnvironmentFile = config.age.secrets.${secret name}.path;
          }
          // extra;
      in
      {
        warnings = lib.optional (!enabled) ''
          genie-experts: ${
            lib.concatMapStringsSep ", " (t: "${secret t}.age") missing
          } absent on ${host.name}, so the expert tiers are NOT enabled and tier 1 routes to genie-support.
          For each tier, mint a token with `claude setup-token`, then `agenix edit .secrets/hosts/${host.name}/<name>.age` with the one line `CLAUDE_CODE_OAUTH_TOKEN=<token>`, `git add` it and `agenix rekey`.
        '';

        # The owner creates the values; nothing here generates them.
        age.secrets = lib.mkIf enabled (
          lib.genAttrs (map secret tiers) (name: {
            rekeyFile = host.secretPath + "/${name}.age";
            owner = "root";
            group = "root";
            mode = "0400";
          })
        );

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

        # The public sources are fetched by genie-expert's unit.
        systemd.services."genie-dispatcher@public" = lib.mkIf enabled {
          after = [ "genie-public-repos.service" ];
          wants = [ "genie-public-repos.service" ];
        };
      };
  };
}
