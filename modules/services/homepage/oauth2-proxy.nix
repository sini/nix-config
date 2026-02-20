{ rootPath, ... }:
{
  # We are having issues with the nixpkg socket... so lets stash our own service for now with fixed users.
  flake.features.oauth2-proxy.nixos =
    { config, environment, ... }:
    {

      age.secrets.oauth2-proxy-oidc-secret = {
        rekeyFile = rootPath + "/.secrets/env/${environment.name}/oidc/oauth2-proxy-oidc-client-secret.age";
        mode = "440";
        owner = "oauth2-proxy";
        group = "oauth2-proxy";
      };

      age.secrets.oauth2-proxy-cookie-secret = {
        rekeyFile = rootPath + "/.secrets/env/${environment.name}/oauth2-proxy-cookie-secret.age";
        mode = "440";
        owner = "oauth2-proxy";
        group = "oauth2-proxy";
      };

      age.secrets.oauth2-proxy-keys = {
        generator.dependencies = [
          config.age.secrets.oauth2-proxy-cookie-secret
          config.age.secrets.oauth2-proxy-oidc-secret
        ];
        generator.script = (
          {
            lib,
            decrypt,
            deps,
            ...
          }:
          ''
            echo -n "OAUTH2_PROXY_COOKIE_SECRET="
            ${decrypt} ${lib.escapeShellArg (lib.elemAt deps 0).file}
            echo -n "OAUTH2_PROXY_CLIENT_SECRET="
            ${decrypt} ${lib.escapeShellArg (lib.elemAt deps 1).file}
          ''
        );
      };

      services.oauth2-proxy = {
        enable = true;

        provider = "oidc";

        keyFile = config.age.secrets.oauth2-proxy-keys.path;

        # Email configuration - allow all authenticated users
        email.domains = [ "*" ];

        # Reverse proxy settings
        reverseProxy = true;
        # httpAddress = "127.0.0.1:4180";

        # OIDC configuration
        clientID = "oauth2-proxy";
        oidcIssuerUrl = "https://idm.${environment.domain}/oauth2/openid/oauth2-proxy";
        redirectURL = "https://oauth2-proxy.${environment.domain}/oauth2/callback";
        loginURL = "https://oauth2-proxy.${environment.domain}/oauth2/authorise";
        profileURL = "https://idm.${environment.domain}/oauth2/openid/oauth2-proxy/userinfo";
        redeemURL = "https://idm.${environment.domain}/oauth2/token";
        validateURL = "https://idm.${environment.domain}/oauth2/token/introspect";

        scope = "openid email profile";

        cookie = {
          domain = ".${environment.domain}";
          secure = true;
          httpOnly = true;
          name = "_oauth2_proxy";
        };

        # Pass authentication headers
        setXauthrequest = true;

        upstream = [ ];

        extraConfig = {
          provider-display-name = "Kanidm";
          skip-provider-button = true;
          code-challenge-method = "S256";
          set-authorization-header = true;
          pass-access-token = true;
          skip-jwt-bearer-tokens = true;

          cookie-csrf-expire = "15m";
          cookie-csrf-per-request = true;

          oidc-groups-claim = "groups";
          whitelist-domain = [
            "${environment.domain}"
            "*.${environment.domain}"
          ];
          # client-secret-file = config.age.secrets.oauth2-proxy-oidc-secret.path;
          # cookie-secret-file = config.age.secrets.oauth2-proxy-cookie-secret.path;
          # upstream = "static://202";
        };

        nginx.domain = "oauth2-proxy.${environment.domain}";
      };

      services.nginx.virtualHosts."oauth2-proxy.${environment.domain}" = {
        forceSSL = true;
        useACMEHost = environment.domain;
        locations."/" = {
          proxyPass = "http://127.0.0.1:4180";
          recommendedProxySettings = true;
          extraConfig = ''
            proxy_set_header X-Scheme                $scheme;
            proxy_set_header X-Auth-Request-Redirect $scheme://$host$request_uri;
          '';
        };
      };

      services.nginx.upstreams."oauth2-proxy.${environment.domain}" = {
        servers = {
          "localhost:4180" = { };
        };
      };

      systemd.services.oauth2-proxy.after = [
        "kanidm.service"
      ];
      # environment.persistence."/persist".directories = [
      #   {
      #     directory = "/var/lib/private/tang";
      #     user = "nobody";
      #     group = "nogroup";
      #     mode = "0700";
      #   }
      # ];
    };
}
