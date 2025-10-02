{
  flake.role.metrics-ingester = {
    features = [
      "loki"
      "prometheus"
    ];
  };
}
