{ den, ... }:
{
  # Monitoring aspects (prometheus, loki, grafana) will be created in Task 10.
  # Den's aspect resolution handles forward references since all aspects are
  # declared on the same config, so these includes will resolve once the
  # monitoring aspects land.
  den.aspects.roles.metrics-ingester = {
    colmena-tags = [ "metrics-ingester" ];
    includes = with den.aspects; [
      services.prometheus
      services.loki
      services.grafana
    ];
  };
}
