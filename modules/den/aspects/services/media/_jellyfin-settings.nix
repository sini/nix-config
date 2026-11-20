# Jellyfin's settings as jellarr's config (github:sini/jellarr, schema at integ/main),
# shared by uplink's NixOS aspect (services/media/jellyfin.nix) and the cluster's
# (kubernetes/services/media/jellyfin.nix), so both instances are configured from one
# source (docs/jellyfin-to-k8s.md). The caller supplies what differs by where it runs.
#
# `config` is the attrset; `render` is the JSON (valid YAML) jellarr reads, with every
# `$` in a string escaped as `$$`: jellarr expands `${VAR}` in string values after
# parsing, and `$$` is its literal `$` (jellarr-0c, tested on 20+ line strings).
{ lib }:
let
  # Every string, at any depth, with `$` doubled. Attribute names are left alone:
  # jellarr expands values only.
  escape =
    v:
    if builtins.isString v then
      lib.replaceStrings [ "$" ] [ "$$" ] v
    else if builtins.isList v then
      map escape v
    else if builtins.isAttrs v then
      lib.mapAttrs (_: escape) v
    else
      v;

  # A secret by path: jellarr replaces it with the file's trimmed contents after
  # parsing (a missing file fails the run). The path goes through `escape` like any
  # string; store and /run paths hold no `$`.
  fileRef = path: { _file = path; };

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
in
rec {
  inherit escape fileRef;

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

  # The file jellarr reads (--configFile), as JSON (valid YAML).
  render = args: builtins.toJSON (escape (config args));
}
