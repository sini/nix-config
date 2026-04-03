# Nix-ld: run unpatched dynamic binaries with comprehensive library support.
{ den, lib, ... }:
{
  den.aspects.nix-ld = {
    includes = lib.attrValues den.aspects.nix-ld._;

    _ = {
      config = den.lib.perHost {
        nixos =
          { pkgs, ... }:
          {
            programs.nix-ld = {
              enable = true;
              libraries =
                with pkgs;
                (steam-run.args.multiPkgs pkgs)
                ++ (heroic.args.multiPkgs pkgs)
                ++ (lutris.args.multiPkgs pkgs)
                ++ [
                  alsa-lib
                  clang.cc.lib
                  dbus
                  glibc
                  gtk3
                  icu
                  libcap
                  libxcrypt
                  libGL
                  libdrm
                  libudev0-shim
                  libva
                  mesa
                  networkmanager
                  openssl
                  pkg-config
                  stdenv.cc.cc
                  libx11
                  libxext
                  udev
                  vulkan-loader
                ];
            };
          };
      };
    };
  };
}
