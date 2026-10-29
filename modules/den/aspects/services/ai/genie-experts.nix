# genie-experts: genie-agent's expert tiers in local mode (plan GI-6): per tier, a
# headless herdr server (genie-herdr@<tier>) and the dispatcher (genie-dispatcher@<tier>)
# that registers `genie-expert-<tier>` on the owner's xmsg bus and spawns one Claude
# session per escalated thread. Tier 1 (genie-tier1) routes its escalations here.
#
# Both tiers run as the system owner with the owner's Claude credentials; they differ
# in what is cloned in, not in edit rights (plan §5.2):
#   public   the clean public clones (genie-expert's genie-public-repos) and
#            genie-agent's support-memory/ (the module defaults)
#   trusted  the owner's checkouts and ~/.claude/memory, read-only sources
#
# The owner's xmsg admits each dispatcher by its executable and watches each tier's
# session dir (mcp/xmsg.nix), both read off this host's services.genie-agent.
{ den, ... }:
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
        tier =
          name: extra:
          {
            address = "genie-expert-${name}@${node}";
          }
          // extra;
      in
      {
        services.genie-agent.experts = {
          enable = true;
          herdrPackage = inputs'.llm-agents.packages.herdr;
          claudePackage = inputs'.llm-agents.packages.claude-code;
          credentialsFile = "${home}/.claude/.credentials.json";
          public = tier "public" { };
          trusted = tier "trusted" {
            reposDir = "${home}/Documents/repos/sini";
            memoryDir = "${home}/.claude/memory";
          };
        };

        # The public sources are fetched by genie-expert's unit.
        systemd.services."genie-dispatcher@public" = {
          after = [ "genie-public-repos.service" ];
          wants = [ "genie-public-repos.service" ];
        };
      };
  };
}
