{
  flake.modules.nixos.utils =
    { pkgs, ... }:
    {
      programs.dconf.enable = true;

      environment.systemPackages = with pkgs; [
        btop
        coreutils
        curl
        fd
        file
        findutils
        killall
        lsof
        pciutils
        unzip
        wget
      ];
    };
}
