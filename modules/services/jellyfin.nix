{
  flake.features.jellyfin = {
    requires = [ "media-data-share" ];

    nixos =
      {
        inputs,
        config,
        ...
      }:
      let
        mediaRoot = "/mnt/data/media";
      in
      {

        imports = [
          inputs.declarative-jellyfin.nixosModules.default
        ];

        services = {
          declarative-jellyfin = {
            enable = true;
            serverId = (builtins.hashString "md5" "jellyfin.${config.networking.domain}");

            # This user is configured in ./modules/users/media/media.nix and is a normal user for legacy/NAS reasons
            user = "media";
            group = "media";

            network = {
              enableIPv6 = true;
              enableHttps = false; # Handled by Nginx
              internalHttpPort = 8096;
              publicHttpPort = 8096;
              publishedServerUriBySubnet = [ "all=https://jellyfin.${config.networking.domain}}" ];
            };

            encoding = {
              enableVppTonemapping = true;
              enableTonemapping = true;
              tonemappingAlgorithm = "bt2390";
              enableHardwareEncoding = true;
              hardwareAccelerationType = "vaapi";
              enableDecodingColorDepth10Hevc = true;
              allowHevcEncoding = true;
              allowAv1Encoding = true;
              hardwareDecodingCodecs = [
                "h264"
                "hevc"
                "mpeg2video"
                "vc1"
                "vp9"
                "vp8"
                "av1"
              ];
            };

            system = {
              trickplayOptions = {
                enableHwAcceleration = true;
                enableHwEncoding = true;
                enableKeyFrameOnlyExtraction = true;
                processThreads = 2;
              };
              pluginRepositories = [
                {
                  content = {
                    Name = "Jellyfin Stable";
                    Url = "https://repo.jellyfin.org/files/plugin/manifest.json";
                  };
                  tag = "RepositoryInfo";
                }
                {
                  content = {
                    Name = "Jellyfin SSO Plugin";
                    Url = "https://raw.githubusercontent.com/9p4/jellyfin-plugin-sso/manifest-release/manifest.json";
                  };
                  tag = "RepositoryInfo";
                }
                {
                  content = {
                    Name = "Intro Skipper";
                    Url = "https://intro-skipper.org/manifest.json";
                  };
                  tag = "RepositoryInfo";
                }
              ];
            };

            libraries = {
              Movies = {
                enabled = true;
                contentType = "movies";
                pathInfos = [ "${mediaRoot}/movies" ];
                typeOptions.Movies = {
                  metadataFetchers = [
                    "The Open Movie Database"
                    "TheMovieDb"
                  ];
                  imageFetchers = [
                    "The Open Movie Database"
                    "TheMovieDb"
                  ];
                };
              };
              Shows = {
                enabled = true;
                contentType = "tvshows";
                pathInfos = [ "${mediaRoot}/tv" ];
                enableAutomaticSeriesGrouping = true;
              };
              Anime = {
                enabled = true;
                contentType = "tvshows";
                pathInfos = [ "${mediaRoot}/anime" ];
                enableAutomaticSeriesGrouping = true;
              };
              Books = {
                enabled = true;
                contentType = "books";
                pathInfos = [ "${mediaRoot}/books" ];
              };
              Music = {
                enabled = true;
                contentType = "music";
                pathInfos = [ "${mediaRoot}/music" ];
              };
              "Music Videos" = {
                enabled = true;
                contentType = "musicvideos";
                pathInfos = [ "${mediaRoot}/mv" ];
              };
              "Concerts" = {
                enabled = true;
                contentType = "musicvideos";
                pathInfos = [ "${mediaRoot}/concerts" ];
              };
            };

            users = {
              Admin = {
                mutable = false;
                hashedPassword = "$PBKDF2-SHA512$iterations=210000$40ED1F46D80C99D30D668942213CC8AB$4118D9203F97D407B57E3D1B4C24B6DB844D3777736D80283FC1942BFF5E834AF4CE174B8F8FAB85ED0E2B5579066A0250BCECE434811EA451D30C07F9AD00A6";
                permissions = {
                  isAdministrator = true;
                };
              };
            };

            branding = {
              loginDisclaimer = ''
                <form action="https://jellyfin.${config.networking.domain}/sso/OID/start/kanidm">
                  <button class="raised block emby-button button-submit">
                    Sign in with SSO
                  </button>
                </form>
              '';
              customCss = ''
                a.raised.emby-button {
                  padding: 0.9em 1em;
                  color: inherit !important;
                }

                .disclaimerContainer {
                  display: block;
                }
              '';
            };
          };
        };

        # TODO: auto-configure SSO, see https://github.com/tecosaur/golgi/blob/568849ce1d6601e1a478b77ad71437aa177a2f5c/modules/streaming/jellyfin.nix#L14

        services.nginx.virtualHosts = {
          "jellyfin.${config.networking.domain}" = {
            forceSSL = true;
            useACMEHost = config.networking.domain;
            locations."/" = {
              proxyPass = "http://127.0.0.1:8096";
              proxyWebsockets = true;
              extraConfig = ''
                proxy_connect_timeout 5s;
                proxy_read_timeout 3600s;
                proxy_send_timeout 3600s;

                proxy_set_header Host $host;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header X-Forwarded-Proto $scheme;
                proxy_set_header X-Forwarded-Protocol $scheme;
                proxy_set_header X-Forwarded-Host $http_host;

                client_max_body_size 256m;
                proxy_buffering off;
              '';
            };
          };
        };

        environment.persistence = {
          "/persist".directories = [
            {
              directory = "/var/lib/jellyfin";
              user = config.services.jellyfin.user;
              group = config.services.jellyfin.group;
              mode = "0700";
            }
          ];
        };
      };
  };
}
