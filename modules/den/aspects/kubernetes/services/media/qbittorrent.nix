# qBittorrent — BitTorrent client routed through a Gluetun WireGuard sidecar.
#
# Routed + OIDC-protected UI on the gateway (cluster.domainFor "qbittorrent"). The
# OIDC clientID stays "qbittorrent".
#
# == VPN topology (single pod, shared netns) ==
# qBittorrent's traffic MUST egress only through the VPN tunnel. We co-locate two
# containers in one pod (controllers.main): the `main` qBittorrent container and a
# `gluetun` native sidecar (a k8s restartPolicy=Always initContainer) running a
# custom-provider WireGuard tunnel (ProtonVPN). Pods share a single network
# namespace, so the qBittorrent container's loopback IS gluetun's loopback and its
# outbound sockets route through gluetun's tun0 — the same model as the old compose
# `network_mode: service:qbt-vpn`.
#
# Native sidecar ordering: as a restartPolicy=Always initContainer, gluetun starts
# BEFORE the `main` container and keeps running for the pod's lifetime. With a
# readiness probe on gluetun's control server (below), the kubelet holds `main`
# until the tunnel is up — so qBittorrent never runs before its only egress path
# exists. (app-template v5 renders restartPolicy + probes on initContainers via the
# same container spec template as regular containers; verified against the vendored
# chart.)
#
# tun device: gluetun needs /dev/net/tun. app-template can mount a host char
# device via a hostPath persistence entry (type=hostPath, hostPathType=CharDevice)
# plus an advancedMounts target scoped to the gluetun container only. gluetun also
# needs NET_ADMIN (set on its container securityContext).
#
# == Kill-switch / leak prevention (defense in depth) ==
# 1. PRIMARY: gluetun's built-in firewall. With VPN_SERVICE_PROVIDER=custom it
#    blocks all non-tunnel egress except FIREWALL_OUTBOUND_SUBNETS (the cluster
#    pod/service CIDRs + the management VLAN) and the WireGuard endpoint. If the
#    tunnel drops, gluetun drops traffic — qBittorrent cannot leak to the clear.
# 2. BELT+SUSPENDERS: CiliumNetworkPolicies on the pod. We do NOT add a world
#    80/443 egress. Instead the policies below allow only:
#      - world UDP 51820 (the WireGuard handshake/data to the ProtonVPN endpoint;
#        the endpoint IP/port live in a secret a CNP can't read, so we allow the
#        standard ProtonVPN WG port to all of `world`);
#      - intra-namespace ingress on 8080 from the *arr API callers + unpackerr.
#    DNS + gateway-ingress are the routed-app baseline. Cilium policies are
#    additive (union of allows), so these compose. No TCP world-egress policy
#    exists, so even if gluetun's firewall were misconfigured, Cilium denies
#    cleartext TCP to the internet.
#
# INVARIANT — pre-tunnel leak surface: the native sidecar (above) closes the
# startup race by ordering gluetun's tunnel ahead of `main`. The CNP floor is the
# second, independent layer: the ONLY world egress this pod can ever make is
# UDP/51820 (WireGuard) + DNS, because NO world-TCP egress policy exists for this
# endpoint. Do NOT add a world-TCP egress policy to this pod — doing so would punch
# a cleartext hole straight through the kill-switch. The leak surface is bounded to
# UDP/51820 + DNS by construction, sidecar or not.
#
# == Port forwarding ==
# ProtonVPN supports incoming port forwarding; gluetun (VPN_PORT_FORWARDING=on)
# obtains the forwarded port and exposes it on its control server at
# 127.0.0.1:8000/v1/portforward (v3.40+ path; the old /v1/openvpn/portforwarded 301s and busybox wget will not follow). We do NOT use gluetun's
# VPN_PORT_FORWARDING_UP_COMMAND: app-template runs every container env value
# through Helm's `tpl`, which chokes on gluetun's {{PORTS}} placeholder
# ("function PORTS not defined") — escaping it through two template layers is
# fragile. Instead a tiny third container `port-sync` (busybox, polling the
# shared loopback) reads the forwarded port from the gluetun control server every
# 60s and, when it changes, PATCHes qBittorrent's listen port via the WebUI API.
# This mirrors the old compose's gsp DOCKER_MOD (which polled gluetun:8000). The
# WebUI call is unauthenticated because qBittorrent's WebUI\LocalHostAuth is
# disabled (seeded below) and all three containers share the pod loopback —
# the canonical localhost bypass. (AuthSubnetWhitelist was tried first; qbt
# never accepted the seeded keys and flattened them on its config save.)
# DEPLOY-VALIDATE: confirm the forwarded port lands in qBittorrent prefs after
# first connect (check `port-sync` logs).
#
# == WebUI / API config ==
# qBittorrent reads its WebUI settings from qBittorrent.conf, not env. We seed it
# via an init container (idempotent, [Preferences] section guard like sabnzbd's
# [misc] guard): on a fresh /config write a minimal [Preferences] enabling the
# localhost auth-subnet whitelist (so the up-command can hit the API without a
# password) and disabling host-header validation (so the proxied Host header from
# the gateway is accepted); on an existing /config reconcile those keys.
#
# == Secrets ==
# The WireGuard material (private key, addresses, peer public key, endpoint
# IP/port) is provided EXTERNALLY by the operator — there is NO generator, by
# design: these are issued by ProtonVPN, not derivable. Everything else in this
# stack uses agenix-rekey generators; manual encryption is reserved for exactly
# this class of secret. To provision from a downloaded wireguard conf (no
# decryption key needed — encrypt to the master recipient from .secrets/pub):
#   printf '%s' "$VALUE" | age -r "$(grep -oP 'age1\S+' .secrets/pub/master.pub)" \
#     -o .secrets/env/prod/media-vpn/<field>.age
# Fields: private-key ([Interface] PrivateKey), addresses (ipv4 from Address),
# peer-public-key ([Peer] PublicKey), endpoint-ip / endpoint-port (Endpoint).
# `agenix edit` works too. `agenix rekey` then rekeys per-host and the
# agenix-rekey-to-sops extension emits the cluster sops file `media-vpn`
# (5 keys). A k8s Secret `media-vpn` surfaces them; gluetun's env pulls each
# via valueFrom.secretKeyRef. Nothing is hardcoded.
#
# Version: the media-user backup carries no qBittorrent version marker (the conf
# has no version field; the old image was the floating :libtorrentv1 tag). We pin
# the latest libtorrent-v1-line LSIO tag (5.2.1-libtorrentv1). Gluetun pinned to
# v3.41.1. Bump both in the deploy-time pass.
#
# This aspect describes its full service inline (it does not call the _media-app
# builder). The two shell scripts are kept as verbatim data bindings; everything
# else — the WireGuard secrets, gluetun env, network policies, route + OIDC — is
# stated explicitly.
{
  den.aspects.kubernetes.services.media.qbittorrent = {
    service-domains = [ "qbittorrent" ];

    age-secrets =
      { environment, ... }:
      {
        age.secrets = {
          qbittorrent-oidc-client-secret = {
            rekeyFile = environment.secretPath + "/oidc/qbittorrent-oidc-client-secret.age";
            generator = {
              tags = [ "oidc" ];
              script = "rfc3986-secret";
            };
            sopsOutput = {
              file = "oidc";
              key = "qbittorrent";
            };
          };

          # Externally-provided WireGuard material — NO generator, by design
          # (issued by ProtonVPN; operator fills via `agenix edit`). Rekeyed into
          # the cluster sops file `media-vpn`, one key per field.
          media-vpn-private-key = {
            rekeyFile = environment.secretPath + "/media-vpn/private-key.age";
            sopsOutput = {
              file = "media-vpn";
              key = "private-key";
            };
          };
          media-vpn-addresses = {
            rekeyFile = environment.secretPath + "/media-vpn/addresses.age";
            sopsOutput = {
              file = "media-vpn";
              key = "addresses";
            };
          };
          media-vpn-peer-public-key = {
            rekeyFile = environment.secretPath + "/media-vpn/peer-public-key.age";
            sopsOutput = {
              file = "media-vpn";
              key = "peer-public-key";
            };
          };
          media-vpn-endpoint-ip = {
            rekeyFile = environment.secretPath + "/media-vpn/endpoint-ip.age";
            sopsOutput = {
              file = "media-vpn";
              key = "endpoint-ip";
            };
          };
          media-vpn-endpoint-port = {
            rekeyFile = environment.secretPath + "/media-vpn/endpoint-port.age";
            sopsOutput = {
              file = "media-vpn";
              key = "endpoint-port";
            };
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        charts,
        images,
        ...
      }:
      let
        webuiPort = 8080;

        # Alloy River config for the per-pod log-tail sidecar. qBittorrent writes
        # to /config/qBittorrent/logs/qbittorrent.log with .bak/.bakN backups, so
        # the glob `qbittorrent.log*` catches the active file + rotations. The line
        # format prefixes a parenthesised level letter — (N)ormal, (I)nfo,
        # (W)arning, (C)ritical — which we lift verbatim into the `level` label.
        # The duplicate main-container stdout copy is dropped at the cluster
        # DaemonSet via the den.observability/file-tailed pod label.
        #
        # Egress: the logtail push to loki.monitoring.svc (an in-cluster service
        # IP in 172.21.0.0/16) is permitted both by Cilium's clusterwide
        # allow-internal-egress and by gluetun's FIREWALL_OUTBOUND_SUBNETS (which
        # already lists 172.21.0.0/16), so the sidecar reaches loki through the
        # kill-switch without widening any firewall.
        #
        # CRITICAL: validate any edit with `nix run nixpkgs#grafana-alloy -- fmt`.
        logtailConfig = ''
          local.file_match "logs" {
            path_targets = [{
              "__path__"  = "/config/qBittorrent/logs/qbittorrent.log*",
              "app"       = "qbittorrent",
              "namespace" = "media",
            }]
          }

          loki.source.file "logs" {
            targets    = local.file_match.logs.targets
            forward_to = [loki.process.logs.receiver]
          }

          loki.process "logs" {
            stage.regex {
              expression = "^\\((?P<level>N|I|W|C)\\)"
            }

            stage.labels {
              values = {
                level = "",
              }
            }

            forward_to = [loki.write.default.receiver]
          }

          loki.write "default" {
            endpoint {
              url = "http://loki.monitoring.svc:3100/loki/api/v1/push"
            }
          }
        '';

        # qBittorrent.conf seeder. Idempotent:
        #   fresh /config -> write a minimal [Preferences] section
        #   existing      -> reconcile the auth-whitelist + host-header keys
        # printf (not a heredoc) to survive Nix indented-string dedenting.
        configSeedScript = ''
          set -eu
          INI=/config/qBittorrent/qBittorrent.conf
          mkdir -p /config/qBittorrent
          # A fresh pod can never legitimately hold the single-instance lock (RWO
          # PVC, replicas=1). A stale lockfile from a prior pod makes qbt assume a
          # running instance and exit 0 silently — crash-looping with zero output.
          rm -f /config/qBittorrent/lockfile
          ensure_key() {
            # ensure_key <key-escaped-for-sed> <full-line>
            # NB: $line lands in sed REPLACEMENT/append contexts, where a lone
            # backslash is consumed (s|..|WebUI\X| emits WebUIX — this is what
            # flattened the first deployment's keys on its second boot). Escape
            # backslashes for those contexts.
            key="$1"; line="$2"
            escline=$(printf '%s' "$line" | sed 's|\\|\\\\|g')
            if grep -q "^$key=" "$INI"; then
              sed -i "s|^$key=.*|$escline|" "$INI"
            else
              sed -i "/^\[Preferences\]/a $escline" "$INI"
            fi
          }
          # Same as ensure_key but for the [Application] section (FileLogger\*
          # rotation keys live there, not under [Preferences]). Creates the
          # section if absent. Idempotent.
          ensure_app_key() {
            key="$1"; line="$2"
            escline=$(printf '%s' "$line" | sed 's|\\|\\\\|g')
            grep -q '^\[Application\]' "$INI" || printf '\n[Application]\n' >> "$INI"
            if grep -q "^$key=" "$INI"; then
              sed -i "s|^$key=.*|$escline|" "$INI"
            else
              sed -i "/^\[Application\]/a $escline" "$INI"
            fi
          }
          if [ ! -f "$INI" ]; then
            echo "seeding fresh $INI"
            {
              printf '%s\n' '[Application]'
              # Bound /config/qBittorrent/logs: rotate at MaxSizeBytes keeping a
              # bounded backup set; DeleteOld prunes the oldest. The file-tail
              # sidecar ships entries before they roll off.
              printf '%s\n' 'FileLogger\Backup=true'
              printf '%s\n' 'FileLogger\DeleteOld=true'
              printf '%s\n' 'FileLogger\MaxSizeBytes=1048576'
              printf '%s\n' 'FileLogger\Age=1'
              printf '%s\n' 'FileLogger\AgeType=1'
              printf '\n'
              printf '%s\n' '[Preferences]'
              printf '%s\n' 'WebUI\LocalHostAuth=false'
              printf '%s\n' 'WebUI\HostHeaderValidation=false'
            } > "$INI"
          else
            echo "reconciling existing $INI"
            grep -q '^\[Preferences\]' "$INI" || printf '[Preferences]\n' >> "$INI"
            ensure_key 'WebUI\\LocalHostAuth' 'WebUI\LocalHostAuth=false'
            # drop flattened leftovers from the earlier whitelist attempt
            sed -i '/^WebUIAuthSubnetWhitelist/d; /^WebUIHostHeaderValidation/d' "$INI"
            ensure_key 'WebUI\\HostHeaderValidation' 'WebUI\HostHeaderValidation=false'
            # Bound the file logger (see fresh-seed comment above).
            ensure_app_key 'FileLogger\\Backup' 'FileLogger\Backup=true'
            ensure_app_key 'FileLogger\\DeleteOld' 'FileLogger\DeleteOld=true'
            ensure_app_key 'FileLogger\\MaxSizeBytes' 'FileLogger\MaxSizeBytes=1048576'
          fi
        '';

        # port-sync sidecar loop: poll gluetun's control server for the ProtonVPN
        # forwarded port and, when it changes, PATCH qBittorrent's listen port via
        # the WebUI API. All on the shared pod loopback (busybox wget). Idempotent:
        # only pushes when the port actually changes. NB: this is a Nix indented
        # string; the `${...}` interpolations are Nix (webuiPort), and busybox shell
        # `$var` refs are escaped as `''${var}` so Nix leaves them for the shell.
        portSyncScript = ''
          set -eu
          GTN=http://127.0.0.1:8000/v1/portforward
          QBT=http://127.0.0.1:${toString webuiPort}
          last=""
          while true; do
            # Compact-JSON assumption: gluetun's control server emits a single-line
            # object like {"port":12345}; this sed grabs the first "port":<digits>. If
            # gluetun ever pretty-prints the response, this extraction must change.
            port="$(wget -qO- "$GTN" 2>/dev/null | sed -n 's/.*"port":\([0-9]*\).*/\1/p' || true)"
            if [ -z "''${port:-}" ] || [ "''${port}" = "0" ]; then
              echo "port-sync: no forwarded port from gluetun control server"
            elif [ "''${port}" = "''${last}" ]; then
              : # steady state: port unchanged, nothing to push — stay quiet
            else
              echo "port-sync: setting qBittorrent listen port to ''${port}"
              if wget -qO- --post-data "json={\"listen_port\":''${port}}" \
                  "$QBT/api/v2/app/setPreferences" >/dev/null 2>&1; then
                last="''${port}"
              else
                echo "port-sync: setPreferences failed (qBittorrent not ready?), will retry"
              fi
            fi
            sleep 60
          done
        '';
      in
      {
        applications.qbittorrent = {
          namespace = "media";

          helm.releases.qbittorrent = {
            chart = charts.bjw-s-labs.app-template;
            values = {
              controllers.main = {
                type = "deployment";

                # Drives the cluster DaemonSet's stdout-drop for this pod's main
                # container (the logtail sidecar is the canonical log source).
                pod.labels."den.observability/file-tailed" = "true";

                containers.main = {
                  image = {
                    repository = "lscr.io/linuxserver/qbittorrent";
                    tag = "5.2.1-libtorrentv1";
                  };
                  env = {
                    TZ = "America/Los_Angeles";
                    PUID = "1027";
                    PGID = "65536";
                    # WEBUI_PORT tells the LSIO image which port to serve on.
                    WEBUI_PORT = toString webuiPort;
                    UMASK = "022";
                  };
                  envFrom = [ ];
                };

                # Seed/reconcile qBittorrent.conf before the main container starts.
                # Runs the qBittorrent image so /config ownership stays consistent.
                initContainers.config-seed = {
                  image = {
                    repository = "lscr.io/linuxserver/qbittorrent";
                    tag = "5.2.1-libtorrentv1";
                  };
                  command = [
                    "/bin/sh"
                    "-c"
                    configSeedScript
                  ];
                };

                # gluetun WireGuard native sidecar. A restartPolicy=Always
                # initContainer: k8s starts it BEFORE the main container and keeps it
                # running for the pod's lifetime, and (via the readiness probe below)
                # holds `main` until the tunnel is up. Shares the pod netns with the
                # main container.
                initContainers.gluetun = {
                  image = {
                    repository = "qmcgaw/gluetun";
                    tag = "v3.41.1";
                  };
                  restartPolicy = "Always";
                  securityContext.capabilities.add = [ "NET_ADMIN" ];
                  # Gate `main` on the tunnel: the readiness probe hits gluetun's
                  # health server (HTTP 200 only once the VPN loop is up). The kubelet
                  # dials the POD IP, so the health server must bind beyond loopback
                  # (HEALTH_SERVER_ADDRESS) and the firewall must accept the probe
                  # port on eth0 (FIREWALL_INPUT_PORTS).
                  probes.readiness = {
                    enabled = true;
                    type = "HTTP";
                    path = "/";
                    port = 9999;
                    spec = {
                      initialDelaySeconds = 5;
                      periodSeconds = 10;
                      failureThreshold = 30;
                    };
                  };
                  env = {
                    VPN_SERVICE_PROVIDER = "custom";
                    VPN_TYPE = "wireguard";

                    WIREGUARD_PRIVATE_KEY.valueFrom.secretKeyRef = {
                      name = "media-vpn";
                      key = "private-key";
                    };
                    WIREGUARD_ADDRESSES.valueFrom.secretKeyRef = {
                      name = "media-vpn";
                      key = "addresses";
                    };
                    WIREGUARD_PUBLIC_KEY.valueFrom.secretKeyRef = {
                      name = "media-vpn";
                      key = "peer-public-key";
                    };
                    WIREGUARD_ENDPOINT_IP.valueFrom.secretKeyRef = {
                      name = "media-vpn";
                      key = "endpoint-ip";
                    };
                    WIREGUARD_ENDPOINT_PORT.valueFrom.secretKeyRef = {
                      name = "media-vpn";
                      key = "endpoint-port";
                    };

                    # gluetun firewall: permit egress to the cluster pod/service
                    # CIDRs and the management VLAN so the WebUI ingress (via
                    # gateway), the *arr API callbacks, and in-cluster DNS keep
                    # working through the tunnel's kill-switch. Everything else
                    # non-tunnel is dropped by gluetun.
                    FIREWALL_OUTBOUND_SUBNETS = "172.20.0.0/16,172.21.0.0/16,10.10.10.0/24";

                    # INBOUND (root-caused 2026-06-11): gluetun's INPUT policy is DROP
                    # and its local-subnet auto-detection breaks on Cilium's pod netns
                    # shape (eth0 carries the pod IP as a /32 with the node router as
                    # gateway): it derives "local ipnet" from the GATEWAY /32, so its
                    # only eth0 accept rule never matches traffic to the actual pod IP
                    # — envoy, kubelet probes and the *arrs all hit DROP (connect
                    # timeout). FIREWALL_INPUT_PORTS adds interface-scoped accepts on
                    # the default interface (eth0 only, never tun0 — the VPN side stays
                    # closed except the forwarded port), immune to that detection: 8080
                    # = qbt WebUI (gateway + *arr download clients), 9999 = health
                    # probe (kubelet), 9710 = the qbittorrent-exporter metrics port
                    # (Prometheus dials the pod IP — without this accept gluetun DROPs
                    # the scrape even though the exporter is healthy).
                    FIREWALL_INPUT_PORTS = "8080,9999,9710";
                    # Health server defaults to 127.0.0.1:9999, unreachable for the
                    # kubelet's pod-IP httpGet probe — bind all interfaces instead.
                    HEALTH_SERVER_ADDRESS = ":9999";

                    # Forwarded port is read off gluetun's control server by the
                    # port-sync sidecar (below); no up-command (app-template's tpl
                    # rejects gluetun's {{PORTS}} placeholder).
                    VPN_PORT_FORWARDING = "on";
                    VPN_PORT_FORWARDING_PROVIDER = "protonvpn";
                  };
                };

                # port-sync: pushes the ProtonVPN forwarded port into qBittorrent's
                # prefs. Shares the pod loopback with gluetun (control server :8000)
                # and qbt (WebUI :8080). busybox for wget/sh; no secrets, no mounts.
                containers.port-sync = {
                  image = {
                    repository = "busybox";
                    tag = "1.38.0";
                  };
                  command = [
                    "/bin/sh"
                    "-c"
                    portSyncScript
                  ];
                };

                # Prometheus metrics sidecar (esanchezm qbittorrent-exporter):
                # scrapes qBittorrent's WebUI API over the shared pod loopback and
                # re-exports it on :9710 for kube-prometheus-stack. WebUI
                # LocalHostAuth is disabled (seeded above), so localhost API access
                # needs no credentials — USER/PASS stay empty. Port 9710 deliberately
                # avoids 8000 (gluetun's control server on the same loopback).
                # Reachable from Prometheus only because gluetun's FIREWALL_INPUT_PORTS
                # (below) accepts 9710 on eth0; otherwise gluetun's DROP INPUT policy
                # would silently drop the pod-IP scrape.
                containers.exportarr = {
                  image = {
                    inherit (images."esanchezm/prometheus-qbittorrent-exporter") repository digest;
                  };
                  env = {
                    QBITTORRENT_HOST = "localhost";
                    QBITTORRENT_PORT = toString webuiPort;
                    QBITTORRENT_USER = "";
                    QBITTORRENT_PASS = "";
                    EXPORTER_PORT = "9710";
                  };
                  ports = [
                    {
                      name = "metrics";
                      containerPort = 9710;
                    }
                  ];
                };

                # Log-tail sidecar: tails /config/qBittorrent/logs/qbittorrent.log*
                # off the shared config PVC and ships labeled, level-parsed streams
                # to loki. The grafana/alloy image entrypoint is the alloy binary,
                # so args begin with the `run` subcommand. Runs as PUID 1027 — the
                # qbt log files are mode 0600 owned by 1027, so only that uid can
                # read them and write the offset store. Shares the pod netns with
                # gluetun; the loki push is permitted by gluetun's
                # FIREWALL_OUTBOUND_SUBNETS (172.21.0.0/16).
                containers.logtail = {
                  image = {
                    inherit (images."grafana/alloy") repository digest;
                  };
                  args = [
                    "run"
                    "/etc/alloy/config.alloy"
                    # tail offsets on the config PVC -> survive pod restart
                    "--storage.path=/config/.alloy"
                    # keep the alloy UI loopback-only (no CNP needed)
                    "--server.http.listen-addr=127.0.0.1:12345"
                  ];
                  securityContext = {
                    runAsUser = 1027;
                    runAsGroup = 65536;
                  };
                };
              };

              service.main = {
                controller = "main";
                ports.http.port = webuiPort;
              };

              # Sidecar Alloy River config delivered as a ConfigMap.
              configMaps.logtail.data."config.alloy" = logtailConfig;

              persistence = {
                # Mount the sidecar config into the logtail container only.
                logtail = {
                  type = "configMap";
                  identifier = "logtail";
                  advancedMounts.main.logtail = [
                    {
                      path = "/etc/alloy/config.alloy";
                      subPath = "config.alloy";
                      readOnly = true;
                    }
                  ];
                };
                config = {
                  type = "persistentVolumeClaim";
                  accessMode = "ReadWriteOnce";
                  size = "1Gi";
                  storageClass = "longhorn";
                  labels."recurring-job-group.longhorn.io/media-config" = "enabled";
                  globalMounts = [ { path = "/config"; } ];
                };

                # scratch-local RWO -> /scratch (pins pod to the scratch node,
                # alongside sabnzbd / unpackerr). No /data mount.
                scratch = {
                  type = "persistentVolumeClaim";
                  existingClaim = "media-scratch-local";
                  globalMounts = [ { path = "/scratch"; } ];
                };

                # /dev/net/tun char device, mounted into the gluetun container only.
                tun = {
                  type = "hostPath";
                  hostPath = "/dev/net/tun";
                  hostPathType = "CharDevice";
                  advancedMounts.main.gluetun = [ { path = "/dev/net/tun"; } ];
                };
              };
            };
          };

          # Raw PodMonitor: no typed accessor without a kube-prometheus-stack
          # CRDs bridge, so author it directly (mirrors the *arr aspects). Scrapes
          # the esanchezm exporter sidecar's "metrics" port at /metrics.
          objects = [
            {
              apiVersion = "monitoring.coreos.com/v1";
              kind = "PodMonitor";
              metadata = {
                name = "qbittorrent";
                namespace = "media";
              };
              spec = {
                selector.matchLabels."app.kubernetes.io/name" = "qbittorrent";
                podMetricsEndpoints = [
                  {
                    port = "metrics";
                    path = "/metrics";
                    interval = "30s";
                  }
                ];
              };
            }
          ];

          resources = {
            ciliumNetworkPolicies = {
              # Routed-app baseline: Envoy Gateway proxies (ns "gateways") -> :8080.
              allow-gateway-ingress-qbittorrent.spec = {
                description = "Allow Envoy Gateway proxies to reach qbittorrent.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "qbittorrent";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."k8s:io.kubernetes.pod.namespace" = "gateways"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = toString webuiPort;
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              # Routed-app baseline: kube-dns.
              allow-dns-egress-qbittorrent.spec = {
                description = "Allow qbittorrent to resolve via kube-dns.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "qbittorrent";
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
                      }
                    ];
                  }
                ];
              };

              # The gluetun sidecar's WireGuard handshake/data to the ProtonVPN
              # endpoint. The endpoint IP/port are secret (a CNP can't read them), so
              # we allow the standard ProtonVPN WireGuard port (UDP 51820) to all of
              # world. This is the ONLY world egress for the pod.
              allow-vpn-egress-qbittorrent.spec = {
                description = "Allow the gluetun sidecar to reach the ProtonVPN WireGuard endpoint (UDP 51820).";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "qbittorrent";
                egress = [
                  {
                    toEntities = [ "world" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "51820";
                            protocol = "UDP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              # The in-namespace *arr API callers + unpackerr reach the WebUI on 8080
              # (download-client registration + queue management). The gateway ingress
              # on 8080 is the baseline above; this is the intra-namespace side.
              allow-arr-ingress-qbittorrent.spec = {
                description = "Allow the *arrs and unpackerr to reach qBittorrent's WebUI API (8080).";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "qbittorrent";
                ingress = [
                  {
                    fromEndpoints = [
                      { matchLabels."app.kubernetes.io/name" = "sonarr"; }
                      { matchLabels."app.kubernetes.io/name" = "radarr"; }
                      { matchLabels."app.kubernetes.io/name" = "lidarr"; }
                      { matchLabels."app.kubernetes.io/name" = "whisparr"; }
                      { matchLabels."app.kubernetes.io/name" = "prowlarr"; }
                      { matchLabels."app.kubernetes.io/name" = "unpackerr"; }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = toString webuiPort;
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };

              # Prometheus scrape of the exporter sidecar (9710). The pod is in
              # ingress default-deny (CNPs above), so this allow is required for the
              # scrape to land — gluetun's eth0 firewall accept (9710) is the second,
              # independent gate.
              allow-metrics-ingress-qbittorrent.spec = {
                description = "Allow Prometheus to scrape qbittorrent's exporter sidecar (9710).";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "qbittorrent";
                ingress = [
                  {
                    fromEndpoints = [
                      {
                        matchLabels = {
                          "k8s:io.kubernetes.pod.namespace" = "monitoring";
                          "app.kubernetes.io/name" = "prometheus";
                        };
                      }
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "9710";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ];
              };
            };

            httpRoutes.qbittorrent.spec = {
              hostnames = [ (cluster.domainFor "qbittorrent") ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "qbittorrent"}-https";
                }
              ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "qbittorrent";
                      port = webuiPort;
                    }
                  ];
                }
              ];
            };

            securityPolicies."qbittorrent-oidc".spec = {
              targetRefs = [
                {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = "qbittorrent";
                }
              ];
              oidc = {
                provider.issuer = cluster.secrets.oidcIssuerFor "qbittorrent";
                clientID = "qbittorrent";
                clientSecret.name = "qbittorrent-oidc-client-secret";
                scopes = [
                  "email"
                  "openid"
                  "profile"
                ];
                # qBittorrent 5.x answers 404 to ANY request carrying an
                # Authorization: Bearer header (verified live 2026-06-11), and nothing
                # in qbt consumes the forwarded token — keep it off the upstream.
                forwardAccessToken = false;
              };
            };

            secrets = {
              qbittorrent-oidc-client-secret = {
                type = "Opaque";
                stringData.client-secret = config.age.secrets.qbittorrent-oidc-client-secret.sopsRef;
              };

              # media-vpn k8s Secret (5 keys, each a sops ref); gluetun's env pulls
              # each via valueFrom.secretKeyRef above.
              media-vpn = {
                type = "Opaque";
                stringData = {
                  private-key = config.age.secrets.media-vpn-private-key.sopsRef;
                  addresses = config.age.secrets.media-vpn-addresses.sopsRef;
                  peer-public-key = config.age.secrets.media-vpn-peer-public-key.sopsRef;
                  endpoint-ip = config.age.secrets.media-vpn-endpoint-ip.sopsRef;
                  endpoint-port = config.age.secrets.media-vpn-endpoint-port.sopsRef;
                };
              };
            };
          };
        };
      };
  };
}
