{ inputs, ... }:
{
  den.aspects.applications.messaging.discord = {
    homeManagerModules =
      { inputs', ... }:
      [
        inputs'.nixcord.homeModules.nixcord
      ];

    # nixcord still passes `source` to pkgs.discord.override; nixpkgs 7a1e0f89
    # (discord: move to pkgs/by-name) dropped that formal. Strip it only where
    # it is gone, keeping functionArgs so nixcord's useFHSEnv probe still works.
    nixpkgs-overlays = _: [
      (_final: prev: {
        discord =
          let
            args = prev.lib.functionArgs prev.discord.override;
          in
          if args ? source then
            prev.discord
          else
            prev.discord
            // {
              override = prev.lib.setFunctionArgs (a: prev.discord.override (removeAttrs a [ "source" ])) args;
            };
      })
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
