{
  flake.role.laptop = {
    nixosModules = [
      "laptop"
      "wireless"
    ];
  };
}
