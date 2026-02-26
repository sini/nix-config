{ self, lib, ... }:
let
  inherit (self.lib.kubernetes-utils) findClusterMaster;
in
{
  flake.kubernetes.services.cilium = {
    crds =
      { pkgs, lib, ... }:
      let
        # nix run nixpkgs#nix-prefetch-github -- cilium cilium --rev v1.19.1
        # NOTE: Remember to keep pkgs/by-name/cni-plugin-cilium in sync
        src = pkgs.fetchFromGitHub {
          owner = "cilium";
          repo = "cilium";
          rev = "v1.19.1";
          hash = "sha256-wswY4u2Z7Z8hvGVnLONxSD1Mu1RV1AglC4ijUHsCCW4=";
        };
        crds =
          lib.concatMap
            (
              version:
              let
                path = "pkg/k8s/apis/cilium.io/client/crds/${version}";
              in
              lib.pipe (builtins.readDir "${src}/${path}") [
                (lib.filterAttrs (_name: type: type == "regular"))
                (lib.filterAttrs (name: _type: lib.hasSuffix ".yaml" name))
                builtins.attrNames
                (map (file: "${path}/${file}"))
              ]
            )
            [
              "v2"
              "v2alpha1"
            ];
      in
      {
        inherit src crds;
      };

    options = {
      devices = lib.mkOption {
        type = lib.types.nullOr (lib.types.listOf lib.types.str);
        default = null;
        description = "List of devices";
      };
      directRoutingDevice = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Default routing device";
      };
    };

    nixidy =
      {
        config,
        charts,
        environment,
        ...
      }:
      let
        loadbalancer-cidr = config.kubernetes.loadBalancer.cidr;
        ingress-controller-address = config.kubernetes.loadBalancer.reservations.cilium-ingress-controller;

      in
      {
        applications.cilium = {
          namespace = "kube-system";

          annotations."argocd.argoproj.io/sync-wave" = "-2";

          syncPolicy = {
            autoSync = {
              enable = false;
              prune = true;
              selfHeal = true;
            };
            syncOptions = {
              serverSideApply = true;
              applyOutOfSyncOnly = true;
            };
          };

          compareOptions.serverSideDiff = true;

          helm.releases.cilium = {
            chart = charts.cilium.cilium;

            values = {
              namespaceOverride = "kube-system";

              # Cluster identity
              cluster = {
                name = environment.name;
                id = environment.id;
              };

              # Routing Mode
              # routingMode = "native";
              # ipv4NativeRoutingCIDR = environment.kubernetes.clusterCidr;
              routingMode = "tunnel";
              tunnelProtocol = "geneve";

              # endpointRoutes.enabled = true;

              devices = lib.mkIf (
                config.kubernetes.services.cilium.devices != null
              ) config.kubernetes.services.cilium.devices;

              nodePort = lib.optionalAttrs (config.kubernetes.services.cilium.directRoutingDevice != null) {
                directRoutingDevice = config.kubernetes.services.cilium.directRoutingDevice;
              };
              # egress-masquerade-interfaces:

              # Points to the stable loopback routed by the BGP fabric
              k8sServiceHost = findClusterMaster environment;
              k8sServicePort = 6443;

              # Set Cilium as a kube-proxy replacement.
              kubeProxyReplacement = true;

              rollOutCiliumPods = true;
              l2announcements.enabled = true;

              l2NeighDiscovery.enabled = true;

              externalIPs.enabled = true;

              # ingressController = {
              #   enabled = true;
              #   default = true;
              #   loadbalancerMode = "shared";
              #   # hostNetwork.enabled = true;
              #   defaultSecretNamespace = "kube-system";
              #   defaultSecretName = "wildcard-tls";
              #   service = {
              #     annotations = {
              #       "lbipam.cilium.io/ips" = ingress-controller-address;
              #       "lbipam.cilium.io/sharing-key" = "cilium-ingress";
              #     };
              #   };
              # };

              gatewayAPI.enabled = true;
              gatewayAPI.hostNetwork.enabled = false;

              # Don't create secretsNamespace, we do this in the bootstrap app
              tls.secretsNamespace.create = false;
              ingressController.secretsNamespace.create = false;
              gatewayAPI.secretsNamespace.create = false;
              envoyConfig.secretsNamespace.create = false;

              k8sClientRateLimit = {
                qps = 50;
                burst = 200;
              };

              operator = {
                enabled = true;
                rollOutPods = true;
              };

              # Enable Hubble UI (Observability)
              hubble = {
                enabled = true;
                relay.enabled = true;
                ui = {
                  enabled = true;
                  # ingress = {
                  #   annotations = { };
                  #   className = "cilium";
                  #   enabled = true;
                  #   hosts = [ "hubble.${environment.domain}" ];
                  #   labels = { };
                  #   tls = [ { hosts = [ "hubble.${environment.domain}" ]; } ];
                  # };
                };
                # metrics.enabled = [
                #   "dns"
                #   "drop"
                #   "tcp"
                #   "flow"
                #   "port-distribution"
                #   "icmp"
                #   "http"
                # ];

                tls = {
                  auto = {
                    enabled = true;
                    method = "cronJob";
                    # method = "certmanager";
                    # certValidityDuration = 90;
                    # certManagerIssuerRef = {
                    #   group = "cert-manager.io";
                    #   kind = "ClusterIssuer";
                    #   name = "cloudflare-issuer";
                    # };
                  };
                };
              };

              # Needed for the tailscale proxy setup to work.
              socketLB.hostNamespaceOnly = true;
              bpf.lbExternalClusterIP = true;
              bpf.lbSourceRangeAllTypes = true;
              bpf.masquerade = true;
              bpf.disableExternalIPMitigation = true;
              bpf.tproxy = true;

              ipMasqAgent = {
                enabled = true;
                config.nonMasqueradeCIDRs = "{${environment.kubernetes.clusterCidr},${environment.kubernetes.serviceCidr}}";
                config.masqLinkLocal = false;
              };

              # loadBalancer.acceleration = "best-effort";
              # loadBalancer.mode = "dsr";
              # loadBalancer.dsrDispatch = "geneve";

              # IPAM & Pod CIDRs
              ipam = {
                mode = "cluster-pool";
                operator.clusterPoolIPv4PodCIDRList = [ environment.kubernetes.clusterCidr ];
              };

              # BGP control-plane (for FRR peering)
              bgpControlPlane.enabled = true;

              policyEnforcementMode = "default";
              policyAuditMode = false;
            };
          };

          resources = {
            gateways.default-gateway =
              let
                # ip = gateway-controller-address;
                ip = ingress-controller-address;
              in
              {
                metadata.annotations."cert-manager.io/cluster-issuer" = "cloudflare-issuer";
                spec = {
                  gatewayClassName = "cilium";
                  addresses = lib.toList {
                    type = "IPAddress";
                    value = ip;
                  };
                  # infrastructure.annotations."external-dns.alpha.kubernetes.io/hostname" = "${name}.${domain}";
                  listeners = [
                    {
                      name = "http";
                      protocol = "HTTP";
                      port = 80;
                      hostname = "*.${environment.domain}";
                      allowedRoutes.namespaces.from = "All";
                    }
                    {
                      name = "https";
                      protocol = "HTTPS";
                      port = 443;
                      hostname = "*.${environment.domain}";
                      allowedRoutes.namespaces.from = "All";
                      tls = {
                        mode = "Terminate";
                        certificateRefs = [
                          {
                            kind = "Secret";
                            name = "wildcard-tls";
                            namespace = "kube-system";
                          }
                        ];
                      };
                    }
                  ];
                };
              };

            ciliumLoadBalancerIPPools."lb-pool" = {
              metadata = {
                name = "lb-pool";
              };
              spec = {
                blocks = [ { cidr = loadbalancer-cidr; } ];
              };
            };

            ciliumL2AnnouncementPolicies."default-l2-announcement-policy" = {
              metadata = {
                name = "default-l2-announcement-policy";
                namespace = "kube-system";
              };
              spec = {
                externalIPs = true;
                loadBalancerIPs = true;
              };
            };

            ciliumNetworkPolicies = {
              # Allow hubble relay server egress to nodes
              allow-hubble-relay-server-egress.spec = {
                description = "Policy for egress from hubble relay to hubble server in Cilium agent.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "hubble-relay";
                egress = [
                  {
                    toEntities = [
                      "remote-node"
                      "host"
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "4244";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              # Allow hubble UI to talk to hubble relay
              allow-hubble-ui-relay-ingress.spec = {
                description = "Policy for ingress from hubble UI to hubble relay.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "hubble-relay";
                ingress = [
                  {
                    fromEndpoints = [
                      {
                        matchLabels."app.kubernetes.io/name" = "hubble-ui";
                      }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "4245";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              # Allow hubble UI to talk to kube-apiserver
              allow-hubble-ui-kube-apiserver-egress.spec = {
                description = "Allow Hubble UI to talk to kube-apiserver";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "hubble-ui";
                egress = [
                  {
                    toEntities = [ "kube-apiserver" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "6443";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              # Allow kube-dns to talk to upstream DNS
              allow-kube-dns-upstream-egress.spec = {
                description = "Policy for egress to allow kube-dns to talk to upstream DNS.";
                endpointSelector.matchLabels.k8s-app = "kube-dns";
                egress = [
                  {
                    toEntities = [ "world" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "53";
                            protocol = "UDP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              # Allow CoreDNS to talk to kube-apiserver
              allow-kube-dns-apiserver-egress.spec = {
                description = "Allow coredns to talk to kube-apiserver.";
                endpointSelector.matchLabels.k8s-app = "kube-dns";
                egress = [
                  {
                    toEntities = [ "kube-apiserver" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "6443";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              # Allow hubble-generate-certs job to talk to kube-apiserver
              allow-hubble-generate-certs-apiserver-egress.spec = {
                description = "Allow hubble-generate-certs job to talk to kube-apiserver.";
                endpointSelector.matchLabels.k8s-app = "hubble-generate-certs";
                egress = [
                  {
                    toEntities = [ "kube-apiserver" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "6443";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };
            };

            ciliumClusterwideNetworkPolicies = {
              # Allow all cilium endpoints to talk egress to each other
              allow-internal-egress.spec = {
                description = "Policy to allow all Cilium managed endpoint to talk to all other cilium managed endpoints on egress";
                endpointSelector = { };
                egress = [
                  {
                    toEndpoints = [ { } ];
                  }
                ];
              };

              # Allow all health checks
              cilium-health-checks.spec = {
                endpointSelector.matchLabels."reserved:health" = "";
                ingress = [
                  {
                    fromEntities = [ "remote-node" ];
                  }
                ];
                egress = [
                  {
                    toEntities = [ "remote-node" ];
                  }
                ];
              };

              allow-kube-dns-cluster-ingress.spec = {
                description = "Policy for ingress allow to kube-dns from all Cilium managed endpoints in the cluster.";
                endpointSelector.matchLabels = {
                  "k8s:io.kubernetes.pod.namespace" = "kube-system";
                  "k8s-app" = "kube-dns";
                };
                ingress = [
                  {
                    fromEndpoints = [ { } ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "53";
                            protocol = "UDP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

            };
          };
        };
      };
  };
}
