{
  den.aspects.applications.gaming.nix-ld = {
    nixos =
      { pkgs, ... }:
      {
        programs.nix-ld = {
          enable = true;
          libraries =
            (pkgs.steam-run.args.multiPkgs pkgs)
            ++ (pkgs.heroic.args.multiPkgs pkgs)
            # TODO: lutris 0.5.22's runtime set pulls gtk2, which nixpkgs marks broken; restore once lutris drops it
            # ++ (pkgs.lutris.args.multiPkgs pkgs)
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
