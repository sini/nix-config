# Exports host configurations for CI builds
# Merges with nixos-unified's packages (activate, update) via config.packages
{
  self,
  config,
  lib,
  ...
}:
let
  # Get host system from den entity data (cheap) instead of evaluating
  # nixosConfigurations.${name}.pkgs.stdenv.hostPlatform.system (expensive).
  allHosts = lib.foldl' (acc: system: acc // (config.den.hosts.${system} or { })) { } (
    builtins.attrNames (config.den.hosts or { })
  );
in
{
  perSystem =
    {
      pkgs,
      lib,
      system,
      ...
    }:
    let
      # Only include hosts matching this system, using den entity metadata.
      compatHostNames = lib.filterAttrs (_: host: (host.system or null) == system) allHosts;

      # Lazily map to toplevel derivations — only evaluated hosts are forced.
      compatHostDrvs = lib.mapAttrs (
        name: _: self.nixosConfigurations.${name}.config.system.build.toplevel
      ) compatHostNames;

      # Create a linkFarm containing all compatible hosts
      compatHostsFarm = pkgs.linkFarm "hosts-${system}" (
        lib.mapAttrsToList (name: path: { inherit name path; }) compatHostDrvs
      );
    in
    {
      # Host configurations as packages (for CI)
      packages =
        compatHostDrvs
        // (lib.optionalAttrs (compatHostDrvs != { }) {
          default = compatHostsFarm;
        })
        // {
          inherit (pkgs) nix-fast-build;
        };
    };
}
