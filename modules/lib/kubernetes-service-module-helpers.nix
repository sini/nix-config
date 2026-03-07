{
  lib,
  config,
  self,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (self.lib.modules) mkDeferredModuleOpt;

  serviceSubmodule =
    { name, ... }:
    {
      options = {
        name = mkOption {
          type = types.str;
          default = name;
          readOnly = true;
          internal = true;
        };

        requires = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "List of names of services required by this service";
        };

        excludes = mkOption {
          type = types.listOf types.str;
          default = [ ];
          description = "List of names of services to exclude from this service";
        };

        options = mkOption {
          type = types.lazyAttrsOf types.raw;
          default = { };
          description = ''
            Option declarations for environment-level configuration of this service.
            These options will be available at kubernetes.services.<name> in environment configs.
            Should contain ONLY option declarations, no config assignments.
          '';
        };

        crds = mkOption {
          type = types.nullOr types.raw;
          default = null;
          description = ''
            CRD generator configuration function for this service.

            Should be a function that receives perSystem module args ({ pkgs, lib, inputs, system, ... })
            and returns an attribute set with CRD configuration.

            Two patterns are supported:
            - fromCRD: Return { src, crds } to manually specify CRD files
            - fromChartCRD: Return { chart } or { chartAttrs } to auto-discover CRDs from a helm chart

            Example (fromCRD):
              crds = { pkgs, lib, ... }: {
                src = pkgs.fetchFromGitHub { ... };
                crds = [ "path/to/crd.yaml" ];
              };

            Example (fromChartCRD):
              crds = { inputs, system, ... }: {
                chart = inputs.nixhelm.chartsDerivations.''${system}.traefik.traefik;
              };

            Available options in the returned attrset:
            - src: Source package with CRD YAML files (for fromCRD)
            - chart: Helm chart derivation (for fromChartCRD)
            - chartAttrs: Attributes for downloadHelmChart (for fromChartCRD)
            - values: Helm values for chart rendering (for fromChartCRD)
            - crds: List of CRD file paths (fromCRD) or kind names (fromChartCRD)
            - namePrefix: Prefix for generated type names
            - attrNameOverrides: Custom attribute name mappings
            - skipCoerceToList: Control list coercion behavior
          '';
        };

        nixidy = mkDeferredModuleOpt "A nixidy module for this Kubernetes service";
      };
    };

  # Shared kubernetes options
  kubernetesNetworkOptions = {
    tlsSanIps = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional IPs to include in Kubernetes API server TLS certificate SANs";
    };
  };

  # Base kubernetes options shared by config types (network + secrets)
  baseKubernetesOptions = kubernetesNetworkOptions // {
    secretsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to sops encrypted secret file for kubernetes environment";
    };

    sso = mkOption {
      type = types.submodule {
        options = {
          issuerPattern = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              SSO issuer URL pattern for authentication.
              Use {clientID} as a placeholder for the client ID.
              Example: "https://idm.example.com/oauth2/openid/{clientID}"
            '';
          };

          credentialsEnvironment = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = "Environment variable name containing SSO credentials";
          };
        };
      };
      default = { };
      description = "Single Sign-On configuration";
    };
  };

  # Type for flake.kubernetes - service definitions with nixidy modules
  kubernetesType = types.submodule {
    options = kubernetesNetworkOptions // {
      services = mkOption {
        type = types.lazyAttrsOf (types.submodule serviceSubmodule);
        default = { };
        description = "Kubernetes service definitions with their nixidy modules";
      };
    };
  };

  serviceOptions = mkOption {
    type = types.submodule {
      options = lib.mapAttrs (
        name: service:
        mkOption {
          type =
            if service.options or { } != { } then
              types.submodule { inherit (service) options; }
            else
              types.attrs;
          default = { };
          description = "Configuration for ${name} service";
        }
      ) (config.flake.kubernetes.services or { });
    };
    default = { };
    description = ''
      Service-specific configurations for this environment.
      Options are imported from flake.kubernetes.services.<name>.options.
    '';
  };

  # Type for flake.environments.<name>.kubernetes - split enabled/config structure
  kubernetesConfigType = types.submodule {
    options = baseKubernetesOptions // {
      services = mkOption {
        type = types.submodule {
          options = {
            enabled = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = ''
                List of enabled services for this environment.
                Services without configuration can be enabled by simply adding them to this list.
              '';
            };

            config = serviceOptions;
          };
        };
        default = { };
        description = ''
          Kubernetes service management for this environment.
          Use 'enabled' to enable services and 'config' for service-specific options.
        '';
      };
    };
  };

  # Type for nixidy modules - flattened services for direct access
  nixidyKubernetesType = types.submodule {
    options = baseKubernetesOptions // {
      services = serviceOptions;
    };
  };
in
{
  flake.lib.kubernetes-services = {
    inherit
      kubernetesConfigType
      nixidyKubernetesType
      kubernetesType
      serviceSubmodule
      ;
  };
}
