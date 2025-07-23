{
  flake.modules.homeManager.discord =
    { inputs, ... }:
    {
      imports = [ inputs.nixcord.homeModules.nixcord ];
      programs.nixcord = {
        enable = true;
        discord.enable = false;
        vesktop.enable = true;
        config = {
          themeLinks = [ "https://catppuccin.github.io/discord/dist/catppuccin-mocha.theme.css" ];

          frameless = true;

          plugins = {
            alwaysAnimate.enable = true;
            alwaysTrust.enable = true;
            accountPanelServerProfile.enable = true;
            betterGifPicker.enable = true;
            betterNotesBox.enable = true;
            betterRoleContext.enable = true;
            betterRoleDot.enable = true;
            betterUploadButton.enable = true;
            biggerStreamPreview.enable = true;
            callTimer.enable = true;
            fakeNitro.enable = true;
            fakeProfileThemes.enable = true;
            # forceOwnerCrown.enable = true;
            friendsSince.enable = true;
            fullSearchContext.enable = true;
            fullUserInChatbox.enable = true;
            gameActivityToggle.enable = true;
            implicitRelationships.enable = true;
            # lastFMRichPresence = {
            #   enable = true;
            #   username = "USER_NAME";
            #   apiKey = "YOUR_LASTFM_API_KEY";
            #   hideWithSpotify = false;
            #   nameFormat = "artist-first";
            #   useListeningStatus = true;
            #   showLastFmLogo = false;
            # };
            mentionAvatars.enable = true;
            # platformIndicators.enable = true;
            # serverListIndicators.enable = true;
            # spotifyControls.enable = true;
            typingIndicator.enable = true;
            typingTweaks.enable = true;
            userVoiceShow.enable = true;
            validReply.enable = true;
            validUser.enable = true;
            viewIcons.enable = true;
            volumeBooster.enable = true;
            webScreenShareFixes.enable = true;
            whoReacted.enable = true;
          };
        };
        # dorion.enable = true; # Dorion
        # dorion = {
        #   theme = "dark";
        #   zoom = "1.1";
        #   blur = "acrylic"; # "none", "blur", or "acrylic"
        #   sysTray = true;
        #   openOnStartup = true;
        #   autoClearCache = true;
        #   disableHardwareAccel = false;
        #   rpcServer = true;
        #   rpcProcessScanner = true;
        #   pushToTalk = true;
        #   pushToTalkKeys = [ "RControl" ];
        #   desktopNotifications = true;
        #   unreadBadge = true;
        # };
        # extraConfig = {
        #   # Some extra JSON config here
        #   # ...
        # };
      };
    };
}
