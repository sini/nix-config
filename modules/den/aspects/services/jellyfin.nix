{
  den,
  lib,
  config,
  inputs,
  ...
}:
let
  environments = config.den.environments;
in
{
  den.aspects.services.jellyfin = {
    includes = [ den.aspects.services.nginx ];

    nixos =
      {
        config,
        host,
        pkgs,
        ...
      }:
      let
        env = environments.${host.environment};
        domain = env.getDomainFor "jellyfin";
        mediaRoot = "/mnt/data/media";
      in
      {
        imports = [
          inputs.declarative-jellyfin.nixosModules.default
        ];

        users.deterministicIds.jellyfin =
          let
            uidGid = id: {
              uid = id;
              gid = id;
            };
          in
          uidGid 1027;

        services = {
          declarative-jellyfin = {
            enable = true;
            serverId = builtins.hashString "md5" domain;

            package = pkgs.jellyfin;

            network = {
              enableIPv6 = true;
              enableHttps = false;
              internalHttpPort = 8096;
              publicHttpPort = 8096;
              publishedServerUriBySubnet = [ "all=https://${domain}" ];
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
                <form action="https://${domain}/sso/OID/start/kanidm">
                  <button class="raised block emby-button button-submit">
                    Sign in with SSO
                  </button>
                </form>
              '';
              customCss = ''
                 /* Hide manual login form */
                .manualLoginForm {
                  display: none !important;
                }

                /* Hide 'Forgot password' button */
                .btnForgotPassword {
                  display: none !important;
                }

                /* Add SSO button */
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

          nginx.virtualHosts."${domain}" = {
            forceSSL = true;
            useACMEHost = env.getTopDomainFor "jellyfin";
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
        };
      };

    firewall = {
      networking.firewall.allowedTCPPorts = [
        7359
        8096
        8920
      ];
    };

    service-domains = [ "jellyfin" ];

    persist = {
      directories = [
        {
          directory = "/var/lib/jellyfin";
          user = "jellyfin";
          group = "jellyfin";
          mode = "0700";
        }
      ];
    };
  };
}
