{
  lib,
  ...
}:
let
  inherit (lib) types mkOption;
in
{
  options.flake.hosts =
    let
      hostType = types.submodule {
        options = {
          system = mkOption {
            type = types.str;
            default = "x86_64-linux";
          };

          unstable = lib.mkOption {
            type = types.bool;
            default = false;
          };

          deployment = {
            targetHost = mkOption {
              type = types.str;
              default = "";
              description = "The target host for deployment.";
            };
          };

          tags = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "List of tags for the host.";
          };

          public_key = mkOption {
            type = types.path;
            default = null;
            description = "Path to the public SSH key for the host.";
          };

          facts = mkOption {
            type = types.path;
            default = null;
            description = "Path to the Facter JSON file for the host.";
          };

          additional_modules = mkOption {
            type = types.listOf types.path;
            default = [ ];
            description = "List of additional modules to include for the host.";
          };
        };
      };
    in
    mkOption {
      type = types.attrsOf hostType;
    };

  config.flake.modules.nixos.hosts = { };
}
