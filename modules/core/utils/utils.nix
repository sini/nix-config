{
  flake.modules.nixos.utils =
    { pkgs, ... }:
    {
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
