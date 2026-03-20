{
  lib,
  config,
  ...
}:
{
  flake.lib.host-utils = {
    findHostsWithRole =
      role:
      let
        matchingHosts =
          config.hosts
          |> lib.attrsets.filterAttrs (_hostname: hostConfig: builtins.elem role (hostConfig.roles or [ ]));
      in
      matchingHosts;
  };
}
