{ den, ... }:
{
  den.aspects.services.ai.open-webui = {
    includes = [ den.aspects.services.networking.nginx ];

    nixos =
      {
        ollama-endpoints,
        environment,
        config,
        ...
      }:
      let
        domain = environment.getDomainFor "open-webui";
        kanidmDomain = environment.getDomainFor "kanidm";

        # Collect ollama IPs (same-environment scoping guaranteed by
        # collect-ollama-endpoints policy)
        ollamaHosts = builtins.sort (a: b: a < b) (map (e: e.ip) ollama-endpoints);
      in
      {
        services = {
          open-webui = {
            enable = true;
            host = "127.0.0.1";
            port = 10715;
            stateDir = "/var/lib/open-webui";
            environment = {
              WEBUI_NAME = "LLM @ Home";
              WEBUI_URL = "https://${domain}";

              OLLAMA_BASE_URLS = builtins.concatStringsSep ";" (
                [ "http://10.9.2.2:11434" ] ++ (map (ip: "http://${ip}:11434") ollamaHosts)
              );

              SHOW_ADMIN_DETAILS = "False";

              ENABLE_SIGNUP_PASSWORD_CONFIRMATION = "True";
              ENABLE_SIGNUP = "False";
              ENABLE_LOGIN_FORM = "False";
              DEFAULT_USER_ROLE = "user";

              ENABLE_OAUTH_SIGNUP = "True";
              OAUTH_UPDATE_PICTURE_ON_LOGIN = "True";
              ENABLE_OAUTH_PERSISTENT_CONFIG = "False";
              OAUTH_MERGE_ACCOUNTS_BY_EMAIL = "True";

              OAUTH_CLIENT_ID = "open-webui";
              OPENID_PROVIDER_URL = "https://${kanidmDomain}/oauth2/openid/open-webui/.well-known/openid-configuration";
              OAUTH_CODE_CHALLENGE_METHOD = "S256";
              OAUTH_PROVIDER_NAME = "idm";
              OAUTH_ALLOWED_ROLES = "user";
              OAUTH_ADMIN_ROLES = "admin";
              ENABLE_OAUTH_ROLE_MANAGEMENT = "True";
              ENABLE_OAUTH_GROUP_MANAGEMENT = "True";

              RESET_CONFIG_ON_START = "True";
              ENABLE_OPENAI_API = "False";

              ENABLE_VERSION_UPDATE_CHECK = "False";

              ENABLE_CHANNELS = "True";
              ENABLE_REALTIME_CHAT_SAVE = "True";

              ENABLE_API_KEY_ENDPOINT_RESTRICTIONS = "True";
              ENABLE_FORWARD_USER_INFO_HEADERS = "True";

              PDF_EXTRACT_IMAGES = "True";

              ENABLE_IMAGE_GENERATION = "True";

              RAG_FULL_CONTEXT = "True";
              ENABLE_RAG_LOCAL_WEB_FETCH = "True";
              ENABLE_WEB_SEARCH = "True";
              ENABLE_RAG_WEB_SEARCH = "True";

              ANONYMIZED_TELEMETRY = "False";
              DO_NOT_TRACK = "True";
              SCARF_NO_ANALYTICS = "True";

              ENABLE_COMMUNITY_SHARING = "False";
              ENABLE_ADMIN_EXPORT = "False";
            };

            environmentFile = config.age.secrets.open-webui-env.path;
          };

          nginx = {
            virtualHosts = {
              "${domain}" = {
                forceSSL = true;
                useACMEHost = environment.domain;
                locations."/" = {
                  proxyPass = "http://127.0.0.1:10715";
                  proxyWebsockets = true;
                  extraConfig = ''
                    client_max_body_size 256m;
                    proxy_buffering off;
                  '';
                };
              };
            };
          };
        };

        users.groups.open-webui = { };
        users.users.open-webui = {
          group = "open-webui";
          isSystemUser = true;
        };

        systemd.services.open-webui.serviceConfig = {
          User = "open-webui";
          Group = "open-webui";
        };
      };

    age-secrets =
      { environment, config, ... }:
      {
        age.secrets = {
          open-webui-oidc-secret = {
            rekeyFile = environment.secretPath + "/oidc/open-webui-oidc-client-secret.age";
            generator = {
              tags = [ "oidc" ];
              script = "rfc3986-secret";
            };
            intermediary = true;
          };

          open-webui-env = {
            generator.dependencies = [ config.age.secrets.open-webui-oidc-secret ];
            settings.keys = [ "OAUTH_CLIENT_SECRET" ];
            generator.script = "environment-file";
          };
        };
      };

    service-domains = [ "open-webui" ];

    persist = {
      directories = [
        {
          directory = "/var/lib/private/open-webui";
          user = "open-webui";
          group = "open-webui";
          mode = "0700";
        }
      ];
    };
  };
}
