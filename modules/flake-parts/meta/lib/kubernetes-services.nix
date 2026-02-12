{
  self,
  lib,
  config,
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

        nixidy = mkDeferredModuleOpt "A nixidy module for this Kubernetes service";
      };
    };

  # Shared kubernetes network options
  kubernetesNetworkOptions = {
    clusterCidr = mkOption {
      type = types.str;
      default = "172.20.0.0/16";
      description = "Kubernetes pod network CIDR";
    };

    serviceCidr = mkOption {
      type = types.str;
      default = "172.21.0.0/16";
      description = "Kubernetes service network CIDR";
    };

    internalMeshCidr = mkOption {
      type = types.str;
      default = "172.16.255.0/24";
      description = "Internal mesh network for Kubernetes nodes";
    };

    tlsSanIps = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional IPs to include in Kubernetes API server TLS certificate SANs";
    };

    loadBalancerRange = mkOption {
      type = types.str;
      default = "10.0.100.0/24";
      description = "IP range for LoadBalancer services";
    };
  };

  # Base kubernetes options shared by config types (network + secrets)
  baseKubernetesOptions = kubernetesNetworkOptions // {
    secretsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Path to sops encrypted secret file for kubernetes environment";
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
              types.submodule { options = service.options; }
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
