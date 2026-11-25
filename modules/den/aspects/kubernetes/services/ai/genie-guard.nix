# genie-guard as a pod: an xmsg leaf (xmsg X19, federation plan §2.1) whose hub is
# the system owner's xmsg on the `hub` host. Senders on the hub address it as
# `genie-guard@genie-guard.genie` (its node name derives from its URI SAN,
# `<sa>.<ns>`); the hub queues those sends in the leaf's mailbox,
# and the leaf container long-polls it over mTLS and hands each message to the
# guard on register.sock. Nothing connects in: no Service, no ingress.
#
# The pod is xmsg's chart (charts/xmsg, `mode: leaf`) with genie-agent's
# genie-guard overlay (examples/helm/genie-guard-values.yaml): the chart owns the
# leaf sidecar (hardening, shared uid, the /run socket dir, the state dir, the peers
# ConfigMap), the overlay the guard container. This aspect sets only the instance:
# the hubs, the images, and the objects around the pod.
#
# The Deployment and ServiceAccount are named genie-guard (fullnameOverride,
# serviceAccount.name), the SA the SPIFFE id names and the egress policies select.
#
# Identity (plan §6.7): a cert-manager Certificate from xmsg-cluster-ca whose one
# URI SAN is spiffe://<environment domain>/ns/genie/sa/genie-guard. Its Secret's tls.crt is
# leaf, cluster intermediate and root (xmsg-ca.nix), which is the chain
# --fed-cert presents; its ca.crt is the root, the trust anchor for the hub. xmsg
# reloads both when cert-manager rotates them (X17).
#
# Egress (plan §6.4): the hub's federation port only, and the model ports through
# model-egress.nix, both granted to this namespace and service account. The hub
# is addressed by its LAN IP, so no DNS: xmsg's CA verifier checks the chain and
# the URI SAN, never a name against the address.
#
# No gVisor RuntimeClass: the guard executes no model-produced code, it only
# reads a model's verdict.
#
# Gating check: genie-guard-check.nix, over axon's rendered manifests.
{
  config,
  den,
  lib,
  inputs,
  rootPath,
  ...
}:
let
  topConfig = config;
  namespace = "genie";
  name = "genie-guard";
  issuer = "xmsg-cluster-ca";
  tlsSecret = "${name}-xmsg-tls";

  # Enabled, and refused by name until the guard image is pinned.
  enabledFor =
    cluster: images:
    let
      on = cluster.settings.kubernetes.services.ai.genie-guard.enable;
    in
    if on && !(images ? "sini/genie-guard") then
      throw ''
        genie-guard: images/sini/genie-guard/default.nix is absent. Publish ghcr.io/sini/genie-guard,
        then run `nix run .#oci-image-updater -- init --image-name ghcr.io/sini/genie-guard ...`
        and move the file to images/sini/genie-guard/.
      ''
    else
      on;

  hubOf =
    cfg:
    if cfg.hub == null then
      throw "genie-guard: enable needs settings.kubernetes.services.ai.genie-guard.hub, the host whose owner's xmsg is the leaf's hub."
    else
      cfg.hub;

  # spiffe trust domains: a host's and the cluster's own are their environments' domains.
  domainOf = entity: den.environments.${entity.environment}.domain;

  ref = image: "${image.repository}@${image.digest}";
in
{
  # Source-only pins of the chart and the overlay, apart from the `xmsg` and
  # `genie-agent` inputs that pin the fleet's daemon and package.
  flake-file.inputs.xmsg-chart = {
    url = "github:sini/xmsg/ea825d4d7c9ebe294b31ab336981996a848c7d93";
    flake = false;
  };
  flake-file.inputs.genie-agent-helm = {
    url = "github:sini/genie-agent/8017e558234e56e8af65b31452f109bcc4468b61";
    flake = false;
  };

  den.aspects.kubernetes.services.ai.genie-guard = {
    settings.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run genie-guard as an xmsg leaf pod in the genie namespace. Needs images/sini/genie-guard and the xmsg-cluster-ca issuer.";
    };

    settings.hub = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "bitstream";
      description = "The host whose owner's xmsg is the leaf's hub. That node takes the leaf from the xmsg-leaves record this aspect emits. Required with enable.";
    };

    settings.devHubs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "cortex" ];
      description = "More hosts whose owner's xmsg the leaf also pulls from, for development and testing. The model endpoint stays the primary hub's.";
    };

    age-secrets = _: {
      age.secrets = {
        # The key the bitstream guard reads (services/ai/hyperqwen-client.nix);
        # generated there, so no generator here.
        genie-guard-api-key = {
          rekeyFile = rootPath + "/.secrets/env/dev/hyperqwen/api-key.age";
          sopsOutput = {
            file = "genie-guard";
            key = "api-key";
          };
        };
      };
    };

    k8s-manifests =
      {
        config,
        cluster,
        images,
        lib,
        ...
      }:
      let
        cfg = cluster.settings.kubernetes.services.ai.genie-guard;
        hub = den.hosts.x86_64-linux.${hubOf cfg};
        # The chart's leaf.hubs. A hub is keyed by the node name its identity derives,
        # `<user>.<host>` (xmsg README 7.0); the leaf routes each reply to the peer of
        # the origin's node.
        fleetHubs = inputs.xmsg.lib.fleet.peersFor {
          fleet = topConfig.xmsg.fleet;
          self = "${name}.${namespace}";
        };
        primaryHubOrder = map (h: "${den.hosts.x86_64-linux.${h}.system-owner}.${h}") (
          [ (hubOf cfg) ] ++ (cfg.devHubs or [ ])
        );
        orderedHubNames =
          primaryHubOrder
          ++ (lib.filter (n: !(builtins.elem n primaryHubOrder)) (builtins.attrNames fleetHubs));
        chartHubs = map (n: {
          name = n;
          inherit (fleetHubs.${n}) address;
          identity = builtins.head fleetHubs.${n}.identities;
        }) orderedHubNames;
        # lib is nixidy's module lib here, whose lib.kube parses the overlay's YAML.
        overlay = lib.head (
          lib.kube.fromYAML (
            builtins.readFile "${inputs.genie-agent-helm}/examples/helm/genie-guard-values.yaml"
          )
        );
      in
      lib.optionalAttrs (enabledFor cluster images) {
        applications.${name} = {
          inherit namespace;

          helm.releases.${name} = {
            chart = "${inputs.xmsg-chart}/charts/xmsg";
            values = lib.recursiveUpdate overlay {
              fullnameOverride = name;
              serviceAccount.name = name;
              image = { inherit (images."sini/xmsg") repository digest; };
              tls.existingSecret = tlsSecret;
              leaf = {
                prepareImage = ref images."library/busybox";
                hubs = chartHubs;
                containers = map (
                  c: if c.name == name then c // { image = ref images."sini/genie-guard"; } else c
                ) overlay.leaf.containers;
              };
            };
          };

          resources = {
            certificates.${name}.spec = {
              secretName = tlsSecret;
              issuerRef = {
                name = issuer;
                kind = "ClusterIssuer";
                group = "cert-manager.io";
              };
              uris = [ "spiffe://${domainOf cluster}/ns/${namespace}/sa/${name}" ];
              usages = [
                "digital signature"
                "key encipherment"
                "server auth"
                "client auth"
              ];
              # Short-lived: expiry stands in for revocation (plan §6.7).
              duration = "24h";
              renewBefore = "8h";
              privateKey = {
                algorithm = "ECDSA";
                size = 256;
                encoding = "PKCS8";
                rotationPolicy = "Always";
              };
            };

            # The overlay's guard container reads both keys. The URL is no secret, but
            # it rides in the same Secret so the guard's whole configuration is one object.
            secrets.${name}.stringData = {
              api-key = config.age.secrets.genie-guard-api-key.sopsRef;
              # The hub's own guard setting, so both guards ask the same endpoint.
              ninfer-url = hub.settings.applications.dev.ai.mcp.xmsg.genieGuard.ninferUrl;
            };

            ciliumClusterwideNetworkPolicies."allow-xmsg-egress-${namespace}-${name}".spec = {
              description = "Allow ${namespace}/${name} to its xmsg hubs' federation ports.";
              endpointSelector.matchExpressions = [
                {
                  key = "k8s:io.kubernetes.pod.namespace";
                  operator = "In";
                  values = [ namespace ];
                }
                {
                  key = "k8s:io.cilium.k8s.policy.serviceaccount";
                  operator = "In";
                  values = [ name ];
                }
              ];
              egress = map (
                h:
                let
                  m = builtins.match "^([^:]+):([0-9]+)$" h.address;
                  ip = builtins.elemAt m 0;
                  port = builtins.elemAt m 1;
                in
                {
                  toCIDR = [ "${ip}/32" ];
                  toPorts = [
                    {
                      ports = [
                        {
                          inherit port;
                          protocol = "TCP";
                        }
                      ];
                    }
                  ];
                }
              ) chartHubs;
            };
          };
        };
      };
  };
}
