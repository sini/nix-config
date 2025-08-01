{ inputs, ... }:
{
  flake.modules.homeManager.firefox =
    { pkgs, ... }:
    {
      programs.firefox = {
        enable = true;
        profiles = {
          default = {
            id = 0;
            isDefault = true;

            extensions.packages = with pkgs.nur.repos.rycee.firefox-addons; [
              bitwarden
              ublock-origin
              sponsorblock
              return-youtube-dislikes
              firefox-color
              tampermonkey
              duckduckgo-privacy-essentials
              mal-sync
              sidebery
            ];

            preConfig = builtins.readFile "${inputs.betterfox.outPath}/user.js";
            userChrome = builtins.readFile "${inputs.shimmer.outPath}/userChrome.css";
            userContent = builtins.readFile "${inputs.shimmer.outPath}/userContent.css";

            extraConfig = builtins.concatStringsSep "\n" [
              (builtins.readFile "${inputs.betterfox.outPath}/Securefox.js")
              (builtins.readFile "${inputs.betterfox.outPath}/Fastfox.js")
              (builtins.readFile "${inputs.betterfox.outPath}/Peskyfox.js")
            ];

            settings = {
              # General
              "intl.accept_languages" = "en-US,en";
              "browser.startup.page" = 3; # Resume previous session on startup
              "browser.aboutConfig.showWarning" = false; # I sometimes know what I'm doing
              "browser.ctrlTab.sortByRecentlyUsed" = false; # Don't sort tabs by recently used
              "browser.download.useDownloadDir" = false; # Ask where to save stuff
              "privacy.clearOnShutdown.history" = false; # We want to save history on exit

              # Allow executing JS in the dev console
              "devtools.chrome.enabled" = true;
              # Disable browser crash reporting
              "browser.tabs.crashReporting.sendReport" = false;
              # Why the fuck can my search window make bell sounds
              "accessibility.typeaheadfind.enablesound" = false;
              # Why the fuck can my search window make bell sounds
              "general.autoScroll" = true;

              # Hardware acceleration
              # See https://github.com/elFarto/nvidia-vaapi-driver?tab=readme-ov-file#firefox
              "gfx.webrender.all" = true;
              "widget.dmabuf.force-enabled" = true;
              "media.av1.enabled" = true;
              "media.ffmpeg.vaapi.enabled" = true;
              "media.ffvpx.enabled" = false;
              "media.rdd-ffmpeg.enabled" = true;
              "media.rdd-vpx.enabled" = true;
              "media.rdd-process.enabled" = true;

              "shimmer.remove-winctr-buttons" = true;
              "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
              "svg.context-properties.content.enabled" = true;
              "browser.search.suggest.enabled" = true;
              "captivedetect.canonicalURL" = "http://detectportal.firefox.com/canonical.html";
              "network.captive-portal-service.enabled" = true;
              "network.connectivity-service.enabled" = true;
              "extensions.autoDisableScopes" = 0;

              # This allows firefox devs changing options for a small amount of users to test out stuff.
              # Not with me please ...
              "app.normandy.enabled" = false;
              "app.shield.optoutstudies.enabled" = false;

              # Privacy
              "privacy.donottrackheader.enabled" = true;
              "privacy.trackingprotection.enabled" = true;
              "privacy.trackingprotection.socialtracking.enabled" = true;
              "privacy.userContext.enabled" = true;
              "privacy.userContext.ui.enabled" = true;
              "browser.send_pings" = false; # (default) Don't respect <a ping=...>

              # Disable telemetry for privacy reasons
              "toolkit.telemetry.archive.enabled" = false;
              "toolkit.telemetry.enabled" = false; # enforced by nixos
              "toolkit.telemetry.server" = "";
              "toolkit.telemetry.unified" = false;
              "extensions.webcompat-reporter.enabled" = false; # don't report compability problems to mozilla
              "datareporting.policy.dataSubmissionEnabled" = false;
              "datareporting.healthreport.uploadEnabled" = false;
              "browser.ping-centre.telemetry" = false;
              "browser.urlbar.eventTelemetry.enabled" = false; # (default)

              # Disable some useless stuff
              "extensions.pocket.enabled" = false; # disable pocket, save links, send tabs
              "extensions.abuseReport.enabled" = false; # don't show 'report abuse' in extensions
              "extensions.formautofill.creditCards.enabled" = false; # don't auto-fill credit card information
              "identity.fxaccounts.enabled" = false; # disable firefox login
              "identity.fxaccounts.toolbar.enabled" = false;
              "identity.fxaccounts.pairing.enabled" = false;
              "identity.fxaccounts.commands.enabled" = false;
              "browser.contentblocking.report.lockwise.enabled" = false; # don't use firefox password manger
              "browser.uitour.enabled" = false; # no tutorial please
              "browser.newtabpage.activity-stream.showSponsored" = false;
              "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;

              # disable annoying web features
              "dom.push.enabled" = false; # no notifications, really...
              "dom.push.connection.enabled" = false;
              "dom.battery.enabled" = false; # you don't need to see my battery...
              "dom.private-attribution.submission.enabled" = false; # No PPA for me pls
            };

            search = {
              force = true;
              engines = {
                "Brave" = {
                  urls = [
                    { template = "https://search.brave.com/search?q={searchTerms}"; }
                    {
                      type = "application/x-suggestions+json";
                      template = "https://search.brave.com/api/suggest?q={searchTerms}";
                    }
                  ];

                  icon = "https://cdn.search.brave.com/serp/v2/_app/immutable/assets/safari-pinned-tab.539899c7.svg";
                  updateInterval = 24 * 60 * 60 * 1000;
                  definedAliases = [ "!br" ];
                };
                "NixOS Packages" = {
                  urls = [
                    {
                      template = "https://search.nixos.org/packages?channel=unstable&from=0&size=50&sort=relevance&type=packages&query={searchTerms}";
                    }
                  ];
                  icon = "https://nixos.org/favicon.png";
                  updateInterval = 24 * 60 * 60 * 1000;
                  definedAliases = [ "!ns" ];
                };
                "NixOS Options" = {
                  urls = [
                    {
                      template = "https://search.nixos.org/options?channel=unstable&from=0&size=50&sort=relevance&type=packages&query={searchTerms}";
                    }
                  ];
                  icon = "https://nixos.org/favicon.png";
                  updateInterval = 24 * 60 * 60 * 1000;
                  definedAliases = [ "!no" ];
                };
                "HomeManager" = {
                  urls = [
                    { template = "https://home-manager-options.extranix.com/?query={searchTerms}&release=master"; }
                  ];
                  icon = "https://github.com/mipmip/home-manager-option-search/blob/main/images/favicon.png";
                  updateInterval = 24 * 60 * 60 * 1000;
                  definedAliases = [ "!hs" ];
                };
                "NixWiki" = {
                  urls = [ { template = "https://wiki.nixos.org/w/index.php?search={searchTerms}"; } ];
                  icon = "https://nixos.org/favicon.png";
                  updateInterval = 24 * 60 * 60 * 1000;
                  definedAliases = [ "!nw" ];
                };
              };
              default = "Brave";
            };
          };
        };
      };
      xdg.mimeApps.defaultApplications = {
        "text/html" = [ "firefox.desktop" ];
        "text/xml" = [ "firefox.desktop" ];
        "x-scheme-handler/http" = [ "firefox.desktop" ];
        "x-scheme-handler/https" = [ "firefox.desktop" ];
      };
    };
}
