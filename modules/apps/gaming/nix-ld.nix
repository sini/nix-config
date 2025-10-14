{
  flake.features.nix-ld.nixos =
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
            xorg.libX11
            xorg.libXext
            udev
            vulkan-loader
          ];
      };
    };
}
