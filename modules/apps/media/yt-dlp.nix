{

  flake.modules.homeManager.yt-dlp =
    { inputs, pkgs, ... }:
    {
      home.packages = with pkgs; [ media-downloader ];
      programs.yt-dlp = {
        enable = true;
        package = inputs.chaotic.packages.${pkgs.system}.yt-dlp_git;
      };
    };
}
