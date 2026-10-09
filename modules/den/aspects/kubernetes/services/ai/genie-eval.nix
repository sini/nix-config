# genie-eval — the namespace genie-agent runs its untrusted Nix evals in, one
# Job per eval (xmsg/genie-agent-design.md §5.2, layers 3-4).
#
# The launcher identity lives in `matrix`, beside the genie-agent pod, and its
# only power is a Role here: create/get/list/watch/delete Jobs and read their
# pods and logs. Nothing in `matrix` (or any other namespace) is granted.
#
# Every container is bounded by the LimitRange (12Gi / 2 CPU, default limit and
# max) but requests only 1Gi / 250m by default, so four pods do not reserve 48Gi.
# The ResourceQuota caps the namespace at 4 live pods, so at most four evals run
# at once.
#
# EGRESS: DNS, plus the fetch hosts by name (toFQDNs, 443 only). The DNS rule
# carries an L7 `dns` section because toFQDNs only learns IPs from lookups that
# pass Cilium's DNS proxy. In-cluster traffic is denied too, which needs the
# cluster-wide `allow-internal-egress` (network/cilium/cilium.nix) to exclude
# this namespace: Cilium policies only add allows, so a CNP here cannot take
# that grant away.
#
# INGRESS: none. `enableDefaultDeny.ingress` engages ingress default-deny with
# no allow rule; the agent sanitizer accepts it because the egress section is
# non-empty (see media/network-policy.nix on the empty-only-section refusal).
#
# Gating check: genie-eval-check.nix, over the rendered manifests.
_:
let
  namespace = "genie-eval";
  launcher = {
    name = "genie-eval-launcher";
    namespace = "matrix";
  };

  fetchHosts = [
    "github.com"
    "codeload.github.com"
    "api.github.com"
    "channels.nixos.org"
    "releases.nixos.org"
    "tarballs.nixos.org"
  ];

  bounds = {
    memory = "12Gi";
    cpu = "2";
  };
  request = {
    memory = "1Gi";
    cpu = "250m";
  };
in
{
  den.aspects.kubernetes.services.ai.genie-eval = {
    service-domains = [ ];

    k8s-manifests = _: {
      applications.genie-eval = {
        inherit namespace;

        resources = {
          serviceAccounts.${launcher.name}.metadata = { inherit (launcher) namespace; };

          roles.${launcher.name}.rules = [
            {
              apiGroups = [ "batch" ];
              resources = [ "jobs" ];
              verbs = [
                "create"
                "get"
                "list"
                "watch"
                "delete"
              ];
            }
            {
              apiGroups = [ "" ];
              resources = [
                "pods"
                "pods/log"
              ];
              verbs = [
                "get"
                "list"
                "watch"
              ];
            }
          ];

          roleBindings.${launcher.name} = {
            roleRef = {
              apiGroup = "rbac.authorization.k8s.io";
              kind = "Role";
              inherit (launcher) name;
            };
            subjects = [
              {
                kind = "ServiceAccount";
                inherit (launcher) name namespace;
              }
            ];
          };

          limitRanges.genie-eval.spec.limits = [
            {
              type = "Container";
              default = bounds;
              defaultRequest = request;
              max = bounds;
            }
          ];

          resourceQuotas.genie-eval.spec.hard.pods = "4";

          ciliumNetworkPolicies.genie-eval-egress.spec = {
            description = "Eval pods: DNS and the Nix fetch hosts only; no ingress, nothing in-cluster.";
            endpointSelector = { };
            enableDefaultDeny.ingress = true;
            egress = [
              {
                toEndpoints = [
                  {
                    matchLabels = {
                      "k8s:io.kubernetes.pod.namespace" = "kube-system";
                      "k8s-app" = "kube-dns";
                    };
                  }
                ];
                toPorts = [
                  {
                    ports = [
                      {
                        port = "53";
                        protocol = "UDP";
                      }
                      {
                        port = "53";
                        protocol = "TCP";
                      }
                    ];
                    rules.dns = [ { matchPattern = "*"; } ];
                  }
                ];
              }
              {
                toFQDNs = map (matchName: { inherit matchName; }) fetchHosts;
                toPorts = [
                  {
                    ports = [
                      {
                        port = "443";
                        protocol = "TCP";
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
}
