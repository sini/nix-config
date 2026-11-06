# persist-orphans: list what sits in /persist and /cache that no configured entry uses, the
# inverse of persist-migrate. Installed with this host's manifest built in, so a bare
# `sudo persist-orphans` reports against the running configuration.
{
  den.aspects.core.impermanence.orphans = {
    nixos =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        manifest = pkgs.writeText "persist-manifest.json" (
          builtins.toJSON {
            entries = import ./_entries.nix { inherit lib config; };
            inherit (config.impermanence) directPaths;
          }
        );
      in
      {
        options.impermanence.directPaths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Paths a service uses on a persistent store directly rather than through an
            impermanence entry (a microvm share's source, a scratch image directory), so
            persist-orphans does not report them.
          '';
        };

        config.environment.systemPackages = [
          (pkgs.writeShellScriptBin "persist-orphans" ''
            exec ${lib.getExe pkgs.local.persist-orphans} --manifest ${manifest} "$@"
          '')
        ];
      };
  };
}
