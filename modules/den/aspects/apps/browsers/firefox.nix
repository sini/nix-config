{ inputs, ... }:
let
  inherit (inputs) betterfox shimmer;
in
{
  den.aspects.apps.firefox = {
    homeManager =
      {
        pkgs,
        ...
      }:
      let
        inherit (inputs.firefox-addons.packages.${pkgs.stdenv.hostPlatform.system})
          bitwarden
          ublock-origin
          sponsorblock
          darkreader
          ghostery
          return-youtube-dislikes
          firefox-color
          duckduckgo-privacy-essentials
          mal-sync
          sidebery
          ;
      in
      {
        programs.firefox = {
          enable = true;

          profiles = {
            default = {
              id = 0;
              isDefault = true;

              extensions.packages = [
                bitwarden
                ublock-origin
                sponsorblock
                darkreader
                ghostery
                return-youtube-dislikes
                firefox-color
                duckduckgo-privacy-essentials
                mal-sync
                sidebery
              ];

              preConfig = builtins.readFile "${betterfox.outPath}/user.js";
              userChrome = builtins.readFile "${shimmer.outPath}/userChrome.css";
              userContent = builtins.readFile "${shimmer.outPath}/userContent.css";

              extraConfig = builtins.concatStringsSep "\n" [
                (builtins.readFile "${betterfox.outPath}/Securefox.js")
                (builtins.readFile "${betterfox.outPath}/Fastfox.js")
                (builtins.readFile "${betterfox.outPath}/Peskyfox.js")
              ];

              settings = {
                # General
                "intl.accept_languages" = "en-US,en";
                "browser.startup.page" = 3;
                "browser.aboutConfig.showWarning" = false;
                "browser.ctrlTab.sortByRecentlyUsed" = false;
                "browser.download.useDownloadDir" = false;
                "privacy.clearOnShutdown.history" = false;

                # Dev console
                "devtools.chrome.enabled" = true;
                # Crash reporting
                "browser.tabs.crashReporting.sendReport" = false;
                "accessibility.typeaheadfind.enablesound" = false;
                "general.autoScroll" = true;

                # Hardware acceleration
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

                "app.normandy.enabled" = false;
                "app.shield.optoutstudies.enabled" = false;

                # Privacy
                "privacy.donottrackheader.enabled" = true;
                "privacy.trackingprotection.enabled" = true;
                "privacy.trackingprotection.socialtracking.enabled" = true;
                "privacy.userContext.enabled" = true;
                "privacy.userContext.ui.enabled" = true;
                "browser.send_pings" = false;

                # Telemetry
                "toolkit.telemetry.archive.enabled" = false;
                "toolkit.telemetry.enabled" = false;
                "toolkit.telemetry.server" = "";
                "toolkit.telemetry.unified" = false;
                "extensions.webcompat-reporter.enabled" = false;
                "datareporting.policy.dataSubmissionEnabled" = false;
                "datareporting.healthreport.uploadEnabled" = false;
                "browser.ping-centre.telemetry" = false;
                "browser.urlbar.eventTelemetry.enabled" = false;

                # Disable useless features
                "extensions.pocket.enabled" = false;
                "extensions.abuseReport.enabled" = false;
                "extensions.formautofill.creditCards.enabled" = false;
                "identity.fxaccounts.enabled" = false;
                "identity.fxaccounts.toolbar.enabled" = false;
                "identity.fxaccounts.pairing.enabled" = false;
                "identity.fxaccounts.commands.enabled" = false;
                "browser.contentblocking.report.lockwise.enabled" = false;
                "browser.uitour.enabled" = false;
                "browser.newtabpage.activity-stream.showSponsored" = false;
                "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;

                # Disable annoying web features
                "dom.push.enabled" = false;
                "dom.push.connection.enabled" = false;
                "dom.battery.enabled" = false;
                "dom.private-attribution.submission.enabled" = false;
              };

              search = {
                force = true;
                engines = {
                  "Nix Packages" = {
                    urls = [
                      {
                        template = "https://search.nixos.org/packages";
                        params = [
                          {
                            name = "type";
                            value = "packages";
                          }
                          {
                            name = "channel";
                            value = "unstable";
                          }
                          {
                            name = "query";
                            value = "{searchTerms}";
                          }
                        ];
                      }
                    ];
                    icon = "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
                    definedAliases = [ "@np" ];
                  };

                  "Nix Options" = {
                    urls = [
                      {
                        template = "https://search.nixos.org/options";
                        params = [
                          {
                            name = "type";
                            value = "options";
                          }
                          {
                            name = "channel";
                            value = "unstable";
                          }
                          {
                            name = "query";
                            value = "{searchTerms}";
                          }
                        ];
                      }
                    ];
                    icon = "''${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
                    definedAliases = [ "@no" ];
                  };

                  "HomeManager" = {
                    urls = [
                      { template = "https://home-manager-options.extranix.com/?query={searchTerms}&release=master"; }
                    ];
                    icon = "https://github.com/mipmip/home-manager-option-search/blob/main/images/favicon.png";
                    updateInterval = 24 * 60 * 60 * 1000;
                    definedAliases = [ "@hm" ];
                  };

                  "NixWiki" = {
                    urls = [ { template = "https://wiki.nixos.org/w/index.php?search={searchTerms}"; } ];
                    icon = "https://nixos.org/favicon.png";
                    updateInterval = 24 * 60 * 60 * 1000;
                    definedAliases = [ "@nw" ];
                  };
                };
                default = "Brave";
              };
            };
          };
        };

        stylix.targets.firefox.profileNames = [ "default" ];

        xdg.mimeApps.defaultApplications = {
          "text/html" = [ "firefox.desktop" ];
          "text/xml" = [ "firefox.desktop" ];
          "x-scheme-handler/http" = [ "firefox.desktop" ];
          "x-scheme-handler/https" = [ "firefox.desktop" ];
        };
      };

    provides.impermanence = {
      homeManager = {
        home.persistence."/cache".directories = [
          ".cache/mozilla"
        ];
        home.persistence."/persist".directories = [
          ".mozilla/firefox"
        ];
      };
    };
  };
}
