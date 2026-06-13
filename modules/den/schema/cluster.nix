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

  # Pure transform: a domain's k8s-safe resource name = its last two labels,
  # hyphenated (glance.json64.dev -> json64-dev). Shared by the domainForResource
  # (service-keyed) and resourceForDomain (domain-keyed) cluster methods below.
  resourceNameOf =
    domain:
    lib.concatStringsSep "-" (
      lib.reverseList (lib.take 2 (lib.reverseList (lib.splitString "." domain)))
    );

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

    # Resolve the public domain for a service in this cluster's environment
    # (delegates to the environment's getDomainFor, following service overrides
    # and delegation). Lets cluster-scoped aspects state `cluster.domainFor "x"`
    # without re-deriving the environment.
    den.schema.cluster.methods.domainFor =
      schemaLib.schemaFn "Resolve the public domain for a service in this cluster's environment"
        (lib.types.functionTo lib.types.str)
        ({ environment, ... }: environments.${environment}.getDomainFor);

    # Gateway listener resource name for a service's domain: the last two domain
    # labels, hyphenated (glance.json64.dev -> json64-dev). Used to build the
    # HTTPRoute parentRef sectionName ("${cluster.domainForResource "x"}-https").
    # Replaces the per-aspect `domainToResourceName` let that was duplicated across
    # glance / grafana / hubble-ui.
    den.schema.cluster.methods.domainForResource =
      schemaLib.schemaFn
        "Gateway listener resource name (last two domain labels, hyphenated) for a service"
        (lib.types.functionTo lib.types.str)
        (
          { environment, ... }:
          serviceName: resourceNameOf (environments.${environment}.getDomainFor serviceName)
        );

    # Same transform keyed by a raw domain rather than a service — for aspects that
    # enumerate domains directly (the gateway listeners in envoy-gateway, the
    # wildcard certs in cert-manager) rather than resolving a single service.
    den.schema.cluster.methods.resourceForDomain =
      schemaLib.schemaFn "k8s-safe resource name (last two domain labels, hyphenated) for a domain"
        (lib.types.functionTo lib.types.str)
        (_: resourceNameOf);

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
