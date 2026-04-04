{
  lib,
  config,
  den,
  ...
}:
{
  # Re-expose den and remaining legacy resources as flake outputs
  config.flake = {
    # Den resources
    den-hosts = lib.concatMapAttrs (_sys: hosts: hosts) (den.hosts or { });
    den-environments = den.environments or { };

    # Legacy resources still in use (users, groups, clusters for ACL + k8s)
    inherit (config)
      users
      groups
      clusters
      ;
  };
}
