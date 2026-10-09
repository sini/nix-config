{
  den,
  lib,
  config,
  self,
  ...
}:
let
  serviceDomains = [ "kanidm" ];
  inherit (lib)
    filterAttrs
    mapAttrs
    mapAttrs'
    nameValuePair
    elem
    unique
    optionalAttrs
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
  # gidNumber is left to kanidm: it only accepts 1000-60000 and up, and these
  # mirror system groups (wheel, audio, ...) that no host resolves via kanidm.
  extraGroupsJson = mapAttrs (_: _: { enableUnix = true; }) posixGroups;

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
      # Gateway-OIDC fronts for the cluster's Prometheus and Alertmanager
      # (kubernetes/services/monitoring/prometheus.nix); admins only.
      prometheus = {
        displayName = "Prometheus";
        originUrl = [ "https://${domain "prometheus"}/oauth2/callback" ];
        originLanding = "https://${domain "prometheus"}";
        basicSecretFile = secretPaths.prometheus-oidc-client-secret;
        preferShortUsername = true;
        scopeMaps.admins = [
          "openid"
          "email"
          "profile"
        ];
      };

      alertmanager = {
        displayName = "Alertmanager";
        originUrl = [ "https://${domain "alertmanager"}/oauth2/callback" ];
        originLanding = "https://${domain "alertmanager"}";
        basicSecretFile = secretPaths.alertmanager-oidc-client-secret;
        preferShortUsername = true;
        scopeMaps.admins = [
          "openid"
          "email"
          "profile"
        ];
      };

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

      coder = {
        displayName = "Coder";
        originUrl = [ "https://${domain "coder"}/api/v2/users/oidc/callback" ];
        originLanding = "https://${domain "coder"}";
        basicSecretFile = secretPaths.coder-oidc-client-secret;
        preferShortUsername = true;
        scopeMaps."coder.access" = [
          "openid"
          "email"
          "profile"
          "groups"
        ];
        # The admin/user values feed Coder's OIDC role sync
        # (CODER_OIDC_USER_ROLE_MAPPING), a Coder PREMIUM feature — inert on
        # unlicensed OSS, where roles are assigned manually. The groups claim is
        # still emitted (harmless); login is gated by the coder.access scope map
        # above, which works on OSS.
        claimMaps.groups = {
          joinType = "array";
          valuesByGroup = {
            "coder.admins" = [ "admin" ];
            "coder.access" = [ "user" ];
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

      # The fleet's Grafana (in-cluster, monitoring namespace), grafana-native
      # OIDC, served at grafana.<domain>.
      grafana = {
        displayName = "Grafana (cluster)";
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

      opkssh = {
        displayName = "opkssh";
        public = true;
        enableLocalhostRedirects = true;
        enableLegacyCrypto = true; # opkssh needs RS256; kanidm defaults to ES256
        preferShortUsername = true;
        originUrl = [
          "http://localhost:3000/login-callback"
          "http://localhost:10001/login-callback"
          "http://localhost:11110/login-callback"
          # iOS (rootshell) uses a custom URL scheme, not localhost loopback — its redirect
          # URI is added later once captured hands-on. Do NOT invent one now.
        ];
        originLanding = "http://localhost:3000";
        scopeMaps."opkssh.access" = [
          "openid"
          "email"
          "profile"
          "groups"
        ];
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

      # Gateway OIDC (Envoy SecurityPolicy) in front of matrix-admin.json64.dev:
      # Ketesa plus the Synapse admin API. Admins only, like longhorn.
      synapse-admin = {
        displayName = "Matrix admin";
        originUrl = [ "https://${domain "matrix-admin"}/oauth2/callback" ];
        originLanding = "https://${domain "matrix-admin"}/";
        basicSecretFile = secretPaths.synapse-admin-oidc-client-secret;
        scopeMaps."admins" = [
          "openid"
          "email"
          "profile"
        ];
      };

      # tuwunel (communication/matrix/tuwunel.nix), the gen.wtf companion homeserver.
      # Native OIDC; the callback path is tuwunel's fixed per-client form.
      tuwunel = {
        displayName = "Matrix (gen.wtf)";
        originUrl = "https://matrix.gen.wtf/_matrix/client/unstable/login/sso/callback/tuwunel";
        originLanding = "https://matrix.gen.wtf";
        basicSecretFile = secretPaths.tuwunel-oidc-client-secret;
        preferShortUsername = true;
        scopeMaps."matrix.access" = [
          "openid"
          "profile"
          "email"
        ];
      };

      garage-ui = {
        displayName = "Garage UI";
        originUrl = [ "https://${domain "garage-ui"}/oauth2/callback" ];
        originLanding = "https://${domain "garage-ui"}/";
        basicSecretFile = secretPaths.garage-ui-oidc-client-secret;
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

      # RomM uses its NATIVE OIDC (not the gateway SecurityPolicy that the generic
      # mkMediaClients entries get), so it needs a bespoke callback + role claim.
      # Callback is RomM's own /api/oauth/openid. RomM requests scope
      # "openid profile email roles", so `roles` is granted in the scopeMap (an
      # arbitrary scope string) AND emitted as a claim via claimMaps.roles:
      # media.admins -> RomM ADMIN, media.access -> RomM VIEWER. Mirrors jellyfin's
      # claimMap; see romm.nix OIDC_* env.
      romm = {
        displayName = "RoMM";
        originUrl = "https://${domain "romm"}/api/oauth/openid";
        originLanding = "https://${domain "romm"}";
        basicSecretFile = secretPaths.romm-oidc-client-secret;
        preferShortUsername = true;
        allowInsecureClientDisablePkce = true;
        scopeMaps."media.access" = [
          "openid"
          "profile"
          "email"
          "groups"
          "roles"
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

      # Synapse NATIVE OIDC (the romm pattern; see communication/matrix/synapse.nix).
      # preferShortUsername makes `preferred_username` the short kanidm name, which
      # becomes the PERMANENT Matrix localpart (@<short>:json64.dev). Synapse sends
      # PKCE (pkce_method: always), so the insecure PKCE opt-out is not set.
      synapse = {
        displayName = "Matrix";
        originUrl = "https://${domain "matrix"}/_synapse/client/oidc/callback";
        originLanding = "https://${domain "matrix"}";
        basicSecretFile = secretPaths.synapse-oidc-client-secret;
        preferShortUsername = true;
        scopeMaps."matrix.access" = [
          "openid"
          "profile"
          "email"
        ];
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
    }
    // mkMediaClients env secretPaths;

  # ---- Media-stack OAuth2 clients ----
  # Every media UI sits behind an Envoy OIDC SecurityPolicy. The SecurityPolicy
  # (rendered per-app in each media aspect) uses clientID = <name>, issuer
  # https://idm.<domain>/oauth2/openid/<name>, clientSecret <name>-oidc-client-secret,
  # and the Envoy-default redirect URI <app-url>/oauth2/callback. These client
  # entries mirror that contract exactly (hubble-ui originUrl convention). The
  # client secret shares its rekeyFile + generator with the k8s age-secret so a
  # single generated value backs both sides.
  mediaScopes = [
    "openid"
    "profile"
    "email"
    "groups"
  ];

  # name -> { displayName; group; }. group selects the scope-map: admin-gated
  # apps map to media.admins, general apps to media.access.
  mediaClientDefs = {
    prowlarr = {
      displayName = "Prowlarr";
      group = "media.admins";
    };
    sonarr = {
      displayName = "Sonarr";
      group = "media.access";
    };
    radarr = {
      displayName = "Radarr";
      group = "media.access";
    };
    lidarr = {
      displayName = "Lidarr";
      group = "media.access";
    };
    whisparr = {
      displayName = "Whisparr";
      group = "media.access";
    };
    bazarr = {
      displayName = "Bazarr";
      group = "media.access";
    };
    sabnzbd = {
      displayName = "SABnzbd";
      group = "media.admins";
    };
    qbittorrent = {
      displayName = "qBittorrent";
      group = "media.admins";
    };
    # romm is NOT here: it uses NATIVE OIDC (not the gateway SecurityPolicy), so it
    # needs a bespoke originUrl (/api/oauth/openid) + a `roles` claim/scope. It is
    # defined as a standalone client in mkOAuth2Services below.
    komga = {
      displayName = "Komga";
      group = "media.access";
    };
    glance = {
      displayName = "Glance";
      group = "media.access";
    };
    shoko = {
      displayName = "Shoko";
      group = "media.admins";
    };
    profilarr = {
      displayName = "Profilarr";
      group = "media.admins";
    };
    tdarr = {
      displayName = "Tdarr";
      group = "media.admins";
    };
    # The k8s utility dashboard is named "dash" (NOT "homepage"): the uplink host
    # already owns service-domains "homepage" (homepage.json64.dev) via its NixOS
    # homepage-dashboard aspect (modules/den/aspects/services/web/homepage.nix,
    # behind oauth2-proxy). Reusing "homepage" here would collide on that domain.
    # "dash" -> dash.json64.dev keeps the two dashboards on distinct hosts/domains.
    dash = {
      displayName = "Dashboard";
      group = "media.access";
    };
  };

  mkMediaClients =
    env: secretPaths:
    let
      domain = svc: env.getDomainFor svc;
    in
    mapAttrs (name: def: {
      inherit (def) displayName;
      originUrl = [ "https://${domain name}/oauth2/callback" ];
      originLanding = "https://${domain name}";
      basicSecretFile = secretPaths."${name}-oidc-client-secret";
      preferShortUsername = true;
      scopeMaps.${def.group} = mediaScopes;
    }) mediaClientDefs;
in
{
  den.aspects.services.security.kanidm = {
    includes = [ den.aspects.services.networking.nginx ];

    settings = {
      # kanidm-mail-sender drains kanidm's outbound message queue (credential
      # reset and account recovery links), authenticating with a read-write API
      # token of the mail-sender service account, a member of
      # idm_message_senders and nothing else. The account and membership are an
      # entry-management migration; the token and the domain's account-recovery
      # flag are what migrations may not assert, so a oneshot on this host
      # mints/sets them. The token never leaves the host. null leaves the queue
      # undrained and recovery off.
      mailSender = lib.mkOption {
        type = lib.types.nullOr (
          lib.types.submodule {
            options = {
              relay = lib.mkOption {
                type = lib.types.str;
                example = "smtp://smtp.example.com:587";
                description = "SMTP relay URL: smtps:// or smtp:// with mandatory STARTTLS.";
              };
              fromAddress = lib.mkOption {
                type = lib.types.str;
                example = "idm@example.com";
                description = "Sender address of outgoing messages.";
              };
              replyToAddress = lib.mkOption {
                type = lib.types.str;
                example = "admin@example.com";
                description = "Reply-To address of outgoing messages.";
              };
              instanceDisplayName = lib.mkOption {
                type = lib.types.str;
                example = "Example IDM";
                description = "Instance name shown in message subjects.";
              };
            };
          }
        );
        default = null;
        description = "kanidm-mail-sender configuration; null disables it.";
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
        domain = environment.getDomainFor "kanidm";
        topDomain = environment.domain;

        extraJsonFile = pkgs.writeText "kanidm-provision-extra.json" (builtins.toJSON extraJson);

        # Build secret path lookup for non-public OAuth2 clients
        secretPaths = mapAttrs' (
          name: _:
          nameValuePair "${name}-oidc-client-secret" config.age.secrets."${name}-oidc-client-secret".path
        ) (filterAttrs (_: sys: !(sys.public or false)) (mkOAuth2Services environment { }));

        oauth2Services = mkOAuth2Services environment secretPaths;

        mailSender = host.settings.services.security.kanidm.mailSender;
        mailSenderUuid = "794f8210-93f9-4ec6-b89f-24607b41f9e2";
        # Everything but the token, which is prepended at start from the credential.
        mailSenderConfig = (pkgs.formats.toml { }).generate "kanidm-mail-sender.toml" {
          instance_display_name = mailSender.instanceDisplayName;
          instance_url = "https://${domain}";
          mail_from_address = mailSender.fromAddress;
          mail_reply_to_address = mailSender.replyToAddress;
          mail_relay = mailSender.relay;
        };
      in
      lib.mkMerge [
        {
          services = {
            kanidm = {
              # Carries two OAuth2 token-lifetime patches (see the .patch header):
              # (B) 8h access tokens so the stateless Envoy oauth2 filter rarely
              # refreshes, and (A) a refresh-token reuse grace so the rare concurrent
              # refresh fanned across the gateway replicas isn't misdetected as reuse
              # and doesn't destroy the session. Neither is configurable in kanidm
              # (proven from source). Only .rs files change, so vendored cargoDeps
              # stay valid; --replace would silently no-op on a bump, so a context
              # diff (fails loudly if the lines move) is used instead.
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
                  # kanidm rejects an empty displayname (InvalidAttributeSyntax),
                  # so fall back to the username when none is set.
                  displayName = if user.identity.displayName != "" then user.identity.displayName else username;
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
        }

        (lib.mkIf (mailSender != null) {
          # The mail-sender account, asserted at kanidmd start.
          services.kanidm.server.entryManagement.migrations = {
            "50-mail-sender-account" = {
              id = "f353f3cb-f779-4907-8d6d-ee6ba0fd78b9";
              assertions = [
                {
                  state = "present";
                  id = mailSenderUuid;
                  class = [
                    "account"
                    "service_account"
                  ];
                  name = "mail-sender";
                  displayname = "Mail Sender";
                  entry_managed_by = [ "idm_admins" ];
                }
              ];
            };
          };

          # What migrations do not cover: the account's API token (a credential),
          # the domain's account-recovery flag (recovery needs a domain admin), and
          # membership of the builtin idm_message_senders group (a migration
          # asserting it applied without effect on 1.11.2). Each start re-asserts
          # the flag and membership and mints the token once, as idm_admin, into a
          # root-only state file.
          systemd.services.kanidm-mail-sender-bootstrap = {
            description = "Mint the kanidm-mail-sender token and enable account recovery";
            after = [ "kanidm.service" ];
            requires = [ "kanidm.service" ];
            path = [
              config.services.kanidm.package
              pkgs.jq
            ];
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              StateDirectory = "kanidm-mail-sender";
              StateDirectoryMode = "0700";
              ExecStart = pkgs.writeShellScript "kanidm-mail-sender-bootstrap" ''
                set -euo pipefail
                KANIDM_TOKEN_CACHE_PATH=$(mktemp)
                export KANIDM_TOKEN_CACHE_PATH
                trap 'rm -f "$KANIDM_TOKEN_CACHE_PATH"' EXIT
                password=$(< ${config.services.kanidm.provision.adminPasswordFile})

                KANIDM_PASSWORD=$password kanidm login -D admin
                kanidm system domain set-allow-account-recovery true -D admin

                KANIDM_PASSWORD=$(< ${config.services.kanidm.provision.idmAdminPasswordFile}) \
                  kanidm login -D idm_admin
                kanidm group add-members idm_message_senders mail-sender -D idm_admin

                token="$STATE_DIRECTORY/token"
                if [[ ! -s $token ]]; then
                  umask 077
                  kanidm service-account api-token generate mail-sender kanidm-mail-sender \
                    --readwrite -o json -D idm_admin | jq -er .result > "$token.new"
                  mv "$token.new" "$token"
                fi
              '';
            };
            wantedBy = [ "multi-user.target" ];
          };

          systemd.services.kanidm-mail-sender = {
            description = "Kanidm outbound mail sender";
            after = [
              "kanidm-mail-sender-bootstrap.service"
              "network-online.target"
            ];
            requires = [ "kanidm-mail-sender-bootstrap.service" ];
            wants = [ "network-online.target" ];
            # The config embeds the token and the binary reads no token file, so
            # render it into the private runtime directory at start.
            script = ''
              umask 077
              conf="$RUNTIME_DIRECTORY/mail-sender.toml"
              printf 'token = "%s"\n' "$(< "$CREDENTIALS_DIRECTORY/token")" > "$conf"
              cat ${mailSenderConfig} >> "$conf"
              chmod 0400 "$conf"
              exec ${config.services.kanidm.package}/bin/kanidm-mail-sender \
                -c /etc/kanidm/config -m "$conf"
            '';
            serviceConfig = {
              DynamicUser = true;
              RuntimeDirectory = "kanidm-mail-sender";
              RuntimeDirectoryMode = "0700";
              LoadCredential = "token:/var/lib/kanidm-mail-sender/token";
              Restart = "on-failure";
              RestartSec = 30;
              NoNewPrivileges = true;
              ProtectSystem = "strict";
              ProtectHome = true;
              PrivateTmp = true;
              PrivateDevices = true;
              RestrictAddressFamilies = [
                "AF_INET"
                "AF_INET6"
                "AF_UNIX"
              ];
            };
            wantedBy = [ "multi-user.target" ];
          };
        })
      ];

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
        # Plain disjoint merge (each element is a distinct secret name), not
        # mkMerge: the secrets collector deduplicates broadcast emissions by name
        # with a shallow merge, so emitters must return a plain attrset.
        age.secrets = lib.mergeAttrsList (
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

    service-domains = serviceDomains;
    served-domains = { environment, host, ... }: environment.servedDomains host serviceDomains;

    # The identities this IdP provisions, with their kanidm groups, computed here
    # where provisioning is decided. Routed to clusters (cluster-collect-idm-users)
    # so workloads can derive authorization from the same source.
    idm-users =
      { environment, ... }:
      lib.mapAttrsToList (name: user: {
        environment = environment.name;
        inherit name;
        groups = getUserGroups user;
      }) kanidmUsers;

    persist =
      { host, ... }:
      {
        directories = [
          {
            directory = "/var/lib/kanidm";
            user = "kanidm";
            group = "kanidm";
            mode = "0700";
          }
        ]
        # The minted mail-sender token (kanidm-mail-sender-bootstrap).
        ++ lib.optional (host.settings.services.security.kanidm.mailSender != null) {
          directory = "/var/lib/kanidm-mail-sender";
          user = "root";
          group = "root";
          mode = "0700";
        };
      };
  };
}
