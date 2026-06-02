{ den, ... }:
{
  den.aspects.services.security.oauth2-proxy = {
    includes = [ den.aspects.services.networking.nginx ];

    nixos =
      {
        config,
        environment,
        host,
        ...
      }:
      let
        domain = environment.getDomainFor "oauth2-proxy";
        kanidmDomain = environment.getDomainFor "kanidm";
      in
      {
        services = {
          oauth2-proxy = {
            enable = true;

            provider = "oidc";

            keyFile = config.age.secrets.oauth2-proxy-keys.path;

            # Allow all authenticated users
            email.domains = [ "*" ];

            reverseProxy = true;

            # OIDC configuration
            clientID = "oauth2-proxy";
            oidcIssuerUrl = "https://${kanidmDomain}/oauth2/openid/oauth2-proxy";
            redirectURL = "https://${domain}/oauth2/callback";
            loginURL = "https://${domain}/oauth2/authorise";
            profileURL = "https://${kanidmDomain}/oauth2/openid/oauth2-proxy/userinfo";
            redeemURL = "https://${kanidmDomain}/oauth2/token";
            validateURL = "https://${kanidmDomain}/oauth2/token/introspect";

            scope = "openid email profile";

            cookie = {
              domain = ".${environment.domain}";
              secure = true;
              httpOnly = true;
              name = "_oauth2_proxy";
            };

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
            };

            nginx.domain = domain;
          };

          nginx = {
            virtualHosts."${domain}" = {
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

            upstreams."${domain}" = {
              servers = {
                "localhost:4180" = { };
              };
            };
          };
        };

        systemd.services.oauth2-proxy.after = [
          "kanidm.service"
        ];
      };

    age-secrets =
      {
        environment,
        host,
        config,
        ...
      }:
      {
        age.secrets = {
          oauth2-proxy-oidc-secret = {
            rekeyFile = environment.secretPath + "/oidc/oauth2-proxy-oidc-client-secret.age";
            generator = {
              tags = [ "oidc" ];
              script = "rfc3986-secret";
            };
            mode = "440";
            owner = "oauth2-proxy";
            group = "oauth2-proxy";
          };

          oauth2-proxy-cookie-secret = {
            rekeyFile = environment.secretPath + "/oauth2-proxy-cookie-secret.age";
            generator.script = "base64";
            mode = "440";
            owner = "oauth2-proxy";
            group = "oauth2-proxy";
          };

          oauth2-proxy-keys = {
            generator.dependencies = [
              config.age.secrets.oauth2-proxy-cookie-secret
              config.age.secrets.oauth2-proxy-oidc-secret
            ];
            settings.keys = [
              "OAUTH2_PROXY_COOKIE_SECRET"
              "OAUTH2_PROXY_CLIENT_SECRET"
            ];
            generator.script = "environment-file";
          };
        };
      };

    service-domains = [ "oauth2-proxy" ];
  };
}
