{
  lib,
  config,
  ...
}:
{
  flake.lib.host-utils = {
    findHostsWithFeature =
      feature:
      let
        matchingHosts =
          config.hosts |> lib.attrsets.filterAttrs (_hostname: hostConfig: hostConfig.hasFeature feature);
      in
      matchingHosts;
  };
}
