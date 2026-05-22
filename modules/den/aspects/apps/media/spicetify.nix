{ den, inputs, ... }:
{
  den.aspects.apps.spicetify = {
    homeManager =
      {
        pkgs,
        ...
      }:
      let
        spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.system};
      in
      {
        imports = [ inputs.spicetify-nix.homeManagerModules.spicetify ];

        programs.spicetify = {
          enable = true;
          enabledExtensions = with spicePkgs.extensions; [
            fullAppDisplay
            playlistIcons
            shuffle
            skipStats
            trashbin
          ];
          enabledCustomApps = with spicePkgs.apps; [
            lyricsPlus
            marketplace
            newReleases
          ];
          enabledSnippets = with spicePkgs.snippets; [
            betterLyricsStyle
            fixedEpisodesIcon
            fixLikedButton
            fixLikedIcon
            fixListeningOn
            fixListenTogetherButton
            fixNowPlayingIcon
            hideAudiobooksButton
            hideFriendActivityButton
            pointer
          ];
        };
      };

    provides.firewall.nixos = {
      # Local Discovery and Google Cast ports
      networking.firewall.allowedTCPPorts = [ 57621 ];
      networking.firewall.allowedUDPPorts = [ 5353 ];
    };
  };
}
