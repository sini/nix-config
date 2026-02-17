{
  flake.features.jellyfin = {
    requires = [ "media-data-share" ];

    nixos =
      {
        inputs,
        config,
        pkgs,
        environment,
        ...
      }:
      let
        mediaRoot = "/mnt/data/media";
      in
      {

        imports = [
          inputs.declarative-jellyfin.nixosModules.default
        ];

        networking.firewall.allowedTCPPorts = [
          7359
          8096
          8920
        ];

        services = {
          declarative-jellyfin = {
            enable = true;
            serverId = (builtins.hashString "md5" "jellyfin.${environment.domain}");

            # Upstream declarative-jellfin locked version is broken against unstable
            package = pkgs.jellyfin;

            # This user is configured in ./modules/users/media/media.nix and is a normal user for legacy/NAS reasons
            user = "media";
            group = "media";

            network = {
              enableIPv6 = true;
              enableHttps = false; # Handled by Nginx
              internalHttpPort = 8096;
              publicHttpPort = 8096;
              publishedServerUriBySubnet = [ "all=https://jellyfin.${environment.domain}" ];
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
              MusicVideos = {
                enabled = true;
                contentType = "musicvideos";
                pathInfos = [ "${mediaRoot}/mv" ];
              };
              Concerts = {
                enabled = true;
                contentType = "musicvideos";
                pathInfos = [ "${mediaRoot}/concerts" ];
              };
            };

            users = {
              Admin = {
                mutable = false;
                hashedPassword = "$PBKDF2-SHA512$iterations=210000$E7332528F62FF592B1BC0BDC5B40E709$C86BCCB2501A0E816F9AA90B775D2D95F7A23791A1EE5EBD2DB0812B87BCF179AF18E682C224E429D03DA51C4E262D1D1C6A2EA0964C7E2957C831CB80B85DC8";
                permissions = {
                  isAdministrator = true;
                };
              };
            };

            branding = {
              loginDisclaimer = ''
                <form action="https://jellyfin.${environment.domain}/sso/OID/start/kanidm">
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

        services.nginx.virtualHosts."jellyfin.${environment.domain}" = {
          forceSSL = true;
          useACMEHost = environment.domain;
          locations."/" = {
            proxyPass = "http://127.0.0.1:8096";
            extraConfig = ''
              proxy_buffering off;
              proxy_set_header X-Forwarded-Protocol $scheme;
            '';
          };
          locations."/socket" = {
            proxyPass = "http://127.0.0.1:8096";
            proxyWebsockets = true;
            extraConfig = ''
              proxy_set_header X-Forwarded-Protocol $scheme;
            '';
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
