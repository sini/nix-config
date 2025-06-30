{
  lib,
  ...
}:
let
  inherit (lib) types mkOption;
in
{
  config.text.readme.parts.host-options =
    # markdown
    ''
      ## Host Options

      This repository defines a set of hosts in the `flake.hosts` attribute set.
      Each host is defined as a submodule with its own configuration options.
      The host configurations can be used to deploy NixOS configurations to remote
      machines using Colmena or for local development. These options are defined for
      every host and include:

      - `system`: The system architecture of the host (e.g., `x86_64-linux`).
      - `unstable`: Whether to use unstable packages for the host.
      - `deployment.targetHost`: The target host for deployment.
      - `tags`: A list of tags for the host, which can be used to target
        specific hosts during deployment.
      - `public_key`: The path or value of the public SSH key for the host used for encryption.
      - `facts`: The path to the Facter JSON file for the host, which is used to provide
        additional information about the host and for automated hardware configuration.
      - `extra_modules`: A list of additional modules to include for the host.

    '';

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

          extra_modules = mkOption {
            type = types.listOf types.deferredModule;
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
