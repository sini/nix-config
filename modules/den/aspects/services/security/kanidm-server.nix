# kanidmd alone: the patched package, the server, its TLS and replication
# identity, and its database. services.security.kanidm adds what only the
# writer runs (provisioning, migrations, mail, nginx, served names); a replica
# includes this aspect alone, so it emits no served-domains or idm-users records
# and stays out of DNS and the gateway until it is routed explicitly.
{ den, lib, ... }:
let
  replicationPort = 8445; # 8444 is nginx's PROXY listener on uplink
  settingOf = h: lib.attrByPath [ "settings" "services" "security" "kanidm-server" ] { } h;
  # A node's replication identity, committed as PEM (`kanidmd
  # show-replication-certificate` prints its DER as unpadded base64url).
  certFile = h: h.secretPath + "/kanidm-replication.crt";
  partnerCert =
    h:
    let
      pem = lib.filter (l: l != "" && !(lib.hasPrefix "-----" l)) (
        lib.splitString "\n" (builtins.readFile (certFile h))
      );
    in
    lib.replaceStrings [ "+" "/" "=" ] [ "-" "_" "" ] (lib.concatStrings pem);
in
{
  den.aspects.services.security.kanidm-server = {
    includes = [ den.aspects.services.security.acme ];

    settings.replication = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable kanidm replication: kanidmd generates its replication identity
        certificate and listens on the host's default address, port
        ${toString replicationPort}. Its partners are every other host of the
        environment with replication on and a committed
        `.secrets/hosts/<host>/kanidm-replication.crt`, all mutual-pull.
      '';
    };

    settings.refreshFrom = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "uplink";
      description = ''
        The partner whose database replaces this node's when their databases
        diverge (kanidm's automatic_refresh): set on a joining node, toward the
        primary. Never on the primary itself, and never on the writer.
      '';
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
        domain = environment.getDomainFor "kanidm";
        # A host with nginx reuses its environment wildcard certificate; any other
        # orders one for the kanidm name alone (a distinct identifier set, so it
        # doesn't count against the wildcard's duplicate-certificate limit).
        ownCert = !config.services.nginx.enable;
        certName = if ownCert then domain else environment.domain;
        certDir = config.security.acme.certs.${certName}.directory;
        address = environment.addressOn "default" host;
        own = settingOf host;
        addressOf = h: den.environments.${h.environment}.addressOn "default" h;
        partners = lib.filter (
          h:
          h.name != host.name
          && h.environment == host.environment
          && (settingOf h).replication or false
          && builtins.pathExists (certFile h)
        ) (lib.attrValues den.hosts.x86_64-linux);
        replicationHosts = lib.filter (
          h: h.environment == host.environment && (settingOf h).replication or false
        ) (lib.attrValues den.hosts.x86_64-linux);
      in
      lib.mkMerge [
        {
          services.kanidm = {
            # Carries two OAuth2 token-lifetime patches (see the .patch header):
            # (B) 8h access tokens so the stateless Envoy oauth2 filter rarely
            # refreshes, and (A) a refresh-token reuse grace so the rare concurrent
            # refresh fanned across the gateway replicas isn't misdetected as reuse
            # and doesn't destroy the session. Neither is configurable in kanidm
            # (proven from source). Only .rs files change, so vendored cargoDeps
            # stay valid; --replace would silently no-op on a bump, so a context
            # diff (fails loudly if the lines move) is used instead. Replicas must
            # run the same build: a bump deploys to every kanidm host together.
            package = pkgs.kanidm_1_11.withSecretProvisioning.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [ ./kanidm-oauth2-token-tuning.patch ];
            });

            server = {
              enable = true;
              settings = {
                inherit (environment) domain;
                origin = "https://${domain}";
                bindaddress = "127.0.0.1:8443";
                ldapbindaddress = "127.0.0.1:3636";

                tls_chain = "${certDir}/fullchain.pem";
                tls_key = "${certDir}/key.pem";
              };
            };
          };

          # Ensure kanidm user can read secret files and certificates
          systemd.services.kanidm.serviceConfig = {
            SupplementaryGroups = [ "keys" ];
          };
        }

        # The environment wildcard is nginx's certificate, readable by its group only.
        (lib.mkIf (!ownCert) { users.users.kanidm.extraGroups = [ config.services.nginx.group ]; })

        (lib.mkIf ownCert {
          security.acme.certs.${domain} = {
            group = "kanidm";
            reloadServices = [ "kanidm.service" ];
          };
          # acme-<cert> places a self-signed certificate before the first order.
          systemd.services.kanidm = {
            wants = [ "acme-${domain}.service" ];
            after = [ "acme-${domain}.service" ];
          };
        })

        (lib.mkIf own.replication {
          assertions = [
            {
              assertion = own.refreshFrom == null || lib.elem own.refreshFrom (map (h: h.name) replicationHosts);
              message = "${host.name}: kanidm-server.refreshFrom = ${toString own.refreshFrom} is not a replication host of ${host.environment}";
            }
          ];
          services.kanidm.server.settings.replication = {
            origin = "repl://${address}:${toString replicationPort}";
            bindaddress = "${address}:${toString replicationPort}";
          }
          // lib.listToAttrs (
            map (
              h:
              lib.nameValuePair "repl://${addressOf h}:${toString replicationPort}" (
                {
                  type = "mutual-pull";
                  partner_cert = partnerCert h;
                }
                // lib.optionalAttrs (own.refreshFrom == h.name) { automatic_refresh = true; }
              )
            ) partners
          );
          # Mutual TLS pinned to each partner's certificate guards the port; the
          # firewall (where one runs) also admits the partners only.
          networking.firewall.extraInputRules = lib.mkIf (partners != [ ]) ''
            ip saddr { ${
              lib.concatMapStringsSep ", " addressOf partners
            } } ip daddr ${address} tcp dport ${toString replicationPort} accept
          '';
        })
      ];

    persist = {
      directories = [
        {
          directory = "/var/lib/kanidm";
          user = "kanidm";
          group = "kanidm";
          mode = "0700";
        }
      ];
    };
  };
}
