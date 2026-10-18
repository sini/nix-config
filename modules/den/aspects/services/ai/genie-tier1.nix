# genie-tier1: genie-agent's Tier 1 (github:sini/genie-agent, nixosModules.default), the
# composition root that answers @genie mentions routed to it (plan GI-5). It runs as
# the system owner and registers as the service `genie` on the owner's xmsg bus, beside
# the bot; matrix-xmsg routes rooms to it per room (services/matrix-xmsg.nix
# `roomRoutes`).
#
#   model      hyperqwen on cortex-cuda, keyed by the owner's hyperqwen-client secret,
#              loaded by systemd as a credential (never in the store)
#   guard-in   the pod guard, the bot's own (kubernetes/services/ai/genie-guard.nix);
#              the module's local genie-guard unit stays off, since the owner's bus
#              already serves `genie-guard` (mcp/xmsg.nix)
#   guard-out  on, against the same model
#   experts    genie-support until the expert tiers come up (GI-6)
{ inputs, ... }:
let
  stateDir = "/var/lib/genie-agent";
in
{
  den.aspects.services.ai.genie-tier1 = {
    nixos =
      { host, config, ... }:
      let
        owner = host.system-owner;
        home = config.users.users.${owner}.home;
        node = "${owner}.${host.name}";
      in
      {
        imports = [ inputs.genie-agent.nixosModules.default ];

        services.genie-agent = {
          enable = true;
          user = owner;
          xmsgSocket = "/run/user/${toString config.users.users.${owner}.uid}/xmsg";
          inherit stateDir;
          model = {
            baseUrl = "http://10.9.2.2:18020/v1";
            id = "qwen3.8-27b";
            keyFile = "${home}/.config/hyperqwen/api-key";
          };
          tier1.searxngUrl = host.settings.applications.dev.ai.mcp.searxng.endpoint;
          hindsightUrl = "http://10.11.0.20:8888";
          s3 = null;
          guardRef = "genie-guard@genie-guard.genie";
          experts = {
            public = "genie-support@${node}";
            trusted = "genie-support@${node}";
          };
        };

        # guard.enable also declares a local genie-guard unit; screening stays on, the
        # unit does not.
        systemd.services.genie-guard.enable = false;
      };

    persist =
      { host, ... }:
      {
        directories = [
          {
            directory = stateDir;
            user = host.system-owner;
            group = "users";
            mode = "0700";
          }
        ];
      };
  };
}
