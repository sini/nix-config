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
    # instance; builtins.toJSON of the result is the file for --configFile. Strings go
    # through as written: jellarr (0.6+) expands `${VAR}` only with `expandEnv`, which
    # is off. A secret goes in as { _file = path; }, which jellarr replaces with the
    # file's contents.
    settings.jellarr = lib.mkOption {
      type = lib.types.functionTo lib.types.attrs;
      description = "Instance values -> jellarr's config.";
      default =
        let
          library = name: collectionType: dir: extra: {
            inherit name collectionType;
            libraryOptions = {
              enabled = true;
              pathInfos = [ { path = dir; } ];
            }
            // extra;
          };
          movieFetchers =
            let
              fetchers = [
                "The Open Movie Database"
                "TheMovieDb"
              ];
            in
            {
              typeOptions = [
                {
                  type = "Movie";
                  metadataFetchers = fetchers;
                  metadataFetcherOrder = fetchers;
                  imageFetchers = fetchers;
                  imageFetcherOrder = fetchers;
                }
              ];
            };

          # The anime libraries are Shokofin's (Shoko's AniDB-matched metadata), shows and
          # movies apart (Shokofin's SeparateMovies). Shokofin manages a library only when
          # Shoko is one of its metadata fetchers (ShokoIdLookup.IsEnabledForLibraryOptions);
          # Shoko's docs: Shoko alone as the metadata provider, and the first image fetcher
          # (Screen Grabber is safe after it). With its VFS on, Shokofin swaps the media
          # path for its VFS root, so the path is only set at creation.
          shoko =
            types:
            let
              option = type: images: {
                inherit type;
                metadataFetchers = [ "Shoko" ];
                metadataFetcherOrder = [ "Shoko" ];
                imageFetchers = images;
                imageFetcherOrder = images;
              };
              withGrabber = [
                "Shoko"
                "Screen Grabber"
              ];
            in
            {
              typeOptions = map (
                t: option t (if t == "Episode" || t == "Movie" then withGrabber else [ "Shoko" ])
              ) types;
              # Mixed metadata otherwise (Shoko's docs).
              enableEmbeddedTitles = false;
              enableEmbeddedEpisodeInfos = false;
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
                  # K0lin's maintained fork of 9p4's SSO-Auth: the same plugin GUID and
                  # configuration, built for Jellyfin 12 (9p4 has no 12 build).
                  {
                    name = "SSO Authentication (K0lin)";
                    url = "https://raw.githubusercontent.com/k0lin/jellyfin-plugin-sso/manifest-release/manifest.json";
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
                  # Shokofin's only Jellyfin 12 build is on its dev channel (owner, 2026-11-21).
                  {
                    name = "Shokofin Dev";
                    url = "https://raw.githubusercontent.com/ShokoAnime/Shokofin/metadata/dev/manifest.json";
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
                (
                  library "Anime" "tvshows" "${mediaRoot}/anime" (
                    shoko [
                      "Series"
                      "Season"
                      "Episode"
                    ]
                    // {
                      enableAutomaticSeriesGrouping = true;
                    }
                  )
                  // {
                    ignoreChanges = [ "pathInfos" ];
                  }
                )
                (
                  library "AnimeMovies" "movies" "${mediaRoot}/anime-movies" (shoko [ "Movie" ])
                  // {
                    ignoreChanges = [ "pathInfos" ];
                  }
                )
                (library "Books" "books" "${mediaRoot}/books" { })
                (library "Music" "music" "${mediaRoot}/music" { })
                (library "MusicVideos" "musicvideos" "${mediaRoot}/mv" { })
                (library "Concerts" "musicvideos" "${mediaRoot}/concerts" { })
              ];

              # Admin's password is checked on every run and reset to the file if it
              # drifted (opt-in since jellarr 0.6; it was the default before).
              reconcilePasswords = true;

              # Only Admin is declared; SSO creates the rest (authoritative.users in the
              # cluster's call decides what happens to the ones that leave).
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

              # Catalog names, matched by GUID; pinned to their Jellyfin 12 (targetAbi 12.x)
              # builds, each from the repository that carries it (jellarr 0.3.3 `repository`).
              # Their configuration (SSO-Auth, Shokofin) is declared once read from the live
              # instance (GET /Plugins/{id}/Configuration); until then jellarr leaves it as it is.
              plugins = [
                {
                  name = "SSO Authentication";
                  version = "5.1.1";
                  repository = "SSO Authentication (K0lin)";
                }
                {
                  name = "Shoko";
                  version = "6.0.5.4012";
                  repository = "Shokofin Dev";
                }
                {
                  name = "TMDb Box Sets";
                  version = "15.0.0.0";
                  repository = "Jellyfin Stable";
                }
              ];
            };
        in
        config;
    };

    includes = [
      den.aspects.services.networking.nginx
      den.aspects.services.storage.media-data-share
    ];

    age-secrets =
      { environment, ... }:
      {
        # The cluster's values (kubernetes/services/media/jellyfin.nix generates them),
        # so the data migration carries a database whose key and Admin password match.
        age.secrets = {
          jellyfin-api-key.rekeyFile = environment.secretPath + "/jellyfin/api-key.age";
          jellyfin-admin-password.rekeyFile = environment.secretPath + "/jellyfin/admin-password.age";
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
        domain = environment.getDomainFor "jellyfin";
      in
      {
        imports = [ inputs.jellarr.nixosModules.default ];

        users.users.jellyfin = {
          uid = 1027;
          group = "jellyfin";
          isSystemUser = true;
        };
        users.groups.jellyfin.gid = 1027;

        services.jellyfin = {
          enable = true;
          # Jellyfin 12 (uplink's channel, nixpkgs-master), docs/jellyfin-to-k8s.md step 2.
          package = pkgs.jellyfin;
        };

        services.jellarr = {
          enable = true;
          package = inputs.jellarr.packages.${pkgs.stdenv.hostPlatform.system}.default;
          apiKeyFile = config.age.secrets.jellyfin-api-key.path;
          # A major upgrade's database migration runs before /System/Info/Public answers.
          waitTimeout = 1800;
          # Seeds the key into jellyfin.db (one stop and start of Jellyfin, skipped
          # once the key is there).
          bootstrap.enable = true;
          configFile = pkgs.writeText "jellarr.json" (
            builtins.toJSON (
              host.settings.services.media.jellyfin.jellarr {
                baseUrl = "http://127.0.0.1:8096";
                inherit domain;
                # LoadCredential below; a literal path (jellarr expands no `${VAR}`).
                adminPasswordFile = "/run/credentials/jellarr.service/admin-password";
                knownProxies = [ "127.0.0.1" ];
                hardwareDecodingCodecs = [
                  "h264"
                  "hevc"
                  "mpeg2video"
                  "vc1"
                  "vp9"
                  "vp8"
                  "av1"
                ];
              }
            )
          );
        };
        systemd.services.jellarr.serviceConfig.LoadCredential = [
          "admin-password:${config.age.secrets.jellyfin-admin-password.path}"
        ];

        services.nginx.virtualHosts."${domain}" = {
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
