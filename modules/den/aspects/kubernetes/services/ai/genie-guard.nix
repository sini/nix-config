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
# The chart names its ServiceAccount `<release>-xmsg`, so the pod runs as
# genie-guard-xmsg while its SPIFFE id keeps sa/genie-guard (the node name). The
# egress policies select the ServiceAccount the pod runs as.
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
  den,
  lib,
  inputs,
  rootPath,
  ...
}:
let
  namespace = "genie";
  name = "genie-guard";
  # The chart's `<release>-xmsg` ServiceAccount, the one the pod runs as.
  serviceAccount = "${name}-xmsg";
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
    url = "github:sini/xmsg/a3efb129c8e99a873c7a39b6f78eb8768b5719c5";
    flake = false;
  };
  flake-file.inputs.genie-agent-helm = {
    url = "github:sini/genie-agent/4d8e39cf6487270d472f8dddda9fb1b371993bdf";
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

    # The hubs take the leaf from this record (applications/dev/ai/mcp/xmsg.nix).
    xmsg-leaves =
      { cluster, ... }:
      let
        cfg = cluster.settings.kubernetes.services.ai.genie-guard;
      in
      lib.optionals cfg.enable [
        {
          identity = "spiffe://${domainOf cluster}/ns/${namespace}/sa/${name}";
          cluster = cluster.name;
          hubs = map (h: "${den.hosts.x86_64-linux.${h}.system-owner}.${h}") ([ (hubOf cfg) ] ++ cfg.devHubs);
          # It answers what it collects, and is sent nothing but guard requests.
          allow = [ "reply" ];
          targets = [ name ];
        }
      ];

    # Declared with the flag off too, so the sops store holds the key before the pod
    # needs it and turning the flag on needs only the image.
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
        xmsg-nodes ? [ ],
        ...
      }:
      let
        cfg = cluster.settings.kubernetes.services.ai.genie-guard;
        hub = den.hosts.x86_64-linux.${hubOf cfg};
        # The leaf pulls from every peer in its file, each mailbox on its own.
        hubs = map (h: rec {
          name = h;
          host = den.hosts.x86_64-linux.${h};
          ip = lib.head host.ipv4;
          port = host.settings.applications.dev.ai.mcp.xmsg.federation.nodes.${host.system-owner}.port;
        }) ([ (hubOf cfg) ] ++ cfg.devHubs or [ ]);
        # Service nodes that screen through this pod (services/matrix-xmsg.nix `guards`)
        # are hubs too: the pod collects their guard requests from them.
        serviceHubs = lib.filter (n: lib.elem "${name}@${name}.${namespace}" (n.guards or [ ])) xmsg-nodes;
        # The chart's leaf.hubs. A hub is keyed by the node name its identity derives,
        # `<user>.<host>` (xmsg README 7.0); the leaf routes each reply to the peer of
        # the origin's node.
        chartHubs =
          map (h: {
            name = "${h.host.system-owner}.${h.name}";
            address = "${h.ip}:${toString h.port}";
            identity = "spiffe://${domainOf h.host}/host/${h.name}/user/${h.host.system-owner}";
          }) hubs
          ++ map (n: {
            inherit (n) name identity;
            address = "${n.lanIp}:${toString n.port}";
          }) serviceHubs;
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
                  values = [ serviceAccount ];
                }
              ];
              egress = map (h: {
                toCIDR = [ "${h.ip}/32" ];
                toPorts = [
                  {
                    ports = [
                      {
                        port = toString h.port;
                        protocol = "TCP";
                      }
                    ];
                  }
                ];
              }) (hubs ++ map (n: { inherit (n) ip port; }) (map (n: n // { ip = n.lanIp; }) serviceHubs));
            };
          };
        };
      };
  };
}
