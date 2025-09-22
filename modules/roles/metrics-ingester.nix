{
  flake.role.metrics-ingester = {
    nixosModules = [
      "loki"
      "prometheus"
    ];

    homeModules = [ ];
  };
}
