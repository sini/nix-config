{
  flake.role.metrics-ingester = {
    aspects = [
      "loki"
      "prometheus"
    ];
  };
}
