{ inputs, ... }:
{
  den.aspects.apps.messaging.discord = {
    homeManagerModules =
      { inputs', ... }:
      [
        inputs'.nixcord.homeModules.nixcord
      ];

    homeManager =
      {
        pkgs,
        ...
      }:
      {

        home.packages = [
          pkgs.discordo
        ];

        programs.nixcord = {
          enable = true;
          discord.equicord.enable = true;
          config = {
            themeLinks = [ "https://catppuccin.github.io/discord/dist/catppuccin-mocha.theme.css" ];

            frameless = true;

            plugins = {
              alwaysAnimate.enable = true;
              alwaysTrust.enable = true;
              accountPanelServerProfile.enable = true;
              betterGifPicker.enable = true;
              betterRoleContext.enable = true;
              betterRoleDot.enable = true;
              betterUploadButton.enable = true;
              biggerStreamPreview.enable = true;
              callTimer.enable = true;
              fakeNitro.enable = true;
              fakeProfileThemes.enable = true;
              fullSearchContext.enable = true;
              fullUserInChatbox.enable = true;
              gameActivityToggle.enable = true;
              implicitRelationships.enable = true;
              mentionAvatars.enable = true;
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
        };
      };
  };
}
