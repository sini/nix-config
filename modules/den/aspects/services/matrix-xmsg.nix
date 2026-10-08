# matrix-xmsg (github:sini/matrix-xmsg): the @genie support bot. It answers trusted
# mentions in its rooms by relaying them to an expert agent session over xmsg's
# HTTP bridge on loopback (anonymous sender; a system service cannot attest on
# agent.sock), so it runs on the host that runs xmsg.
#
# Trust follows kanidm: the IdP's `admins` group, routed here as `idm-users`
# (kanidm.nix → collect-idm-users), mapped to MXIDs as synapse-admins.nix does.
#
# The token is provisioned once by `matrix-bot-provision` (no generator). The
# service stays off until `rooms` names a room the bot has joined.
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
        type = lib.types.listOf (lib.types.strMatching "![^:]+:.+");
        default = [ ];
        example = [ "!abcdef:json64.dev" ];
        description = "Room IDs (not aliases) the bot serves. Empty keeps the service disabled; `matrix-bot-provision` prints the value.";
      };
      expertRef = lib.mkOption {
        type = lib.types.str;
        default = "genie-support";
        description = "xmsg session the bot relays to: a pi session registers under its cwd basename.";
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
        mxid = name: "@${name}:${environment.domain}";
        # The environment whose kanidm serves this host's (dev delegates to prod).
        idpEnv = (environment.services.kanidm or { }).delegateTo or null;
        trusted = lib.sort lib.lessThan (
          map (u: mxid u.name) (
            lib.filter (
              u:
              u.environment == (if idpEnv != null then idpEnv else environment.name)
              && lib.elem adminGroup u.groups
            ) idm-users
          )
        );
      in
      {
        imports = [ inputs.matrix-xmsg.nixosModules.default ];

        warnings = lib.optional (cfg.rooms == [ ]) ''
          matrix-xmsg: settings.services.matrix-xmsg.rooms is empty on ${host.name}, so the @genie bot is NOT enabled.
          Run `matrix-bot-provision '#support:${environment.domain}'` and set the room ID it prints.
        '';

        age.secrets = lib.mkIf (cfg.rooms != [ ]) {
          matrix-genie-token.rekeyFile = host.secretPath + "/matrix-genie-token.age";
        };

        services.matrix-xmsg = lib.mkIf (cfg.rooms != [ ]) {
          enable = true;
          package = inputs'.matrix-xmsg.packages.default;
          homeserverUrl = "https://${environment.getDomainFor "matrix"}";
          botMxid = mxid "genie";
          ownerMxid = mxid "json";
          accessTokenFile = config.age.secrets.matrix-genie-token.path;
          trustedMxids = trusted;
          inherit (cfg) rooms expertRef;
        };
      };
  };
}
