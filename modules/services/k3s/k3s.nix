{
  rootPath,
  config,
  ...
}:
let
  # Get hosts from the flake config
  hosts = config.flake.hosts;
  # Helper function to find master nodes in the same cluster and environment
  findClusterMaster =
    currentHostEnvironment: hosts: lib:
    let
      clusterHosts = lib.attrsets.filterAttrs (
        hostname: hostConfig:
        (builtins.elem "kubernetes" (hostConfig.roles or [ ]))
        && (hostConfig.environment == currentHostEnvironment)
      ) hosts;

      masterHosts = lib.attrsets.filterAttrs (
        hostname: hostConfig: builtins.elem "kubernetes-master" (hostConfig.roles or [ ])
      ) clusterHosts;
    in
    if lib.length (lib.attrNames masterHosts) > 0 then
      let
        masterHost = lib.head (lib.attrValues masterHosts);
      in
      masterHost.tags.kubernetes-internal-ip or masterHost.ipv4
    else
      null;

  # Original commented logic for reference:
  # hosts = config.flake.hosts;
  # kubernetesMasterMap = builtins.listToAttrs (
  #   map
  #     (
  #       { name, value }:
  #       {
  #         name = value.tags."kubernetes-cluster";
  #         value = name;
  #       }
  #     )
  #     (
  #       lib.filter (
  #         host:
  #         builtins.elem "kubernetes-master" (host.value.roles or [ ])
  #         && host.value.tags ? "kubernetes-cluster"
  #       ) (lib.attrsToList hosts)
  #     )
  # );
in
{
  flake.modules.nixos.kubernetes =
    {
      lib,
      pkgs,
      config,
      hostOptions,
      environment,
      ...
    }:
    let
      currentHostEnvironment = hostOptions.environment;
      isMaster = builtins.elem "kubernetes-master" hostOptions.roles;
      clusterInit = isMaster;
      internalIP = hostOptions.tags.kubernetes-internal-ip or hostOptions.ipv4;
      externalIP = hostOptions.ipv4;

      # Find master node for agent connection (using hosts from outer scope)
      masterIP = findClusterMaster currentHostEnvironment hosts lib;
    in
    {
      age.secrets.kubernetes-cluster-token = {
        rekeyFile = rootPath + "/.secrets/k3s/${environment.name}/k3s-token.age";
      };

      environment.systemPackages = with pkgs; [
        k3s
        k9s
        kubectl
        istioctl
        kubernetes-helm
        cilium-cli

        clusterctl # for kubernetes cluster-api
        nerdctl # containerd CLI, similar to docker CLI

        skopeo # copy/sync images between registries and local storage
        go-containerregistry # provides `crane` & `gcrane`, it's similar to skopeo
        dive # explore docker layers

        openiscsi # Required for Longhorn
        nfs-utils # Required for Longhorn
      ];

      # Kernel modules required by cilium
      boot.kernelModules = [
        "ip6_tables"
        "ip6table_mangle"
        "ip6table_raw"
        "ip6table_filter"
      ];

      networking = {
        enableIPv6 = true;
        nat = {
          enable = true;
          enableIPv6 = true;
        };
        nftables.enable = lib.mkForce false;
        firewall.enable = lib.mkForce false;
      };

      # TODO: Enable proper firewall configuration
      # Required ports: 6443 (API), 2379/2380 (etcd), 8472 (CNI)

      services = {
        nix-snapshotter.enable = true;

        k3s =
          let
            generalFlagList = [
              "--image-service-endpoint=unix:///run/nix-snapshotter/nix-snapshotter.sock"
              "--snapshotter=overlayfs"
              "--container-runtime-endpoint=unix:///run/containerd/containerd.sock"
              "--node-ip=${internalIP}"
              "--node-external-ip=${externalIP}"
              "--node-label=node.longhorn.io/create-default-disk=true"
              # CoreDNS doesn't like systemd-resolved's /etc/resolv.conf
              "--resolv-conf=/run/systemd/resolve/resolv.conf"
            ];
            serverFlagList = [
              "--bind-address=0.0.0.0"
              "--cluster-cidr=${environment.kubernetes.clusterCidr}"
              "--service-cidr=${environment.kubernetes.serviceCidr}"

              "--write-kubeconfig-mode \"0644\""
              "--etcd-expose-metrics"
              "--disable-helm-controller"

              "--disable local-storage"
              "--disable metrics-server"
              "--disable traefik"

              "--disable servicelb" # Cilium
              "--flannel-backend=none" # Cilium
              "--disable-network-policy" # Cilium
              "--disable-kube-proxy" # Cilium will handle this
              "--disable-cloud-controller"

              "--tls-san=${config.networking.fqdn}"
              "--tls-san=${config.networking.hostName}"
              "--tls-san=${externalIP}"
            ]
            ++ (lib.map (ip: "--tls-san=${ip}") environment.kubernetes.tlsSanIps);
            #agentFlags = builtins.concatStringsSep " " generalFlagList;
            serverFlags = builtins.concatStringsSep " " (generalFlagList ++ serverFlagList);
          in
          {
            inherit clusterInit;
            enable = true;
            role = "server";
            tokenFile = config.age.secrets.kubernetes-cluster-token.path;
            gracefulNodeShutdown.enable = true;
            extraFlags = lib.mkForce serverFlags;
          }
          // lib.optionalAttrs (!isMaster && masterIP != null) {
            serverAddr = "https://${masterIP}:6443";
            # }
            # // lib.optionalAttrs isMaster {
            #   # Bootstrap cluster components using template-based manifests
            #   manifests =
            #     let
            #       # Template substitution helper
            #       substitute =
            #         template: vars:
            #         builtins.replaceStrings (builtins.attrNames vars) (builtins.attrValues vars) template;
            #     in
            #     {
            #       # Cilium CNI via HelmChart CRD
            #       cilium = {
            #         source = pkgs.writeTextFile {
            #           name = "k3s-cilium.yaml";
            #           text = substitute (builtins.readFile (rootPath + "/k8s/helm/k3s-cilium.yaml")) {
            #             "@version@" = "1.18.0";
            #             "@clusterName@" = kubernetesCluster;
            #             "@masterIP@" = masterIP;
            #           };
            #         };
            #       };

            #       # ArgoCD via HelmChart CRD
            #       argocd = {
            #         source = pkgs.writeTextFile {
            #           name = "k3s-argocd.yaml";
            #           text = substitute (builtins.readFile (rootPath + "/k8s/helm/k3s-argocd.yaml")) {
            #             "@version@" = "7.7.11";
            #             "@clusterName@" = kubernetesCluster;
            #           };
            #         };
            #       };

            #       # ArgoCD Application for nixidy GitOps
            #       argocd-apps = {
            #         content = {
            #           apiVersion = "argoproj.io/v1alpha1";
            #           kind = "Application";
            #           metadata = {
            #             name = "prod-cluster";
            #             namespace = "argocd";
            #             finalizers = [
            #               "resources-finalizer.argocd.argoproj.io"
            #             ];
            #           };
            #           spec = {
            #             project = "default";
            #             source = {
            #               repoURL = "https://github.com/sini/nix-config";
            #               targetRevision = "HEAD";
            #               path = "k8s/nixidy/manifests/prod";
            #             };
            #             destination = {
            #               server = "https://kubernetes.default.svc";
            #             };
            #             syncPolicy = {
            #               automated = {
            #                 prune = true;
            #                 selfHeal = true;
            #                 allowEmpty = false;
            #               };
            #               syncOptions = [
            #                 "CreateNamespace=true"
            #                 "PrunePropagationPolicy=foreground"
            #                 "PruneLast=true"
            #               ];
            #               retry = {
            #                 limit = 5;
            #                 backoff = {
            #                   duration = "5s";
            #                   factor = 2;
            #                   maxDuration = "3m";
            #                 };
            #               };
            #             };
            #           };
            #         };
            #       };
            #     };
          };

        # Required for Longhorn
        openiscsi = {
          enable = true;
          name = "iqn.2016-04.com.open-iscsi:${config.networking.fqdn}";
        };
      };
    };
}
