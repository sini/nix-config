# Chromium. On Linux it's the native nixpkgs build configured via
# programs.chromium. nixpkgs chromium doesn't build on darwin, so macOS installs
# the `chromium` cask and reapplies the portable parts of the config — the
# extension set and privacy/telemetry hardening — through Chromium's managed
# policy engine. The Wayland/ozone and VAAPI bits are Linux-only.
let
  # Web Store extension set shared by the Linux install and the macOS policy
  # force-list. Mirrors the firefox addon set; firefox-only addons
  # (firefox-color, sidebery) have no chromium equivalent and are dropped.
  extensions = [
    {
      id = "cjpalhdlnbpafiamejdnhcphjbkeiagm";
      name = "uBlock Origin";
    }
    {
      id = "nngceckbapebfimnlniiiahkandclblb";
      name = "Bitwarden";
    }
    {
      id = "mnjggcdmjocbbbhaepdhchncahnbgone";
      name = "SponsorBlock";
    }
    {
      id = "eimadpbcbfnmbkopoojfekhnkhdbieeh";
      name = "Dark Reader";
    }
    {
      id = "mlomiejdfkolichcflejclcbmpeaniij";
      name = "Ghostery";
    }
    {
      id = "gebbhagfogifgggkldgodflihgfeippi";
      name = "Return YouTube Dislike";
    }
    {
      id = "bkdgflcldnnnapblkhphbgpggdiikppg";
      name = "DuckDuckGo Privacy Essentials";
    }
    {
      id = "kekjfbackdeiabghhcdklcdoekaanoel";
      name = "MAL-Sync";
    }
  ];
  extensionIds = map (e: e.id) extensions;
in
{
  den.aspects.apps.browsers.chromium = {
    homebrew-cask = [ "chromium" ];

    homeLinux =
      {
        lib,
        pkgs,
        ...
      }:
      let
        inherit (lib.strings) concatStringsSep enableFeature;

        # Folded into a single --enable-features= switch below; Chromium does not
        # reliably merge multiple occurrences of the flag.
        enabledFeatures = [
          # Wayland
          "UseOzonePlatform"
          "WaylandWindowDecorations"

          # Hardware video acceleration (mirrors firefox media.ffmpeg.vaapi.enabled)
          "VaapiVideoDecoder"
          "VaapiVideoEncoder"

          # Network-state partitioning (privacy isolation)
          "PartitionVisitedLinkDatabase"
          "PrefetchPrivacyChanges"
          "SplitCacheByNetworkIsolationKey"
          "SplitCodeCacheByNetworkIsolationKey"
          "EnableCrossSiteFlagNetworkIsolationKey"
          "PartitionConnectionsByNetworkIsolationKey"
          "StrictOriginIsolation"
          "ReduceAcceptLanguage"
          "ContentSettingsPartitioning"
        ];

        disabledFeatures = [
          # Autofill (mirrors firefox extensions.formautofill.creditCards.enabled = false)
          "AutofillServerCommunication"
          "AutofillPaymentCardBenefits"
          "AutofillPaymentCvcStorage"

          # Third-party cookie deprecation bypasses
          "TpcdHeuristicsGrants"
          "TpcdMetadataGrants"

          # Hyperlink auditing (mirrors browser.send_pings = false)
          "EnableHyperlinkAuditing"

          # New-tab-page clutter (mirrors activity-stream.showSponsored = false)
          "NTPPopularSitesBakedInContent"
          "UsePopularSitesSuggestions"
          "EnableSnippets"
          "ArticlesListVisible"
          "InterestFeedV2"

          # Privacy Sandbox / Topics (mirrors privacy.trackingprotection + private-attribution)
          "PrivacySandboxSettings4"
          "BrowsingTopics"
          "BrowsingTopicsDocumentAPI"
          "BrowsingTopicsParameters"

          # Telemetry / background fetching (mirrors toolkit.telemetry.* = false)
          "OptimizationHintsFetching"
          "MediaDrmPreprovisioning"
          "PreloadMediaEngagementData"
          "MediaEngagementBypassAutoplayPolicies"
        ];
      in
      {
        programs.chromium = {
          enable = true;

          package = pkgs.chromium.override {
            enableWideVine = true;
          };

          extensions = extensionIds;

          commandLineArgs = [
            # Wayland
            "--ozone-platform=wayland"

            # GPU + hardware video acceleration (mirrors firefox gfx.webrender.all)
            "--ignore-gpu-blocklist"
            (enableFeature true "gpu-rasterization")
            (enableFeature true "oop-rasterization")
            (enableFeature true "zero-copy")

            # Quality of life
            "--no-first-run"
            "--no-default-browser-check"

            # Crash reporting (mirrors browser.tabs.crashReporting.sendReport = false)
            "--disable-breakpad"
            "--no-crash-upload"

            # Privacy / telemetry
            "--no-pings"
            "--no-service-autorun"
            "--disable-sync"
            "--component-updater=require_encryption"
            (enableFeature false "speech-api")
            (enableFeature false "speech-synthesis-api")

            # Extension hardening — only Web Store-signed extensions load
            "--extension-content-verification=enforce_strict"
            "--extensions-install-verification=enforce_strict"
          ]
          ++ [
            "--enable-features=${concatStringsSep "," enabledFeatures}"
            "--disable-features=${concatStringsSep "," disabledFeatures}"
          ];
        };

        xdg.mimeApps.defaultApplications = {
          "text/html" = [ "chromium-browser.desktop" ];
          "text/xml" = [ "chromium-browser.desktop" ];
          "x-scheme-handler/http" = [ "chromium-browser.desktop" ];
          "x-scheme-handler/https" = [ "chromium-browser.desktop" ];
        };
      };

    # macOS: the cask installs Chromium.app unconfigured, so reapply the portable
    # config through Chromium's managed-policy engine, which reads mandatory
    # policy from /Library/Managed Preferences. The Wayland/VAAPI command-line
    # flags above have no macOS analogue and are intentionally dropped.
    darwin =
      {
        pkgs,
        lib,
        ...
      }:
      let
        policy = {
          ExtensionInstallForcelist = map (
            id: "${id};https://clients2.google.com/service/update2/crx"
          ) extensionIds;

          # Telemetry / data collection (mirrors the disabled telemetry features)
          MetricsReportingEnabled = false;
          UrlKeyedAnonymizedDataCollectionEnabled = false;

          # Account / sync (mirrors --disable-sync)
          SyncDisabled = true;
          BrowserSignin = 0;

          # Quality of life (mirrors --no-default-browser-check + NTP declutter)
          DefaultBrowserSettingEnabled = false;
          PromotionalTabsEnabled = false;
          BackgroundModeEnabled = false;

          # Autofill (mirrors the disabled Autofill* features)
          AutofillAddressEnabled = false;
          AutofillCreditCardEnabled = false;

          # Privacy Sandbox / Topics (mirrors the disabled PrivacySandbox features)
          PrivacySandboxPromptEnabled = false;
          PrivacySandboxAdMeasurementEnabled = false;
          PrivacySandboxSiteEnabledAdsEnabled = false;
          PrivacySandboxFledgeEnabled = false;
          PrivacySandboxTopicsEnabled = false;

          # GPU (mirrors --ignore-gpu-blocklist intent)
          HardwareAccelerationModeEnabled = true;
        };
        plist = pkgs.writeText "org.chromium.Chromium.plist" (lib.generators.toPlist { } policy);
      in
      {
        system.activationScripts.postActivation.text = ''
          mkdir -p "/Library/Managed Preferences"
          cp -f ${plist} "/Library/Managed Preferences/org.chromium.Chromium.plist"
        '';
      };

    cacheHome.directories = [
      ".cache/chromium"
    ];

    persistHome.directories = [
      ".config/chromium"
    ];
  };
}
