# Metrics ingester role: log and metrics collection services.
{ den, ... }:
{
  den.aspects.metrics-ingester = {
    includes = [
      den.aspects.loki
      den.aspects.prometheus
    ];
  };
}
