{
  flake.role.gaming = {
    nixosModules = [
      "gamepad"
      "nix-ld"
      "steam"
      #"sunshine"
    ];

    homeModules = [
      "mangohud"
    ];
  };
}
