{
  flake.modules.homeManager.spicetify =
    { pkgs, inputs, ... }:
    let
      # system = "x86_64-linux";
      spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.system};
    in
    {
      imports = [ inputs.spicetify-nix.homeManagerModules.spicetify ];
      programs.spicetify = {
        enable = true;
        # theme = spicePkgs.themes.catppuccin;
        # theme = spicePkgs.themes.text;
        # theme = spicePkgs.themes.TokyoNight;
        # theme = spicePkgs.themes.defaultDynamic;
        enabledExtensions = with spicePkgs.extensions; [
          adblockify
          hidePodcasts
          shuffle
          keyboardShortcut
          popupLyrics
          beautifulLyrics
          # simpleBeautifulLyrics
          queueTime
          history
          songStats
          featureShuffle
          phraseToPlaylist
          skipStats
          fullAppDisplay
        ];
      };
    };
}
