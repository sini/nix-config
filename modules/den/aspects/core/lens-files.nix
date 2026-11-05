# lens-files: project declared settings INTO a file the program also writes, instead of
# replacing it with a read-only store symlink. Each activation applies the managed keys
# through tomlkit (a style-preserving TOML round-trip), so every key, table and comment the
# program or the user owns survives untouched, and a managed key is reset to its declared
# value whatever was written over it in between.
#
# Not Augeas: its Toml.lns rejects quoted keys (`"gpt-6.1-sol" = 1`), which codex writes
# itself, so the first real config.toml failed to parse (measured on augeas 1.15.0).
#
# Removal is three-way, as `kubectl apply` does it: the paths applied last time are kept
# beside the target, and a path that leaves the declaration is removed from the file.
#
# Contributors merge through the HM module system, so several modules may set keys in one
# file. A file that does not parse is reported and left as it was.
{
  den.aspects.core.lens-files = {
    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        toml = pkgs.formats.toml { };

        lens = pkgs.writers.writePython3 "lens-toml" {
          libraries = [ pkgs.python3Packages.tomlkit ];
          flakeIgnore = [ "E501" ];
        } ./_lens-toml.py;

        mkApply =
          name: file:
          pkgs.writeShellScript "lens-apply-${name}" ''
            exec ${lens} ${lib.escapeShellArg "${config.home.homeDirectory}/${file.target}"} \
              ${pkgs.writeText "${name}-lens.json" (builtins.toJSON file.settings)}
          '';
      in
      {
        options.lens.files = lib.mkOption {
          default = { };
          description = "Mutable files whose declared keys are projected in on every activation.";
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                target = lib.mkOption {
                  type = lib.types.str;
                  description = "Path relative to the home directory.";
                };
                settings = lib.mkOption {
                  inherit (toml) type;
                  default = { };
                  description = "Keys owned by Home Manager; everything else in the file is left alone.";
                };
              };
            }
          );
        };

        config = lib.mkIf (config.lens.files != { }) {
          home.activation.lensFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] (
            lib.concatStrings (lib.mapAttrsToList (n: f: "run ${mkApply n f}\n") config.lens.files)
          );
        };
      };
  };
}
