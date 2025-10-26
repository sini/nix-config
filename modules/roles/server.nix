{
  flake.roles.server = {
    features = [
      #"acme"
      "media-data-share"
      "network-boot"
      "server"
      "tang"
      #"alloy"
    ];
  };
}
