{
  den.aspects.apps.browsers.chromium = {
    homeManager =
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

          # Web Store IDs mirror the firefox extension set; firefox-only addons
          # (firefox-color, sidebery) have no chromium equivalent and are dropped.
          extensions = [
            "cjpalhdlnbpafiamejdnhcphjbkeiagm" # uBlock Origin
            "nngceckbapebfimnlniiiahkandclblb" # Bitwarden
            "mnjggcdmjocbbbhaepdhchncahnbgone" # SponsorBlock
            "eimadpbcbfnmbkopoojfekhnkhdbieeh" # Dark Reader
            "mlomiejdfkolichcflejclcbmpeaniij" # Ghostery
            "gebbhagfogifgggkldgodflihgfeippi" # Return YouTube Dislike
            "bkdgflcldnnnapblkhphbgpggdiikppg" # DuckDuckGo Privacy Essentials
            "kekjfbackdeiabghhcdklcdoekaanoel" # MAL-Sync
          ];

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

    cacheHome.directories = [
      ".cache/chromium"
    ];

    persistHome.directories = [
      ".config/chromium"
    ];
  };
}
