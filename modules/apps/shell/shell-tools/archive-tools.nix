{
  features.archive-tools.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        atool
        unzip
        unrar
        cabextract
        p7zip
        zip
        xz
      ];
    };
}
