# genie-guard as a pod: an xmsg leaf (xmsg X19, federation plan §2.1) whose hub is
# the system owner's xmsg on bitstream. Senders on the hub address it as
# `svc:genie-guard@genie-guard`; the hub queues those sends in the leaf's mailbox,
# and the leaf container long-polls it over mTLS and hands each message to the
# guard on register.sock. Nothing connects in: no Service, no ingress.
#
# Both containers run as one uid, because the leaf admits a registration on
# register.sock by SO_PEERCRED uid (exe attestation is impossible across
# containers). XDG_RUNTIME_DIR is an emptyDir mounted in both; the leaf creates
# its `xmsg/` socket dir under it, owned by that uid and mode 0700, as xmsg
# requires of an existing socket dir (an emptyDir root is owned by root).
#
# Identity (plan §6.7): a cert-manager Certificate from xmsg-cluster-ca whose one
# URI SAN is spiffe://json64.dev/ns/genie/sa/genie-guard. Its Secret's tls.crt is
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
# Gating check: genie-guard-check.nix, over this aspect's manifests with the
# flag forced on.
{
  den,
  lib,
  rootPath,
  ...
}:
let
  namespace = "genie";
  name = "genie-guard";
  uid = 65532;
  issuer = "xmsg-cluster-ca";
  runtimeDir = "/run/user";
  tlsDir = "/etc/xmsg/tls";
  peersDir = "/etc/xmsg/peers";
  stateDir = "/var/lib/xmsg";
  keyDir = "/etc/genie-guard";

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

  ref = image: "${image.repository}@${image.digest}";

  hardened = {
    runAsUser = uid;
    runAsGroup = uid;
    runAsNonRoot = true;
    readOnlyRootFilesystem = true;
    allowPrivilegeEscalation = false;
    capabilities.drop = [ "ALL" ];
  };
in
{
  den.aspects.kubernetes.services.ai.genie-guard = {
    settings.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run genie-guard as an xmsg leaf pod in the genie namespace. Needs images/sini/genie-guard and the xmsg-cluster-ca issuer.";
    };

    settings.hub = lib.mkOption {
      type = lib.types.str;
      default = "bitstream";
      description = "The host whose owner's xmsg is the leaf's hub; it must list the leaf in applications.dev.ai.mcp.xmsg.federation.leaves.";
    };

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
        ...
      }:
      let
        cfg = cluster.settings.kubernetes.services.ai.genie-guard;
        hub = den.hosts.x86_64-linux.${cfg.hub};
        hubIp = lib.head hub.ipv4;
        hubPort = hub.settings.applications.dev.ai.mcp.xmsg.federation.port;
        # The hub's peer name is its host name: the hub stamps its host label (the
        # hostname) on each message's origin, and the leaf routes the reply to the
        # peer of that name.
        peers = {
          ${cfg.hub} = {
            address = "${hubIp}:${toString hubPort}";
            ca = "${tlsDir}/ca.crt";
            identities = [ "spiffe://json64.dev/host/${cfg.hub}/user/${hub.system-owner}" ];
            # The leaf has no listener, so nothing is admitted inbound.
            allow = [ ];
          };
        };
        runMount = {
          name = "run";
          mountPath = runtimeDir;
        };
        # The root is read-only; a writable /tmp keeps the guard's runtime from
        # failing at start.
        tmpMount = {
          name = "tmp";
          mountPath = "/tmp";
        };
      in
      lib.optionalAttrs (enabledFor cluster images) {
        applications.${name} = {
          inherit namespace;

          resources = {
            serviceAccounts.${name}.automountServiceAccountToken = false;

            certificates.${name}.spec = {
              secretName = "${name}-xmsg-tls";
              issuerRef = {
                name = issuer;
                kind = "ClusterIssuer";
                group = "cert-manager.io";
              };
              uris = [ "spiffe://json64.dev/ns/${namespace}/sa/${name}" ];
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

            configMaps."${name}-xmsg-peers".data."peers.json" = builtins.toJSON peers;

            # The URL is no secret, but it rides in the same Secret so the guard's
            # whole configuration is one object.
            secrets.${name}.stringData = {
              api-key = config.age.secrets.genie-guard-api-key.sopsRef;
              # The hub's own guard setting, so both guards ask the same endpoint.
              ninfer-url = hub.settings.applications.dev.ai.mcp.xmsg.genieGuard.ninferUrl;
            };

            deployments.${name}.spec = {
              replicas = 1;
              selector.matchLabels."app.kubernetes.io/name" = name;
              template = {
                metadata.labels."app.kubernetes.io/name" = name;
                spec = {
                  serviceAccountName = name;
                  automountServiceAccountToken = false;
                  enableServiceLinks = false;
                  securityContext = {
                    runAsUser = uid;
                    runAsGroup = uid;
                    runAsNonRoot = true;
                    fsGroup = uid;
                    seccompProfile.type = "RuntimeDefault";
                  };
                  containers = [
                    {
                      name = "xmsg";
                      image = ref images."sini/xmsg";
                      args = [
                        "serve"
                        "--leaf"
                        "--leaf-principal"
                        "svc:${name}"
                        # Required by --leaf; loopback in the pod's own netns.
                        "--listen"
                        "127.0.0.1:7787"
                        "--host-label"
                        name
                        "--leaf-register-sock"
                        "${runtimeDir}/xmsg/register.sock"
                        "--db-path"
                        "${stateDir}/xmsg.db"
                        "--peers-file"
                        "${peersDir}/peers.json"
                        "--fed-cert"
                        "${tlsDir}/tls.crt"
                        "--fed-key"
                        "${tlsDir}/tls.key"
                      ];
                      env = [
                        {
                          name = "XDG_RUNTIME_DIR";
                          value = runtimeDir;
                        }
                      ];
                      securityContext = hardened;
                      volumeMounts = [
                        runMount
                        tmpMount
                        {
                          name = "state";
                          mountPath = stateDir;
                        }
                        {
                          name = "tls";
                          mountPath = tlsDir;
                          readOnly = true;
                        }
                        {
                          name = "peers";
                          mountPath = peersDir;
                          readOnly = true;
                        }
                      ];
                    }
                    {
                      inherit name;
                      image = ref images."sini/genie-guard";
                      env = [
                        {
                          name = "XDG_RUNTIME_DIR";
                          value = runtimeDir;
                        }
                        {
                          name = "GENIE_GUARD_NINFER_URL";
                          valueFrom.secretKeyRef = {
                            inherit name;
                            key = "ninfer-url";
                          };
                        }
                        {
                          name = "GENIE_GUARD_API_KEY_FILE";
                          value = "${keyDir}/api-key";
                        }
                      ];
                      securityContext = hardened;
                      volumeMounts = [
                        runMount
                        tmpMount
                        {
                          name = "api-key";
                          mountPath = keyDir;
                          readOnly = true;
                        }
                      ];
                    }
                  ];
                  volumes = [
                    {
                      name = "run";
                      emptyDir.medium = "Memory";
                    }
                    {
                      name = "state";
                      emptyDir = { };
                    }
                    {
                      name = "tmp";
                      emptyDir = { };
                    }
                    {
                      name = "tls";
                      secret = {
                        secretName = "${name}-xmsg-tls";
                        defaultMode = 288; # 0440, read through fsGroup
                      };
                    }
                    {
                      name = "peers";
                      configMap.name = "${name}-xmsg-peers";
                    }
                    {
                      name = "api-key";
                      secret = {
                        secretName = name;
                        items = [
                          {
                            key = "api-key";
                            path = "api-key";
                          }
                        ];
                        defaultMode = 288;
                      };
                    }
                  ];
                };
              };
            };

            ciliumClusterwideNetworkPolicies."allow-xmsg-egress-${namespace}-${name}".spec = {
              description = "Allow ${namespace}/${name} to its xmsg hub's federation port.";
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
              egress = [
                {
                  toCIDR = [ "${hubIp}/32" ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = toString hubPort;
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
