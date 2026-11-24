# model-egress — the model endpoints on cortex-cuda, reachable only from
# allow-listed service accounts (federation plan §6.7).
#
# Pod egress on axon is default-deny: `allow-internal-egress`
# (network/cilium/cilium.nix) selects every pod outside genie-eval and, having
# egress rules and no `enableDefaultDeny`, puts each into egress enforcement,
# where only what some policy allows leaves the pod. So access is an allow:
# one CiliumClusterwideNetworkPolicy per (namespace, service account) pair,
# selecting by exactly those two labels. Cilium sets both from the pod spec and
# strips any a pod carries itself (SanitizePodLabels), so a workload cannot
# claim them, where an app label it can.
#
# Gating check: model-egress-check.nix, over the rendered manifests.
{ lib, ... }:
{
  den.aspects.kubernetes.services.ai.model-egress = {
    # cortex-cuda's address and model ports, stated here rather than derived:
    # the host is in the dev environment and its config is host-scoped, so the
    # cluster scope cannot read it (same reasoning as hindsight-settings.nix
    # externalLlms). Sources: modules/den/hosts/cortex-cuda.nix
    # (networking.interfaces.vm-cuda), services/ai/ninfer.nix `port`,
    # services/ai/hyperqwen.nix `port`.
    settings.cidr = lib.mkOption {
      type = lib.types.str;
      default = "10.9.2.2/32";
      description = "cortex-cuda's address, as a CIDR.";
    };

    settings.ports = lib.mkOption {
      type = lib.types.listOf lib.types.port;
      default = [
        8081 # ninfer
        18020 # hyperqwen
      ];
      description = "Model ports on cortex-cuda the allow-listed service accounts may reach.";
    };

    settings.allow = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule {
          options = {
            namespace = lib.mkOption { type = lib.types.str; };
            serviceAccount = lib.mkOption { type = lib.types.str; };
          };
        }
      );
      # No pod is allowed 8081 or 18020 today (hindsight's cortex-cuda entries
      # are llama-cpp on 8080, and render only when selected). These are
      # genie's planned pods.
      default = [
        {
          namespace = "genie";
          serviceAccount = "genie-guard";
        }
        {
          namespace = "genie";
          serviceAccount = "genie-tier1";
        }
      ];
      description = "(namespace, service account) pairs that may reach the model ports.";
    };

    k8s-manifests =
      { cluster, ... }:
      let
        inherit (cluster.settings.kubernetes.services.ai.model-egress) cidr ports allow;
      in
      {
        applications.model-egress = {
          namespace = "kube-system";

          resources.ciliumClusterwideNetworkPolicies = lib.listToAttrs (
            map (
              a:
              lib.nameValuePair "allow-model-egress-${a.namespace}-${a.serviceAccount}" {
                spec = {
                  description = "Allow ${a.namespace}/${a.serviceAccount} to the cortex-cuda model ports.";
                  endpointSelector.matchExpressions = [
                    {
                      key = "k8s:io.kubernetes.pod.namespace";
                      operator = "In";
                      values = [ a.namespace ];
                    }
                    {
                      key = "k8s:io.cilium.k8s.policy.serviceaccount";
                      operator = "In";
                      values = [ a.serviceAccount ];
                    }
                  ];
                  egress = [
                    {
                      toCIDR = [ cidr ];
                      toPorts = [
                        {
                          ports = map (port: {
                            port = toString port;
                            protocol = "TCP";
                          }) ports;
                        }
                      ];
                    }
                  ];
                };
              }
            ) allow
          );
        };
      };
  };
}
