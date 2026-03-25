{
  features.disk-tools.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        dust
        dua
        dysk
        ncdu
      ];
    };
}
