# qBittorrent — BitTorrent client routed through a Gluetun WireGuard sidecar.
#
# Routed + OIDC-protected UI on torrent.json64.dev (prod.nix declares
# services.qbittorrent.domain; the helper reads it via getDomainFor
# "qbittorrent"). The OIDC clientID stays "qbittorrent".
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
# 2. BELT+SUSPENDERS: CiliumNetworkPolicies on the pod. We do NOT enable the
#    helper's internetEgress (no world 80/443). Instead extraCnps allow only:
#      - world UDP 51820 (the WireGuard handshake/data to the ProtonVPN endpoint;
#        the endpoint IP/port live in a secret a CNP can't read, so we allow the
#        standard ProtonVPN WG port to all of `world`);
#      - intra-namespace ingress on 8080 from the *arr API callers + unpackerr.
#    DNS + gateway-ingress come from the helper baseline. Cilium policies are
#    additive (union of allows), so the baseline DNS/gateway-ingress and these
#    extras compose. No TCP world-egress policy exists, so even if gluetun's
#    firewall were misconfigured, Cilium denies cleartext TCP to the internet.
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
# 127.0.0.1:8000/v1/openvpn/portforwarded. We do NOT use gluetun's
# VPN_PORT_FORWARDING_UP_COMMAND: app-template runs every container env value
# through Helm's `tpl`, which chokes on gluetun's {{PORTS}} placeholder
# ("function PORTS not defined") — escaping it through two template layers is
# fragile. Instead a tiny third container `port-sync` (busybox, polling the
# shared loopback) reads the forwarded port from the gluetun control server every
# 60s and, when it changes, PATCHes qBittorrent's listen port via the WebUI API.
# This mirrors the old compose's gsp DOCKER_MOD (which polled gluetun:8000). The
# WebUI call is unauthenticated because qBittorrent's AuthSubnetWhitelist trusts
# 127.0.0.1/32 (seeded below) and all three containers share the pod loopback.
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
# a recent libtorrent-v1-line LSIO tag (5.1.2-libtorrentv1). Gluetun pinned to
# v3.40.0. Bump both in the deploy-time pass.
{
  config,
  lib,
  ...
}:
let
  media-app = import ./_media-app.nix { inherit lib; };

  webuiPort = 8080;

  # WireGuard material: one externally-provided (generator-less) age secret per
  # field, all rekeyed into a single cluster sops file `media-vpn`.
  vpnSecretName = "media-vpn";
  vpnFields = {
    # age-secret name suffix -> { sopsKey; }
    "private-key" = { };
    "addresses" = { };
    "peer-public-key" = { };
    "endpoint-ip" = { };
    "endpoint-port" = { };
  };
  vpnAgeName = field: "${vpnSecretName}-${field}";

  # gluetun env reading a media-vpn Secret key.
  vpnEnv = key: {
    valueFrom.secretKeyRef = {
      name = vpnSecretName;
      inherit key;
    };
  };

  # qBittorrent.conf seeder. Idempotent:
  #   fresh /config -> write a minimal [Preferences] section
  #   existing      -> reconcile the auth-whitelist + host-header keys
  # [Preferences] keys touched:
  #   WebUI\AuthSubnetWhitelist         127.0.0.1/32 (trust pod loopback)
  #   WebUI\AuthSubnetWhitelistEnabled  true  (lets the port-sync sidecar hit the
  #                                            API unauthenticated from localhost)
  #   WebUI\HostHeaderValidation        false (accept the gateway's proxied Host)
  # printf (not a heredoc) to survive Nix indented-string dedenting.
  configSeedScript = ''
    set -eu
    INI=/config/qBittorrent/qBittorrent.conf
    mkdir -p /config/qBittorrent
    ensure_key() {
      # ensure_key <key-escaped-for-sed> <full-line>
      key="$1"; line="$2"
      if grep -q "^$key=" "$INI"; then
        sed -i "s|^$key=.*|$line|" "$INI"
      else
        sed -i "/^\[Preferences\]/a $line" "$INI"
      fi
    }
    if [ ! -f "$INI" ]; then
      echo "seeding fresh $INI"
      {
        printf '%s\n' '[Preferences]'
        printf '%s\n' 'WebUI\AuthSubnetWhitelist=127.0.0.1/32'
        printf '%s\n' 'WebUI\AuthSubnetWhitelistEnabled=true'
        printf '%s\n' 'WebUI\HostHeaderValidation=false'
      } > "$INI"
    else
      echo "reconciling existing $INI"
      grep -q '^\[Preferences\]' "$INI" || printf '[Preferences]\n' >> "$INI"
      ensure_key 'WebUI\\AuthSubnetWhitelist' 'WebUI\AuthSubnetWhitelist=127.0.0.1/32'
      ensure_key 'WebUI\\AuthSubnetWhitelistEnabled' 'WebUI\AuthSubnetWhitelistEnabled=true'
      ensure_key 'WebUI\\HostHeaderValidation' 'WebUI\HostHeaderValidation=false'
    fi
  '';

  # port-sync sidecar loop: poll gluetun's control server for the ProtonVPN
  # forwarded port and, when it changes, PATCH qBittorrent's listen port via the
  # WebUI API. All on the shared pod loopback (busybox wget). Idempotent: only
  # pushes when the port actually changes. NB: this is a Nix indented string; the
  # `${...}` interpolations are Nix (webuiPort), and busybox shell `$var` refs are
  # escaped as `''${var}` so Nix leaves them for the shell.
  portSyncScript = ''
    set -eu
    GTN=http://127.0.0.1:8000/v1/openvpn/portforwarded
    QBT=http://127.0.0.1:${toString webuiPort}
    last=""
    while true; do
      # Compact-JSON assumption: gluetun's control server emits a single-line
      # object like {"port":12345}; this sed grabs the first "port":<digits>. If
      # gluetun ever pretty-prints the response, this extraction must change.
      port="$(wget -qO- "$GTN" 2>/dev/null | sed -n 's/.*"port":\([0-9]*\).*/\1/p' || true)"
      if [ -n "''${port:-}" ] && [ "''${port}" != "0" ] && [ "''${port}" != "''${last}" ]; then
        echo "port-sync: setting qBittorrent listen port to ''${port}"
        if wget -qO- --post-data "json={\"listen_port\":''${port}}" \
            "$QBT/api/v2/app/setPreferences" >/dev/null 2>&1; then
          last="''${port}"
        else
          echo "port-sync: setPreferences failed (qBittorrent not ready?), will retry"
        fi
      else
        echo "port-sync: no forwarded port from gluetun control server"
      fi
      sleep 60
    done
  '';

  # Egress edge to a single in-namespace service port (used for arr-ingress).
  fromArr = svc: {
    matchLabels."app.kubernetes.io/name" = svc;
  };

  app = media-app.mkMediaApp {
    name = "qbittorrent";
    port = webuiPort;
    image = {
      repository = "lscr.io/linuxserver/qbittorrent";
      tag = "5.1.2-libtorrentv1";
    };
    inherit (config.den) environments;

    # qBittorrent stores nothing in postgres.
    postgres = false;

    config-size = "1Gi";

    # scratch-local RWO -> /scratch (pins pod to the scratch node, alongside
    # sabnzbd / unpackerr on axon-01). No /data mount.
    mounts = {
      scratch-local = true;
    };

    # Main-container env. WEBUI_PORT tells the LSIO image which port to serve on.
    env = {
      WEBUI_PORT = toString webuiPort;
      UMASK = "022";
    };

    # NO world TCP egress: qBittorrent must only reach the internet through the
    # gluetun tunnel. The VPN handshake + intra-ns ingress are added via extraCnps
    # below. gluetun's firewall is the primary kill-switch; these CNPs are the
    # belt-and-suspenders cleartext-leak guard.
    internetEgress = false;

    extraCnps = {
      # Allow the gluetun sidecar's WireGuard handshake/data to the ProtonVPN
      # endpoint. The endpoint IP/port are secret (a CNP can't read them), so we
      # allow the standard ProtonVPN WireGuard port (UDP 51820) to all of world.
      # This is the ONLY world egress for the pod.
      "allow-vpn-egress-qbittorrent".spec = {
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

      # Allow the in-namespace *arr API callers + unpackerr to reach the WebUI on
      # 8080 (download-client registration + queue management). The gateway
      # ingress on 8080 is already covered by the helper baseline.
      "allow-arr-ingress-qbittorrent".spec = {
        description = "Allow the *arrs and unpackerr to reach qBittorrent's WebUI API (8080).";
        endpointSelector.matchLabels."app.kubernetes.io/name" = "qbittorrent";
        ingress = [
          {
            fromEndpoints = [
              (fromArr "sonarr")
              (fromArr "radarr")
              (fromArr "lidarr")
              (fromArr "whisparr")
              (fromArr "prowlarr")
              (fromArr "unpackerr")
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
    };

    extraValues = {
      controllers.main = {
        # Seed/reconcile qBittorrent.conf before the main container starts. Runs
        # the qBittorrent image so /config ownership stays consistent.
        initContainers.config-seed = {
          image = {
            repository = "lscr.io/linuxserver/qbittorrent";
            tag = "5.1.2-libtorrentv1";
          };
          command = [
            "/bin/sh"
            "-c"
            configSeedScript
          ];
        };

        # gluetun WireGuard native sidecar. A restartPolicy=Always initContainer:
        # k8s starts it BEFORE the main container and keeps it running for the pod's
        # lifetime, and (via the readiness probe below) holds `main` until the
        # tunnel is up. Lives under initContainers (not containers) so it sequences
        # ahead of qBittorrent — its only egress path. Shares the pod netns with
        # the main container. app-template v5 renders restartPolicy + probes on
        # initContainers through the same container spec template as regular
        # containers (verified against the vendored chart).
        initContainers.gluetun = {
          image = {
            repository = "qmcgaw/gluetun";
            tag = "v3.40.0";
          };
          # Native sidecar: never terminates, runs alongside main.
          restartPolicy = "Always";
          securityContext.capabilities.add = [ "NET_ADMIN" ];
          # Gate `main` on the tunnel: the readiness probe hits gluetun's control
          # server status endpoint (HTTP 200 once the VPN loop is up). As a native
          # sidecar, the kubelet won't start `main` until this probe passes.
          probes.readiness = {
            enabled = true;
            type = "HTTP";
            path = "/v1/openvpn/status";
            port = 8000;
            spec = {
              initialDelaySeconds = 5;
              periodSeconds = 10;
              failureThreshold = 30;
            };
          };
          env = {
            VPN_SERVICE_PROVIDER = "custom";
            VPN_TYPE = "wireguard";

            WIREGUARD_PRIVATE_KEY = vpnEnv "private-key";
            WIREGUARD_ADDRESSES = vpnEnv "addresses";
            WIREGUARD_PUBLIC_KEY = vpnEnv "peer-public-key";
            WIREGUARD_ENDPOINT_IP = vpnEnv "endpoint-ip";
            WIREGUARD_ENDPOINT_PORT = vpnEnv "endpoint-port";

            # gluetun firewall: permit egress to the cluster pod/service CIDRs and
            # the management VLAN so the WebUI ingress (via gateway), the *arr API
            # callbacks, and in-cluster DNS keep working through the tunnel's
            # kill-switch. Everything else non-tunnel is dropped by gluetun.
            FIREWALL_OUTBOUND_SUBNETS = "172.20.0.0/16,172.21.0.0/16,10.10.10.0/24";

            # Forwarded port is read off gluetun's control server by the
            # port-sync sidecar (see below); no up-command (app-template's tpl
            # rejects gluetun's {{PORTS}} placeholder).
            VPN_PORT_FORWARDING = "on";
            VPN_PORT_FORWARDING_PROVIDER = "protonvpn";
          };
        };

        # port-sync: pushes the ProtonVPN forwarded port into qBittorrent's prefs.
        # Shares the pod loopback with gluetun (control server :8000) and qbt
        # (WebUI :8080). busybox image for wget/sh; no secrets, no mounts.
        containers.port-sync = {
          image = {
            repository = "busybox";
            tag = "1.37.0";
          };
          command = [
            "/bin/sh"
            "-c"
            portSyncScript
          ];
        };
      };

      # /dev/net/tun char device, mounted into the gluetun container only.
      persistence.tun = {
        type = "hostPath";
        hostPath = "/dev/net/tun";
        hostPathType = "CharDevice";
        advancedMounts.main.gluetun = [ { path = "/dev/net/tun"; } ];
      };
    };
  };
in
{
  den.aspects.kubernetes.services.media.qbittorrent = app // {
    # Post-merge the externally-provided WireGuard age secrets onto the helper's
    # OIDC age-secrets. No generator: the operator fills these via `agenix edit`.
    age-secrets =
      args@{ cluster, ... }:
      let
        environment = config.den.environments.${cluster.environment};
        vpnSecrets = lib.mapAttrs' (
          field: _:
          lib.nameValuePair (vpnAgeName field) {
            rekeyFile = environment.secretPath + "/media-vpn/${field}.age";
            sopsOutput = {
              file = vpnSecretName;
              key = field;
            };
          }
        ) vpnFields;
      in
      # recursiveUpdate so the helper's OIDC age.secrets entry is preserved
      # alongside the VPN entries (plain // would clobber the whole age.secrets).
      lib.recursiveUpdate (app.age-secrets args) {
        age.secrets = vpnSecrets;
      };

    # Post-merge the media-vpn k8s Secret (5 keys, each a sops ref) onto the
    # helper's application manifests. The formals here must cover everything the
    # helper's k8s-manifests needs (config, cluster, charts) — the module system
    # only passes the args this function declares, and we forward them verbatim.
    k8s-manifests =
      args@{
        config,
        cluster,
        charts,
        ...
      }:
      lib.recursiveUpdate (app.k8s-manifests args) {
        applications.qbittorrent.resources.secrets.${vpnSecretName} = {
          type = "Opaque";
          stringData = lib.mapAttrs' (
            field: _: lib.nameValuePair field config.age.secrets.${vpnAgeName field}.sopsRef
          ) vpnFields;
        };
      };
  };
}
