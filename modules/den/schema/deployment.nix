# Host deployment record: one tool-neutral { address, user, tags } per host,
# read by every deployer (batteries/colmena.nix, batteries/panix), so they
# cannot drift in how they reach or select a host.
#
#   address  first IPv4, else the tailnet name core/network/hostsfile pins
#   user     remote-deployment-user, else "sini"
#   tags     environment, then every resolved named aspect by identity path
#            (e.g. roles/workstation), sorted and deduplicated
{ lib, config, ... }:
let
  inherit (lib) mkOption types;
  inherit (config.den) environments;
in
{
  den.schema.host.imports = [
    (
      { config, ... }:
      {
        options.deployment = mkOption {
          readOnly = true;
          description = "Tool-neutral deployment record read by the deploy batteries.";
          type = types.submodule {
            options = {
              address = mkOption { type = types.str; };
              user = mkOption { type = types.str; };
              tags = mkOption { type = types.listOf types.str; };
            };
          };
          default = {
            address =
              if config.ipv4 == [ ] then
                "${config.name}.ts.${environments.${config.environment}.domain}"
              else
                builtins.head config.ipv4;
            user = config.remote-deployment-user or "sini";
            tags = [
              config.environment
            ]
            ++ lib.sort (a: b: a < b) (
              lib.unique (map (a: a.identity) (lib.filter (a: a.isNamed) config.aspects))
            );
          };
        };
      }
    )
  ];
}
