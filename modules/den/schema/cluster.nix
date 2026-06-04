{
  lib,
  inputs,
  config,
  den,
  ...
}:
let
  inherit (lib) mkOption types;
  schemaLib = inputs.gen-schema.lib;
  environments = config.den.environments;

  networkType = types.submodule {
    options = {
      cidr = mkOption {
        type = types.str;
        description = "Network CIDR (e.g., 172.20.0.0/16)";
      };

      ipv6_cidr = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "IPv6 network CIDR";
      };

      description = mkOption {
        type = types.str;
        default = "";
        description = "Human-readable description of the network";
      };

      gatewayIp = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Gateway IP address for this network";
      };

      gatewayIpV6 = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Gateway IPv6 address for this network";
      };

      dnsServers = mkOption {
        type = types.listOf types.str;
        default = [ ];
        description = "DNS server IPs for this network";
      };

      assignments = mkOption {
        type = types.attrsOf types.str;
        default = { };
        description = "Static IP address assignments within this network";
      };
    };
  };
in
{
  options.den.clusters = schemaLib.mkInstanceRegistry den.schema.cluster {
    description = "Cluster definitions for fleet topology and K8s service resolution";
    derive =
      clusters:
      lib.mapAttrs (
        _: c:
        lib.optionalAttrs
          (c.secretPath != null && builtins.pathExists "${c.secretPath}/cluster-sops-age-key.pub")
          {
            sopsAgeRecipient = builtins.readFile "${c.secretPath}/cluster-sops-age-key.pub";
          }
      ) clusters;
    extraModules = [
      (_: {
        options.sopsAgeRecipient = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          readOnly = true;
          internal = true;
          description = "Derived SOPS age recipient public key from cluster secretPath";
        };
      })
    ];
  };

  config = {
    den.schema.cluster.isEntity = true;

    den.schema.cluster.methods.getAssignment =
      schemaLib.schemaFn "Look up an IP assignment across cluster networks"
        (lib.types.functionTo lib.types.str)
        (
          { networks, ... }:
          assignmentName:
          let
            networkNames = builtins.attrNames networks;
            found = lib.findFirst (nname: networks.${nname}.assignments ? ${assignmentName}) null networkNames;
          in
          if found != null then
            networks.${found}.assignments.${assignmentName}
          else
            throw "den: cluster assignment '${assignmentName}' not found"
        );

    den.schema.cluster.methods.secrets =
      schemaLib.schemaFn "OIDC secret helpers for cluster services" (lib.types.attrsOf lib.types.anything)
        (
          { environment, ... }:
          let
            env = environments.${environment};
            kanidmDomain = env.getDomainFor "kanidm";
          in
          {
            oidcIssuerFor = clientID: "https://${kanidmDomain}/oauth2/openid/${clientID}";
          }
        );

    den.schema.cluster.imports = [
      (_: {
        options = {
          # TODO: replace with schema.ref to den.environments once gen-schema
          # registry wiring is complete.
          environment = mkOption {
            type = types.str;
            description = "Name of the environment this cluster belongs to";
          };

          role = mkOption {
            type = types.nullOr types.str;
            default = "k3s";
            description = "Host role for auto-discovery. Hosts in the cluster's environment with this role are included.";
          };

          kubeVersion = mkOption {
            type = types.nullOr types.str;
            default = null;
            example = "1.36.1";
            description = ''
              Kubernetes version this cluster targets, used when generating CRD
              resource types (e.g. "1.36.1", no leading "v"). Should match the
              cluster's actual k8s/k3s version. When null, the crds bridge falls
              back to the nixpkgs kubernetes package version.
            '';
          };

          hosts = mkOption {
            type = types.nullOr (types.listOf types.str);
            default = null;
            description = "Explicit list of host names in this cluster. When null, hosts are discovered via role.";
          };

          secretPath = mkOption {
            type = types.nullOr types.path;
            default = null;
            description = "Path to the directory containing secrets for this cluster";
          };

          networks = mkOption {
            type = types.attrsOf networkType;
            default = { };
            description = "Cluster network definitions (pods, services, loadbalancers)";
          };

          nfsVolumes = mkOption {
            type = types.attrsOf (
              types.submodule {
                options = {
                  server = mkOption {
                    type = types.str;
                    description = "NFS server address";
                  };
                  share = mkOption {
                    type = types.str;
                    description = "NFS share path";
                  };
                };
              }
            );
            default = { };
            description = "NFS volumes for CSI driver StorageClass generation";
          };
        };
      })
    ];
  };
}
