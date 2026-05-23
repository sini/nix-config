_: {
  den.aspects.system.nix-ld = {
    nixos =
      { pkgs, ... }:
      {
        programs.nix-ld = {
          enable = true;
          libraries =
            (pkgs.steam-run.args.multiPkgs pkgs)
            ++ (pkgs.heroic.args.multiPkgs pkgs)
            ++ (pkgs.lutris.args.multiPkgs pkgs)
            ++ (with pkgs; [
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
            ]);
        };
      };
  };
}
