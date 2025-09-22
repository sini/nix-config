{
  flake.role.server = {
    nixosModules = [
      "acme"
      "media-data-share"
      "network-boot"
      "server"
      "alloy"
    ];

    homeModules = [ ];
  };
}
