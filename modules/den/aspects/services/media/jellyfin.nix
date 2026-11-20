{
  den,
  inputs,
  lib,
  ...
}:
let
  serviceDomains = [ "jellyfin" ];
in
{
  den.aspects.services.media.jellyfin = {
    # Jellyfin's settings as jellarr's config (github:sini/jellarr), one declaration
    # for every instance (docs/jellyfin-to-k8s.md): uplink reads it as
    # host.settings.services.media.jellyfin.jellarr, the cluster as
    # cluster.settings.services.media.jellyfin.jellarr. Call it with what differs per
    # instance; it returns the config with every `${` in a string escaped as `$${`
    # (jellarr expands `${VAR}` in string values after parsing; `$${` is its literal
    # `${`, and any other `$` stays as written), so builtins.toJSON of the result is
    # the file for --configFile. A secret goes in as
    # { _file = path; }, which jellarr replaces with the file's contents.
    settings.jellarr = lib.mkOption {
      type = lib.types.functionTo lib.types.attrs;
      description = "Instance values -> jellarr's config (escaped).";
      default =
        let
          # Every string, at any depth, with `${` written as `$${`, jellarr's escape for a
          # literal `${`. Any other `$` passes through jellarr unchanged, so nothing else
          # needs escaping. Attribute names are left alone: jellarr expands values only.
          escape =
            v:
            if builtins.isString v then
              lib.replaceStrings [ "\${" ] [ "$\${" ] v
            else if builtins.isList v then
              map escape v
            else if builtins.isAttrs v then
              lib.mapAttrs (_: escape) v
            else
              v;

          library = name: collectionType: dir: extra: {
            inherit name collectionType;
            libraryOptions = {
              enabled = true;
              pathInfos = [ { path = dir; } ];
            }
            // extra;
          };
          movieFetchers = {
            typeOptions = [
              {
                type = "Movie";
                metadataFetchers = [
                  "The Open Movie Database"
                  "TheMovieDb"
                ];
                imageFetchers = [
                  "The Open Movie Database"
                  "TheMovieDb"
                ];
              }
            ];
          };
          config =
            {
              # Where jellarr reaches the API, e.g. http://127.0.0.1:8096.
              baseUrl,
              # The public name, for published server URIs and the SSO button.
              domain,
              # The library root, the same path on every instance so a migrated database's
              # library paths stay valid.
              mediaRoot ? "/mnt/data/media",
              # The admin's password, as a file (agenix).
              adminPasswordFile,
              # Addresses Jellyfin trusts for X-Forwarded-For (its reverse proxy).
              knownProxies,
              # The VA-API render node and what this GPU decodes.
              vaapiDevice ? "/dev/dri/renderD128",
              hardwareDecodingCodecs,
              allowAv1Encoding ? true,
            }:
            {
              version = 1;
              base_url = baseUrl;

              system = {
                enableMetrics = true;
                pluginRepositories = [
                  {
                    name = "Jellyfin Stable";
                    url = "https://repo.jellyfin.org/files/plugin/manifest.json";
                    enabled = true;
                  }
                  {
                    name = "Jellyfin SSO Plugin";
                    url = "https://raw.githubusercontent.com/9p4/jellyfin-plugin-sso/manifest-release/manifest.json";
                    enabled = true;
                  }
                  {
                    name = "Intro Skipper";
                    url = "https://intro-skipper.org/manifest.json";
                    enabled = true;
                  }
                  {
                    name = "Shokofin";
                    url = "https://raw.githubusercontent.com/ShokoAnime/Shokofin/metadata/stable/manifest.json";
                    enabled = true;
                  }
                ];
                trickplayOptions = {
                  enableHwAcceleration = true;
                  enableHwEncoding = true;
                  enableKeyFrameOnlyExtraction = true;
                  processThreads = 2;
                };
              };

              networking = {
                enableIPv6 = true;
                enableHttps = false;
                internalHttpPort = 8096;
                publicHttpPort = 8096;
                publishedServerUriBySubnet = [ "all=https://${domain}" ];
                inherit knownProxies;
              };

              encoding = {
                enableHardwareEncoding = true;
                hardwareAccelerationType = "vaapi";
                inherit vaapiDevice hardwareDecodingCodecs allowAv1Encoding;
                enableDecodingColorDepth10Hevc = true;
                allowHevcEncoding = true;
                enableTonemapping = true;
                enableVppTonemapping = true;
                tonemappingAlgorithm = "bt2390";
              };

              library.virtualFolders = [
                (library "Movies" "movies" "${mediaRoot}/movies" movieFetchers)
                (library "Shows" "tvshows" "${mediaRoot}/tv" { enableAutomaticSeriesGrouping = true; })
                (library "Anime" "tvshows" "${mediaRoot}/anime" { enableAutomaticSeriesGrouping = true; })
                (library "AnimeMovies" "movies" "${mediaRoot}/anime-movies" { })
                (library "Books" "books" "${mediaRoot}/books" { })
                (library "Music" "music" "${mediaRoot}/music" { })
                (library "MusicVideos" "musicvideos" "${mediaRoot}/mv" { })
                (library "Concerts" "musicvideos" "${mediaRoot}/concerts" { })
              ];

              # Only Admin is declared; SSO creates the rest, and jellarr never reads or
              # touches undeclared users. On a migrated database the first run resets
              # Admin's password to this file (jellarr's passwordFile reconciliation).
              users = [
                {
                  name = "Admin";
                  passwordFile = adminPasswordFile;
                  policy.isAdministrator = true;
                }
              ];

              # The admin for a pristine server's first-run wizard; ignored once the wizard
              # has completed.
              startup = {
                completeStartupWizard = true;
                user = {
                  name = "Admin";
                  passwordFile = adminPasswordFile;
                };
                remoteAccess = {
                  enableRemoteAccess = true;
                  enableAutomaticPortMapping = false;
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

              # Catalog names; installed plugins are matched by GUID and never reinstalled.
              # Pinned to uplink's installed versions, so the switch to jellarr changes no
              # plugin (the catalog's TMDb Box Sets is already 15.0.0.0); they move with
              # Jellyfin 12. Their configuration (SSO-Auth, Shokofin) is declared once read
              # from the live instance (GET /Plugins/{id}/Configuration); until then jellarr
              # leaves it as it is.
              plugins = [
                {
                  name = "SSO Authentication";
                  version = "4.0.0.4";
                }
                {
                  name = "Shoko";
                  version = "6.0.5.11";
                }
                {
                  name = "TMDb Box Sets";
                  version = "13.0.0.0";
                }
              ];
            };
        in
        args: escape (config args);
    };

    includes = [
      den.aspects.services.networking.nginx
      den.aspects.services.storage.media-data-share
    ];

    nixos =
      {
        environment,
        host,
        pkgs,
        ...
      }:
      let
        domain = environment.getDomainFor "jellyfin";
        mediaRoot = "/mnt/data/media";
        # declarative-jellyfin supports 10.11.x at most; nixpkgs-master ships 12.0.
        stable = inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
      in
      {
        imports = [
          inputs.declarative-jellyfin.nixosModules.default
        ];

        users.users.jellyfin = {
          uid = 1027;
          group = "jellyfin";
          isSystemUser = true;
        };
        users.groups.jellyfin.gid = 1027;

        services = {
          declarative-jellyfin = {
            enable = true;
            serverId = builtins.hashString "md5" domain;

            package = stable.jellyfin;
            jellyfin-web = stable.jellyfin-web;
            jellyfin-ffmpeg = stable.jellyfin-ffmpeg;

            network = {
              enableIPv6 = true;
              enableHttps = false;
              internalHttpPort = 8096;
              publicHttpPort = 8096;
              publishedServerUriBySubnet = [ "all=https://${domain}" ];
            };

            encoding = {
              encoderAppPathDisplay = "${stable.jellyfin-ffmpeg}";
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
                {
                  content = {
                    Name = "Shokofin";
                    Url = "https://raw.githubusercontent.com/ShokoAnime/Shokofin/metadata/stable/manifest.json";
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
              AnimeMovies = {
                enabled = true;
                contentType = "movies";
                pathInfos = [ "${mediaRoot}/anime-movies" ];
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
        };
      };

    firewall = {
      networking.firewall.allowedTCPPorts = [
        7359
        8096
        8920
      ];
    };

    served-domains = { environment, host, ... }: environment.servedDomains host serviceDomains;

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
