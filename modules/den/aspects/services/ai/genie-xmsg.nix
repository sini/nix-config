# genie-xmsg: one xmsg instance per genie tier, xmsg@public and xmsg@trusted, each
# the bus of its own OS user (xmsg/genie-agent-design.md §5.8 Topology; plan I16).
# xmsg serves HTTP only on $XDG_RUNTIME_DIR/xmsg/http.sock (0600, peer uid ==
# server uid) and binds no TCP without --listen/XMSG_LISTEN, so a process reaches
# only its own user's bus: the tier fence holds by construction. Neither tier
# instance may carry a TCP listen; an assertion refuses one at render time.
#
# The tier users have no login session, so no /run/user/<uid>. Each instance owns
# /run/xmsg-<tier> by RuntimeDirectory= (0700, the tier user, preserved across a
# restart so the units sharing it keep it); services.genie-xmsg.runtimeDir
# exports the path for the units that must set XDG_RUNTIME_DIR to it
# (genie-herdr@ and genie-dispatcher@, I10.2).
#
# Federation (fed ports, node keys, links) is typed data here, inert until xmsg
# ships its federation listener (X1): nothing below passes it to xmsg yet. Each
# node key is an `xmsg-identity` agenix secret owned by its tier user at 0400,
# declared once settings.nodeKeys is set (the owner then generates them).
{ lib, ... }:
let
  tiers = [
    "public"
    "trusted"
  ];
  user = tier: "genie-${tier}";
  homeOf = tier: "/var/lib/${user tier}";
  runtimeDir = tier: "/run/xmsg-${tier}";
  stateDir = tier: "/var/lib/xmsg-${tier}";
  keyName = tier: "xmsg-${user tier}";

  tierOptions = tier: {
    sessionsDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Claude session directories of every per-token config directory of the ${tier} tier (`--sessions-dir`, X7). Empty until I10.3 renders the token pool; xmsg then reads ~/.claude/sessions.";
    };
    svcTrustedExes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Executables trusted to register a `svc:` principal on this instance (the dispatcher, X9). Not rendered until X9 ships its flag.";
    };
    fedPort = lib.mkOption {
      type = lib.types.port;
      default = if tier == "public" then 7789 else 7790;
      description = "This node's federation listener port. Inert until X1.";
    };
  };

  link = lib.types.submodule {
    options = {
      from = lib.mkOption { type = lib.types.str; };
      to = lib.mkOption { type = lib.types.str; };
      allow = lib.mkOption {
        type = lib.types.listOf (
          lib.types.enum [
            "send"
            "reply"
            "list"
          ]
        );
      };
      principals = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
      };
    };
  };
in
{
  den.aspects.services.ai.genie-xmsg = {
    settings = lib.genAttrs tiers tierOptions // {
      nodeKeys = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Declare the tiers' federation node keys. agenix-rekey refuses to evaluate a declared key whose .age is absent, and `agenix generate` creates only declared ones, so set this, then run `agenix generate`, `git add` the .age and .crt files, and `agenix rekey`.";
      };
      ownerFedPort = lib.mkOption {
        type = lib.types.port;
        default = 7788;
        description = "The system owner's node's federation port on this host, held distinct from the tiers'. Inert until X1.";
      };
      links = lib.mkOption {
        type = lib.types.listOf link;
        # The federation plan's one link to genie@bitstream, re-cut per tier. No
        # link joins the tier nodes, or either of them to the owner's.
        default = map (tier: {
          from = "genie";
          to = "${user tier}@bitstream";
          allow = [ "send" ];
          principals = [ "svc:genie-expert" ];
        }) tiers;
        description = "xmsg-links edges into the tier nodes (federation plan §6.1). Inert until X1.";
      };
    };

    nixos =
      {
        config,
        environment,
        host,
        pkgs,
        ...
      }:
      let
        cfg = host.settings.services.ai.genie-xmsg;
        keySecret = tier: {
          rekeyFile = host.secretPath + "/${keyName tier}.age";
          generator.script = "xmsg-identity";
          settings = {
            node = "${user tier}@${host.name}";
            san = "${host.name}.ts.${environment.domain}";
          };
          owner = user tier;
          group = user tier;
          mode = "0400";
        };
        svc = tier: config.systemd.services."xmsg@${tier}";
        tcpFlag =
          tier:
          lib.any (s: lib.hasInfix "--listen" (toString (s.serviceConfig.ExecStart or ""))) [
            config.systemd.services."xmsg@"
            (svc tier)
          ]
          || (svc tier).environment ? XMSG_LISTEN
          || config.systemd.services."xmsg@".environment ? XMSG_LISTEN;
      in
      {
        options.services.genie-xmsg = {
          runtimeDir = lib.mkOption {
            internal = true;
            readOnly = true;
            type = lib.types.attrsOf lib.types.str;
            default = lib.genAttrs tiers runtimeDir;
            description = "XDG_RUNTIME_DIR of each tier's units.";
          };
          fedPorts = lib.mkOption {
            internal = true;
            readOnly = true;
            type = lib.types.attrsOf lib.types.port;
            default = {
              ${host.system-owner} = cfg.ownerFedPort;
            }
            // lib.listToAttrs (map (tier: lib.nameValuePair (user tier) cfg.${tier}.fedPort) tiers);
            description = "Each node's federation port on this host, by node user.";
          };
          # Readable whether or not the keys are declared; genie-xmsg-check.nix reads it.
          keySecrets = lib.mkOption {
            internal = true;
            readOnly = true;
            type = lib.types.attrsOf lib.types.attrs;
            default = lib.genAttrs tiers keySecret;
          };
        };

        config = {
          assertions = map (tier: {
            assertion = !tcpFlag tier;
            message = "genie-xmsg: xmsg@${tier} must bind no TCP (no --listen, no XMSG_LISTEN): its bus is reachable only by its own uid over http.sock.";
          }) tiers;

          warnings = lib.optional (!cfg.nodeKeys) ''
            genie-xmsg: settings.services.ai.genie-xmsg.nodeKeys is off on ${host.name}, so the tiers' federation node keys are NOT declared.
            Set it, then run `agenix generate`, `git add` the .age and .crt files, and `agenix rekey`.
          '';

          age.secrets = lib.mkIf cfg.nodeKeys (
            lib.listToAttrs (map (tier: lib.nameValuePair (keyName tier) (keySecret tier)) tiers)
          );

          systemd.services = {
            "xmsg@" = {
              description = "xmsg: the %i genie tier's bus";
              serviceConfig = {
                ExecStart = "${lib.getExe pkgs.local.xmsg} serve";
                Restart = "on-failure";
                ProtectSystem = "strict";
                ProtectHome = true;
                PrivateTmp = true;
                NoNewPrivileges = true;
              };
            };
          }
          // lib.listToAttrs (
            map (
              tier:
              lib.nameValuePair "xmsg@${tier}" {
                overrideStrategy = "asDropin";
                wantedBy = [ "multi-user.target" ];
                environment = {
                  HOME = homeOf tier;
                  XDG_RUNTIME_DIR = runtimeDir tier;
                  XMSG_DB_PATH = "${stateDir tier}/xmsg.db";
                }
                // lib.optionalAttrs (cfg.${tier}.sessionsDirs != [ ]) {
                  XMSG_SESSIONS_DIR = lib.concatStringsSep ":" cfg.${tier}.sessionsDirs;
                };
                serviceConfig = {
                  User = user tier;
                  Group = user tier;
                  RuntimeDirectory = lib.removePrefix "/run/" (runtimeDir tier);
                  RuntimeDirectoryMode = "0700";
                  RuntimeDirectoryPreserve = "yes";
                  StateDirectory = lib.removePrefix "/var/lib/" (stateDir tier);
                  StateDirectoryMode = "0700";
                };
              }
            ) tiers
          );
        };
      };

    # The reply store survives a reboot (root is wiped).
    persist.directories = map (tier: {
      directory = stateDir tier;
      user = user tier;
      group = user tier;
      mode = "0700";
    }) tiers;
  };
}
