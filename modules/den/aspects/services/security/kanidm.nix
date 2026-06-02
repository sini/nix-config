{
  den,
  lib,
  config,
  self,
  ...
}:
let
  inherit (lib)
    filterAttrs
    mapAttrs
    mapAttrs'
    nameValuePair
    elem
    unique
    optionalAttrs
    mkMerge
    ;

  groups = config.den.groups;
  registry = config.den.users.registry;

  # Groups by label for provisioning classification
  groupsWithLabel = label: filterAttrs (_: g: elem label (g.labels or [ ])) groups;

  # Users who belong to any group carrying the target label
  usersWithLabel =
    label:
    let
      labelGroupNames = builtins.attrNames (groupsWithLabel label);
    in
    filterAttrs (_: user: builtins.any (g: elem g labelGroupNames) (user.groups or [ ])) registry;

  # Users provisioned as kanidm persons (have oauth-grant or user-role groups)
  kanidmUsers =
    let
      oauthUsers = usersWithLabel "oauth-grant";
      roleUsers = usersWithLabel "user-role";
    in
    oauthUsers // roleUsers;

  # All group names a user belongs to that carry one of the target labels
  getUserGroups =
    user:
    let
      oauthGroupNames = builtins.attrNames (groupsWithLabel "oauth-grant");
      roleGroupNames = builtins.attrNames (groupsWithLabel "user-role");
      relevant = unique (oauthGroupNames ++ roleGroupNames);
    in
    builtins.filter (g: elem g relevant) (user.groups or [ ]);

  # ---- POSIX extra JSON (kanidm-provision fork features) ----

  posixGroups = groupsWithLabel "posix";
  extraGroupsJson = mapAttrs (
    _: g: { enableUnix = true; } // optionalAttrs (g.gid != null) { gidNumber = g.gid; }
  ) posixGroups;

  unixUsers = filterAttrs (_: u: u.system.enableUnixAccount or false) kanidmUsers;
  extraPersonsJson = mapAttrs (
    _username: user:
    {
      enableUnix = true;
      loginShell = "/run/current-system/sw/bin/zsh";
    }
    // optionalAttrs (user.system.uid != null) { gidNumber = user.system.uid; }
    // optionalAttrs (user.identity.sshKeys != [ ]) {
      sshPublicKeys = map (k: { inherit (k) tag key; }) user.identity.sshKeys;
    }
  ) unixUsers;

  extraJson =
    optionalAttrs (extraGroupsJson != { }) { groups = extraGroupsJson; }
    // optionalAttrs (extraPersonsJson != { }) { persons = extraPersonsJson; };

  # ---- OAuth2 service definitions ----
  # Each entry mirrors the legacy provision/services/*.nix files.
  # Domain resolution uses env.getDomainFor, secrets come from age-secrets pipe.

  mkOAuth2Services =
    env: secretPaths:
    let
      domain = svc: env.getDomainFor svc;
    in
    {
      argocd = {
        displayName = "argocd";
        originUrl = [ "https://${domain "argocd"}/auth/callback" ];
        originLanding = "https://${domain "argocd"}/applications";
        basicSecretFile = secretPaths.argocd-oidc-client-secret;
        preferShortUsername = true;
        scopeMaps."argocd.access" = [
          "openid"
          "email"
          "profile"
        ];
        claimMaps.groups = {
          joinType = "array";
          valuesByGroup = {
            "argocd.admins" = [ "admin" ];
            "argocd.access" = [ "user" ];
          };
        };
      };

      forgejo = {
        displayName = "Forgejo";
        originUrl = "https://${domain "forgejo"}/user/oauth2/kanidm/callback";
        originLanding = "https://${domain "forgejo"}/";
        basicSecretFile = secretPaths.forgejo-oidc-client-secret;
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

      grafana = {
        displayName = "Grafana Dashboard";
        originLanding = "https://${domain "grafana"}/login/generic_oauth";
        originUrl = "https://${domain "grafana"}";
        basicSecretFile = secretPaths.grafana-oidc-client-secret;
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

      headscale = {
        displayName = "vpn";
        originUrl = [
          "https://${domain "headscale"}/oidc/callback"
          "https://${domain "headscale"}/admin/oidc/callback"
        ];
        originLanding = "https://${domain "headscale"}/admin";
        basicSecretFile = secretPaths.headscale-oidc-client-secret;
        scopeMaps."vpn.users" = [
          "openid"
          "email"
          "profile"
        ];
        preferShortUsername = true;
      };

      hubble-ui = {
        displayName = "hubble-ui";
        originUrl = [ "https://${domain "hubble-ui"}/oauth2/callback" ];
        originLanding = "https://${domain "hubble-ui"}/";
        basicSecretFile = secretPaths.hubble-ui-oidc-client-secret;
        scopeMaps."admins" = [
          "openid"
          "email"
          "profile"
        ];
      };

      jellyfin = {
        displayName = "Jellyfin";
        originUrl = "https://${domain "jellyfin"}/sso/OID/redirect/kanidm";
        originLanding = "https://${domain "jellyfin"}";
        basicSecretFile = secretPaths.jellyfin-oidc-client-secret;
        preferShortUsername = true;
        scopeMaps."media.access" = [
          "openid"
          "profile"
          "groups"
        ];
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

      kubernetes = {
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

      longhorn = {
        displayName = "longhorn";
        originUrl = [ "https://${domain "longhorn"}/oauth2/callback" ];
        originLanding = "https://${domain "longhorn"}/";
        basicSecretFile = secretPaths.longhorn-oidc-client-secret;
        scopeMaps."admins" = [
          "openid"
          "email"
          "profile"
        ];
      };

      oauth2-proxy = {
        displayName = "OAuth2-Proxy";
        originUrl = "https://${domain "oauth2-proxy"}/oauth2/callback";
        originLanding = "https://${domain "oauth2-proxy"}/";
        basicSecretFile = secretPaths.oauth2-proxy-oidc-client-secret;
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

      open-webui = {
        displayName = "open-webui";
        imageFile = builtins.path { path = self + /assets/open-webui.svg; };
        originUrl = "https://${domain "open-webui"}/oauth/oidc/callback";
        originLanding = "https://${domain "open-webui"}/auth";
        basicSecretFile = secretPaths.open-webui-oidc-client-secret;
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
in
{
  den.aspects.services.security.kanidm = {
    includes = [ den.aspects.services.networking.nginx ];

    nixos =
      {
        config,
        environment,
        pkgs,
        ...
      }:
      let
        domain = environment.getDomainFor "kanidm";
        topDomain = environment.domain;

        extraJsonFile = pkgs.writeText "kanidm-provision-extra.json" (builtins.toJSON extraJson);

        # Build secret path lookup for non-public OAuth2 clients
        secretPaths = mapAttrs' (
          name: _:
          nameValuePair "${name}-oidc-client-secret" config.age.secrets."${name}-oidc-client-secret".path
        ) (filterAttrs (_: sys: !(sys.public or false)) (mkOAuth2Services environment { }));

        oauth2Services = mkOAuth2Services environment secretPaths;
      in
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

              # All groups provisioned to kanidm
              groups = mapAttrs (_: g: { inherit (g) members; }) groups;

              # Users with oauth-grant or user-role groups provisioned as persons
              persons = mapAttrs (username: user: {
                inherit (user.identity) displayName;
                mailAddresses =
                  if user.identity.email != null then
                    [ user.identity.email ]
                  else
                    [ "${username}@${environment.email.domain}" ];
                groups = getUserGroups user;
              }) kanidmUsers;

              # OAuth2 client definitions
              systems.oauth2 = oauth2Services;

              # POSIX extensions via extra JSON
              inherit extraJsonFile;
            };
          };

          nginx.virtualHosts."${domain}" = {
            forceSSL = true;
            useACMEHost = topDomain;
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

        # Ensure kanidm user can read secret files and certificates
        systemd.services.kanidm.serviceConfig = {
          SupplementaryGroups = [ "keys" ];
        };

        users.users.kanidm.extraGroups = [
          config.security.acme.defaults.group
          config.services.nginx.group
        ];
      };

    age-secrets =
      { environment, ... }:
      let
        # OIDC secrets for non-public OAuth2 clients
        mkOidcSecret = name: {
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

        # Build a dummy services set to identify non-public clients
        nonPublicClients = builtins.attrNames (
          filterAttrs (_: sys: !(sys.public or false)) (mkOAuth2Services environment { })
        );
      in
      {
        age.secrets = mkMerge (
          [
            {
              kanidm-admin-password = {
                rekeyFile = environment.secretPath + "/kanidm-admin-password.age";
                generator.script = "passphrase";
                owner = "kanidm";
                group = "kanidm";
              };
            }
          ]
          ++ map mkOidcSecret nonPublicClients
        );
      };

    firewall = {
      networking.firewall.allowedTCPPorts = [ 3636 ];
    };

    service-domains = [ "kanidm" ];

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
