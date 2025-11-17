{
  flake.features.spicetify = {
    nixos = {
      # Local Discovery and Google Cast ports
      networking.firewall.allowedTCPPorts = [ 57621 ];
      networking.firewall.allowedUDPPorts = [ 5353 ];
    };
    home =
      { pkgs, inputs, ... }:
      let
        spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.system};
      in
      {

        imports = [ inputs.spicetify-nix.homeManagerModules.spicetify ];

        # Note: Spotify requires NetworkManager to have internet connectivity if it's enabled;
        # it does not like hybrid systemd-networkd+networkmanager configurations for split interfaces.
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

          # wayland = true;
          # windowManagerPatch = true;
          # experimentalFeatures = true;
          # alwaysEnableDevTools = true;
        };

      };
  };
}
