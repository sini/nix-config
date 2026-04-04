# KanIDM identity management server with OIDC provisioning.
#
# This aspect includes:
#   - KanIDM server and client configuration
#   - Nginx reverse proxy
#   - User and group provisioning from den users/groups
#   - OIDC client provisioning for downstream services
#   - Auto-generated OIDC secrets per non-public OAuth2 system
{
  den,
  lib,
  rootPath,
  ...
}:
{
  den.aspects.kanidm = {
    includes = lib.attrValues den.aspects.kanidm._;

    _ = {
      config = den.lib.perHost (
        { host }:
        let
          inherit (host) environment;
          domain = environment.getDomainFor "kanidm";
          topDomain = environment.getTopDomainFor "kanidm";
        in
        {
          nixos =
            { config, pkgs, ... }:
            {
              services = {
                kanidm = {
                  package = pkgs.kanidm_1_9.withSecretProvisioning;

                  server = {
                    enable = true;
                    settings = {
                      inherit (environment) domain;
                      origin = "https://${domain}";
                      bindaddress = "127.0.0.1:8443";
                      ldapbindaddress = "127.0.0.1:3636";

                      # TLS certificates from ACME
                      tls_chain = "${config.security.acme.certs.${topDomain}.directory}/fullchain.pem";
                      tls_key = "${config.security.acme.certs.${topDomain}.directory}/key.pem";
                    };
                  };

                  client = {
                    enable = true;
                    settings = {
                      uri = "https://${domain}";
                    };
                  };

                  provision = {
                    enable = true;
                    adminPasswordFile = config.age.secrets.kanidm-admin-password.path;
                    idmAdminPasswordFile = config.age.secrets.kanidm-admin-password.path;
                  };
                };

                nginx.virtualHosts."${domain}" = {
                  forceSSL = true;
                  useACMEHost = environment.getTopDomainFor "kanidm";
                  locations."/" = {
                    proxyPass = "https://127.0.0.1:8443";
                    proxyWebsockets = true;
                    extraConfig = ''
                      proxy_set_header Host $host;
                      proxy_set_header X-Real-IP $remote_addr;
                      proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                      proxy_set_header X-Forwarded-Proto $scheme;

                      proxy_ssl_server_name on;
                      proxy_ssl_name $host;
                      proxy_ssl_verify_depth 2;
                      proxy_ssl_protocols  TLSv1 TLSv1.1 TLSv1.2;
                      proxy_ssl_session_reuse off;
                    '';
                  };
                };
              };

              # Ensure kanidm user can read the secret files and certificates
              systemd.services.kanidm.serviceConfig = {
                SupplementaryGroups = [ "keys" ];
              };

              # Grant kanidm access to certificates
              users.users.kanidm.extraGroups = [
                config.security.acme.defaults.group
                config.services.nginx.group
              ];
            };
        }
      );

      # User and group provisioning from den users/groups system
      provision-users = den.lib.perHost (
        { host }:
        let
          inherit (host) environment;
        in
        {
          nixos =
            {
              lib,
              config,
              users,
              pkgs,
              ...
            }:
            let
              # All groups are provisioned to Kanidm
              allGroups = config.groups;

              # Users with any oauth-grant or user-role groups get provisioned as persons
              kanidmUsers = lib.filterAttrs (
                _: user: (user.groupsByLabel "oauth-grant" != [ ]) || (user.groupsByLabel "user-role" != [ ])
              ) users;

              getUserGroups =
                user: lib.unique ((user.groupsByLabel "oauth-grant") ++ (user.groupsByLabel "user-role"));

              # Extra JSON for kanidm-provision fork features
              posixGroups = lib.filterAttrs (_: g: lib.elem "posix" (g.labels or [ ])) allGroups;
              extraGroupsJson = lib.mapAttrs (
                _: g: { enableUnix = true; } // lib.optionalAttrs (g.gid != null) { gidNumber = g.gid; }
              ) posixGroups;

              unixPersons = lib.filterAttrs (_: user: user.system.enableUnixAccount or false) kanidmUsers;
              extraPersonsJson = lib.mapAttrs (
                _username: user:
                {
                  enableUnix = true;
                  loginShell = "/run/current-system/sw/bin/zsh";
                }
                // lib.optionalAttrs (user.system.uid != null) { gidNumber = user.system.uid; }
                // lib.optionalAttrs (user.identity.sshKeys != [ ]) {
                  sshPublicKeys = map (k: { inherit (k) tag key; }) user.identity.sshKeys;
                }
              ) unixPersons;

              extraJson =
                lib.optionalAttrs (extraGroupsJson != { }) { groups = extraGroupsJson; }
                // lib.optionalAttrs (extraPersonsJson != { }) { persons = extraPersonsJson; };

              extraJsonFile = pkgs.writeText "kanidm-provision-extra.json" (builtins.toJSON extraJson);
            in
            {
              services.kanidm.provision = {
                groups = lib.mapAttrs (_: g: { members = g.members or [ ]; }) allGroups;

                persons = lib.mapAttrs (username: user: {
                  inherit (user.identity) displayName;
                  mailAddresses =
                    if user.identity.email != null then
                      [ user.identity.email ]
                    else
                      [ "${username}@${environment.email.domain}" ];
                  groups = getUserGroups user;
                }) kanidmUsers;

                inherit extraJsonFile;
              };
            };
        }
      );

      # OIDC secret auto-generation for all non-public OAuth2 systems
      provision-oidc-secrets = den.lib.perHost {
        nixos =
          {
            config,
            lib,
            environment,
            ...
          }:
          let
            mkOidcSecrets = name: {
              "${name}-oidc-client-secret" = {
                rekeyFile = environment.secretPath + "/oidc/${name}-oidc-client-secret.age";
                owner = "kanidm";
                group = "kanidm";
                generator = {
                  tags = [ "oidc" ];
                  script = "rfc3986-secret";
                };
              };
            };
          in
          {
            age.secrets = lib.mkMerge (
              map mkOidcSecrets (
                builtins.attrNames (
                  lib.filterAttrs (
                    _name: system: !(system.public or false)
                  ) config.services.kanidm.provision.systems.oauth2
                )
              )
            );
          };
      };

      # OIDC service provisioning: ArgoCD
      provision-argocd = den.lib.perHost (
        { host }:
        let
          inherit (host) environment;
        in
        {
          nixos =
            { config, ... }:
            let
              domain = environment.getDomainFor "argocd";
            in
            {
              services.kanidm.provision.systems.oauth2.argocd = {
                displayName = "argocd";
                originUrl = [
                  "https://${domain}/auth/callback"
                ];
                originLanding = "https://${domain}/applications";
                basicSecretFile = config.age.secrets.argocd-oidc-client-secret.path;
                preferShortUsername = true;
                scopeMaps = {
                  "argocd.access" = [
                    "openid"
                    "email"
                    "profile"
                  ];
                };
                claimMaps.groups = {
                  joinType = "array";
                  valuesByGroup = {
                    "argocd.admins" = [ "admin" ];
                    "argocd.access" = [ "user" ];
                  };
                };
              };
            };
        }
      );

      # OIDC service provisioning: Forgejo
      provision-forgejo = den.lib.perHost (
        { host }:
        let
          inherit (host) environment;
        in
        {
          nixos =
            { config, ... }:
            let
              domain = environment.getDomainFor "forgejo";
            in
            {
              services.kanidm.provision.systems.oauth2.forgejo = {
                displayName = "Forgejo";
                originUrl = "https://${domain}/user/oauth2/kanidm/callback";
                originLanding = "https://${domain}/";
                basicSecretFile = config.age.secrets.forgejo-oidc-client-secret.path;
                scopeMaps."forgejo.access" = [
                  "openid"
                  "email"
                  "profile"
                ];
                allowInsecureClientDisablePkce = true;
                preferShortUsername = true;
                claimMaps.groups = {
                  joinType = "array";
                  valuesByGroup."forgejo.admins" = [ "admin" ];
                };
              };
            };
        }
      );

      # OIDC service provisioning: Grafana
      provision-grafana = den.lib.perHost (
        { host }:
        let
          inherit (host) environment;
        in
        {
          nixos =
            { config, ... }:
            let
              domain = environment.getDomainFor "grafana";
            in
            {
              services.kanidm.provision.systems.oauth2.grafana = {
                displayName = "Grafana Dashboard";
                originLanding = "https://${domain}/login/generic_oauth";
                originUrl = "https://${domain}";
                basicSecretFile = config.age.secrets.grafana-oidc-client-secret.path;
                scopeMaps."grafana.access" = [
                  "openid"
                  "email"
                  "profile"
                ];
                claimMaps.groups = {
                  joinType = "array";
                  valuesByGroup = {
                    "grafana.editors" = [ "editor" ];
                    "grafana.admins" = [ "admin" ];
                    "grafana.server-admins" = [ "server_admin" ];
                  };
                };
                allowInsecureClientDisablePkce = false;
                preferShortUsername = true;
              };
            };
        }
      );

      # OIDC service provisioning: Headscale
      provision-headscale = den.lib.perHost (
        { host }:
        let
          inherit (host) environment;
        in
        {
          nixos =
            { config, ... }:
            let
              domain = environment.getDomainFor "headscale";
            in
            {
              services.kanidm.provision.systems.oauth2.headscale = {
                displayName = "vpn";
                originUrl = [
                  "https://${domain}/oidc/callback"
                  "https://${domain}/admin/oidc/callback"
                ];
                originLanding = "https://${domain}/admin";
                basicSecretFile = config.age.secrets.headscale-oidc-client-secret.path;
                scopeMaps."vpn.users" = [
                  "openid"
                  "email"
                  "profile"
                ];
                preferShortUsername = true;
              };
            };
        }
      );

      # OIDC service provisioning: Hubble UI
      provision-hubble-ui = den.lib.perHost (
        { host }:
        let
          inherit (host) environment;
        in
        {
          nixos =
            { config, ... }:
            let
              domain = environment.getDomainFor "hubble-ui";
            in
            {
              services.kanidm.provision.systems.oauth2.hubble-ui = {
                displayName = "hubble-ui";
                originUrl = [
                  "https://${domain}/oauth2/callback"
                ];
                originLanding = "https://${domain}/";
                basicSecretFile = config.age.secrets.hubble-ui-oidc-client-secret.path;
                scopeMaps."admins" = [
                  "openid"
                  "email"
                  "profile"
                ];
              };
            };
        }
      );

      # OIDC service provisioning: Jellyfin
      provision-jellyfin = den.lib.perHost (
        { host }:
        let
          inherit (host) environment;
        in
        {
          nixos =
            { config, ... }:
            let
              domain = environment.getDomainFor "jellyfin";
            in
            {
              services.kanidm.provision.systems.oauth2.jellyfin = {
                displayName = "Jellyfin";
                originUrl = "https://${domain}/sso/OID/redirect/kanidm";
                originLanding = "https://${domain}";
                basicSecretFile = config.age.secrets.jellyfin-oidc-client-secret.path;
                preferShortUsername = true;
                scopeMaps = {
                  "media.access" = [
                    "openid"
                    "profile"
                    "groups"
                  ];
                };
                claimMaps.roles = {
                  joinType = "array";
                  valuesByGroup = {
                    "media.admins" = [
                      "admin"
                      "user"
                    ];
                    "media.access" = [ "user" ];
                  };
                };
              };
            };
        }
      );

      # OIDC service provisioning: Kubernetes (public client)
      provision-kubernetes = den.lib.perHost {
        nixos = {
          services.kanidm.provision.systems.oauth2.kubernetes = {
            displayName = "kubernetes";
            originUrl = "http://localhost:8000";
            originLanding = "http://localhost:8000";
            public = true;
            enableLocalhostRedirects = true;
            scopeMaps."admins" = [
              "openid"
              "email"
              "profile"
              "groups"
            ];
            preferShortUsername = true;
          };
        };
      };

      # OIDC service provisioning: Longhorn
      provision-longhorn = den.lib.perHost (
        { host }:
        let
          inherit (host) environment;
        in
        {
          nixos =
            { config, ... }:
            let
              domain = environment.getDomainFor "longhorn";
            in
            {
              services.kanidm.provision.systems.oauth2.longhorn = {
                displayName = "longhorn";
                originUrl = [
                  "https://${domain}/oauth2/callback"
                ];
                originLanding = "https://${domain}/";
                basicSecretFile = config.age.secrets.longhorn-oidc-client-secret.path;
                scopeMaps."admins" = [
                  "openid"
                  "email"
                  "profile"
                ];
              };
            };
        }
      );

      # OIDC service provisioning: OAuth2 Proxy
      provision-oauth2-proxy = den.lib.perHost (
        { host }:
        let
          inherit (host) environment;
        in
        {
          nixos =
            { config, ... }:
            let
              domain = environment.getDomainFor "oauth2-proxy";
            in
            {
              services.kanidm.provision.systems.oauth2.oauth2-proxy = {
                displayName = "OAuth2-Proxy";
                originUrl = "https://${domain}/oauth2/callback";
                originLanding = "https://${domain}/";
                basicSecretFile = config.age.secrets.oauth2-proxy-oidc-client-secret.path;
                preferShortUsername = true;
                scopeMaps = {
                  "media.access" = [
                    "openid"
                    "email"
                    "profile"
                    "groups"
                  ];
                  "media.admins" = [
                    "openid"
                    "email"
                    "profile"
                    "groups"
                  ];
                  "admins" = [
                    "openid"
                    "email"
                    "profile"
                    "groups"
                  ];
                };
              };
            };
        }
      );

      # OIDC service provisioning: Open WebUI
      provision-open-webui = den.lib.perHost (
        { host }:
        {
          nixos =
            { config, ... }:
            let
              domain = host.environment.getDomainFor "open-webui";
            in
            {
              services.kanidm.provision.systems.oauth2.open-webui = {
                displayName = "open-webui";
                imageFile = builtins.path { path = rootPath + /assets/open-webui.svg; };
                originUrl = "https://${domain}/oauth/oidc/callback";
                originLanding = "https://${domain}/auth";
                basicSecretFile = config.age.secrets.open-webui-oidc-client-secret.path;
                scopeMaps."open-webui.access" = [
                  "openid"
                  "email"
                  "profile"
                ];
                preferShortUsername = true;
                claimMaps = {
                  groups = {
                    joinType = "array";
                    valuesByGroup."open-webui.admins" = [ "admins" ];
                  };
                  roles = {
                    joinType = "array";
                    valuesByGroup = {
                      "open-webui.admins" = [ "admin" ];
                      "open-webui.access" = [ "user" ];
                    };
                  };
                };
              };
            };
        }
      );

      secrets = den.lib.perHost (
        { host }:
        {
          secrets.kanidm-admin-password = {
            rekeyFile = host.environment.secretPath + "/kanidm-admin-password.age";
            generator.script = "passphrase";
            owner = "kanidm";
            group = "kanidm";
          };
        }
      );

      firewall = den.lib.perHost {
        firewall.allowedTCPPorts = [ 3636 ];
      };

      impermanence = den.lib.perHost {
        persist.directories = [
          {
            directory = "/var/lib/kanidm";
            user = "kanidm";
            group = "kanidm";
            mode = "0700";
          }
        ];
      };
    };
  };
}
