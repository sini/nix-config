{
  flake.modules.nixos.utils =
    { pkgs, ... }:
    {
      programs.dconf.enable = true;

      environment.systemPackages = with pkgs; [
        coreutils
        curl
        fd
        file
        findutils
        killall
        lsof
        pciutils
        tldr
        unzip
        wget
      ];
    };
}
