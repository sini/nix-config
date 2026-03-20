{
  lib,
  self,
  config,
  rootPath,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (self.lib.kubernetes-services) kubernetesConfigType;
  flakeConfig = config;

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
        description = "Static IP address assignments within this network.";
      };
    };
  };

  clusterType = types.submodule (
    { name, config, ... }:
    {
      options = {
        name = mkOption {
          type = types.str;
          default = name;
          readOnly = true;
          description = "Cluster name";
        };

        environment = mkOption {
          type = types.str;
          description = "Name of the environment this cluster belongs to (references environments.<name>)";
        };

        role = mkOption {
          type = types.str;
          default = "k3s";
          description = "Host role for auto-discovery. Hosts in the cluster's environment with this role are included.";
        };

        hosts = mkOption {
          type = types.nullOr (types.listOf types.str);
          default = null;
          description = ''
            Explicit list of host names in this cluster.
            When null, hosts are discovered from the environment via the configured role.
          '';
        };

        kubernetes = mkOption {
          type = kubernetesConfigType;
          default = { };
          description = "Kubernetes configuration for this cluster";
        };

        secretPath = mkOption {
          type = types.path;
          default = rootPath + "/.secrets/clusters/${name}";
          description = "Path to the directory containing secrets for this cluster.";
        };

        sopsAgeRecipient = mkOption {
          type = types.nullOr types.str;
          readOnly = true;
          default =
            let
              pubFile = config.secretPath + "/cluster-sops-age-key.pub";
            in
            if builtins.pathExists pubFile then
              lib.trim (builtins.readFile pubFile)
            else
              null;
          description = "SOPS age public key for encrypting secrets destined for this cluster's sops-secrets-operator. Auto-derived from secretPath/k3s-sops-age-key.pub.";
        };

        networks = mkOption {
          type = types.attrsOf networkType;
          default = { };
          description = ''
            Cluster network definitions (pods, services, loadbalancers).
            These are cluster-scoped networks separate from the environment's infrastructure networks.
          '';
        };

        resolvedEnvironment = mkOption {
          type = types.unspecified;
          readOnly = true;
          description = "Resolved environment configuration from environments.<environment>";
        };

        resolvedHosts = mkOption {
          type = types.attrsOf types.unspecified;
          readOnly = true;
          description = "Resolved host configurations for this cluster (from explicit hosts or role-based discovery)";
        };

        getAssignment = mkOption {
          type = types.functionTo (types.nullOr types.str);
          readOnly = true;
          description = "Look up an IP assignment by name across all cluster networks.";
        };

        secrets = mkOption {
          type = types.unspecified;
          readOnly = true;
          description = "Secret helper functions for this cluster";
        };
      };

      config =
        let
          environment = flakeConfig.environments.${config.environment};
          allHosts = flakeConfig.hosts;
        in
        {
          resolvedEnvironment = environment;

          resolvedHosts =
            if config.hosts != null then
              lib.filterAttrs (name: _: lib.elem name config.hosts) allHosts
            else
              environment.findHostsByRole config.role;

          getAssignment =
            name:
            let
              allAssignments = lib.flatten (
                lib.mapAttrsToList (
                  _netName: net:
                  lib.mapAttrsToList (assignName: addr: {
                    inherit assignName addr;
                  }) (net.assignments or { })
                ) config.networks
              );
              match = lib.findFirst (a: a.assignName == name) null allAssignments;
            in
            if match != null then match.addr else null;

          secrets =
            let
              credentialsEnv =
                if config.kubernetes.sso.credentialsEnvironment != null then
                  config.kubernetes.sso.credentialsEnvironment
                else
                  config.environment;
            in
            {
              oidcIssuerFor =
                clientID:
                let
                  pattern =
                    if config.kubernetes.sso.issuerPattern != null then
                      config.kubernetes.sso.issuerPattern
                    else
                      let
                        credEnv = flakeConfig.environments.${credentialsEnv} or null;
                        domain = if credEnv != null then credEnv.domain else environment.domain;
                      in
                      "https://idm.${domain}/oauth2/openid/{clientID}";
                in
                lib.replaceStrings [ "{clientID}" ] [ clientID ] pattern;
            };
        };
    }
  );
in
{
  options.clusters = mkOption {
    type = types.attrsOf clusterType;
    default = { };
    description = "Kubernetes cluster definitions. Each cluster references an environment and owns all k8s configuration.";
  };
}
