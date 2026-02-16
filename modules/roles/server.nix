{
  flake.roles.server = {
    features = [
      "acme"
      "media-data-share"
      "network-boot"
      # "nginx"
      "server"
      "tang"
      #"alloy"
      "tailscale"
    ];
  };
}
