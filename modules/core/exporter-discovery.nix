let
  # Helper function to get auto-discovered exporters for a host
  getAutoExporters =
    hostConfig:
    let
      # Add node exporter for all server hosts
      serverExporters =
        if builtins.elem "server" hostConfig.roles then
          {
            node = {
              port = 9100;
              path = "/metrics";
              interval = "15s";
            };
          }
        else
          { };

      # Add K3s exporters for kubernetes hosts
      k3sExporters =
        if builtins.elem "kubernetes" hostConfig.roles then
          {
            k3s-server = {
              port = 10249;
              path = "/metrics";
              interval = "30s";
            };
            etcd = {
              port = 2381;
              path = "/metrics";
              interval = "30s";
            };
          }
        else
          { };
    in
    serverExporters // k3sExporters;
in
{
  # Expose the helper function for use in prometheus module
  _module.args.getAutoExporters = getAutoExporters;
}
