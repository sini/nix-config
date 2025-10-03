{
  flake.roles.metrics-ingester = {
    features = [
      "loki"
      "prometheus"
    ];
  };
}
