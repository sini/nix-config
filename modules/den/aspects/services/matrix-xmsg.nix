# matrix-xmsg (github:sini/matrix-xmsg): the @genie support bot. It answers trusted
# mentions in its rooms by relaying them to an expert agent session over xmsg's
# HTTP bridge on loopback (anonymous sender; a system service cannot attest on
# agent.sock), so it runs on the host that runs xmsg.
#
# Trust follows kanidm: the IdP's `admins` group, routed here as `idm-users`
# (kanidm.nix → collect-idm-users), mapped to MXIDs as matrix/mas.nix maps admins.
#
# The token comes from `agenix generate` (the synapse-bot-token generator
# registers @genie inside the Synapse pod); `matrix-bot-provision` then joins a
# room with it. The service stays off until `rooms` names a room the bot has
# joined.
{ inputs, lib, ... }:
let
  adminGroup = "admins";
in
{
  flake-file.inputs.matrix-xmsg = {
    url = "github:sini/matrix-xmsg";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  den.aspects.services.matrix-xmsg = {
    settings = {
      rooms = lib.mkOption {
        type = lib.types.listOf (lib.types.strMatching "![^:]+(:.+)?"); # room v12 IDs have no :server
        default = [ ];
        example = [ "!abcdef:json64.dev" ];
        description = "Room IDs (not aliases) the bot serves. Empty keeps the service disabled; `matrix-bot-provision` prints the value.";
      };
      expertRef = lib.mkOption {
        type = lib.types.str;
        default = "genie-support";
        description = "Label of the xmsg session the bot relays to, on this host's own node: the bot addresses it as `<label>@<user>.<host>`, so an unreachable peer never makes it `unavailable`.";
      };
      extraTrustedMxids = lib.mkOption {
        type = lib.types.listOf (lib.types.strMatching "@[^:]+:.+");
        default = [ ];
        example = [ "@alice:matrix.org" ];
        description = "Trusted senders beyond kanidm `admins`: accounts on other homeservers, which kanidm cannot list.";
      };
    };

    nixos =
      {
        config,
        environment,
        host,
        idm-users,
        inputs',
        ...
      }:
      let
        cfg = host.settings.services.matrix-xmsg;
        user = "sini";
        # The bus's own node name (xmsg README 7.0): both refs carry it, so a guard or an
        # expert of the same name elsewhere in view never makes them ambiguous.
        node = "${user}.${host.name}";
        mxid = name: "@${name}:${environment.domain}";
        # The environment whose kanidm serves this host's (dev delegates to prod).
        idpEnv = (environment.services.kanidm or { }).delegateTo or null;
        trusted = lib.sort lib.lessThan (
          lib.unique (
            cfg.extraTrustedMxids
            ++ map (u: mxid u.name) (
              lib.filter (
                u:
                u.environment == (if idpEnv != null then idpEnv else environment.name)
                && lib.elem adminGroup u.groups
              ) idm-users
            )
          )
        );
      in
      {
        imports = [ inputs.matrix-xmsg.nixosModules.default ];

        warnings = lib.optional (cfg.rooms == [ ]) ''
          matrix-xmsg: settings.services.matrix-xmsg.rooms is empty on ${host.name}, so the @genie bot is NOT enabled.
          Run `agenix generate` (once, for the token), then `matrix-bot-provision '#support:${environment.domain}'` and set the room ID it prints.
        '';

        # Declared before any room is set: the token must exist to join one.
        age.secrets.matrix-genie-token = {
          rekeyFile = host.secretPath + "/matrix-genie-token.age";
          generator.script = "synapse-bot-token";
          settings = {
            namespace = "matrix";
            workload = "deploy/synapse";
            user = "genie";
            secretsFile = "/secrets/secrets.yaml";
          };
        };

        services.matrix-xmsg = lib.mkIf (cfg.rooms != [ ]) {
          enable = true;
          package = inputs'.matrix-xmsg.packages.default;
          homeserverUrl = "https://${environment.getDomainFor "matrix"}";
          botMxid = mxid "genie";
          ownerMxid = mxid "json";
          accessTokenFile = config.age.secrets.matrix-genie-token.path;
          # The bot is the service matrix-xmsg on sini's own bus (owner, 2026-10-09): a socket client must run
          # as the bus's uid. /run/user/1000 exists under sini's lingering user manager; the bot
          # restarts until it does.
          dynamicUser = false;
          inherit user;
          xmsgSocket = "/run/user/1000/xmsg";
          trustedMxids = trusted;
          inherit (cfg) rooms;
          expertRef = "${cfg.expertRef}@${node}";
          # The pod's guard (kubernetes/services/ai/genie-guard.nix), a leaf of this
          # node: the send queues in its mailbox (hosts/bitstream.nix `leaves`). The
          # host guard keeps running as the standby: revert this line to return to it.
          guardRef = "genie-guard@genie-guard.genie";
        };
      };
  };
}
