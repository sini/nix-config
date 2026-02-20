{ lib, config, ... }:
{
  flake.lib.host-utils = {
    findHostsWithRole =
      role:
      let
        matchingHosts =
          config.flake.hosts
          |> lib.attrsets.filterAttrs (hostname: hostConfig: builtins.elem role (hostConfig.roles or [ ]));
      in
      matchingHosts;
  };

}
