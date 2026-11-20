# The always-on Syncthing hub in the cluster (docs/syncthing-hub-to-k8s.md), taking
# over from uplink's (core/network/syncthing/hub.nix). One replica on a Longhorn
# volume backs up every replicating user's dirs under /var/syncthing/data/<user>/,
# with the same devices, folders and versioning as uplink's (core.network.syncthing.hub.settings.mesh).
#
# It keeps uplink's hub identity (syncthing-uplink: the committed .crt and .id, and
# the key, shared with uplink's host secret), so members see a known device at a
# new address and nothing re-pairs. Owner's decisions (2026-11-19): it starts empty
# and pulls from the members, and it is LAN-only: a LoadBalancer address
# (BGP-advertised, not internet-routable) on 22000/tcp. Off-LAN members sync with
# each other over the tailnet meanwhile.
#
# nix owns the config: an init container writes config.xml on every start, so
# devices and folders track the mesh (hub.nix's overrideDevices/overrideFolders).
#
# `live` gates the cutover: off, the volume and config exist with no replica, and
# the members keep uplink as their hub.
{ lib, rootPath, ... }:
let
  name = "syncthing-hub";
  namespace = "syncthing";
  port = 22000;
  uid = 1000;
  home = "/var/syncthing";
  dataDir = "${home}/data";
  configDir = "${home}/config";
  pod."app.kubernetes.io/name" = name;
  ref = image: "${image.repository}@${image.digest}";
  # uplink's hub identity, kept so the device id doesn't change.
  identity = rootPath + "/.secrets/hosts/uplink/syncthing-uplink";
  deviceId = builtins.readFile (identity + ".id");

  esc = lib.escapeXML;
  versioningXml =
    v:
    ''<versioning type="${esc v.type}">''
    + lib.concatStrings (
      lib.mapAttrsToList (k: val: ''<param key="${esc k}" val="${esc val}"></param>'') v.params
    )
    + "</versioning>";
  configXml =
    { devices, folders }:
    lib.concatStrings (
      [ ''<configuration version="52">'' ]
      ++ lib.mapAttrsToList (
        _: f:
        ''<folder id="${esc f.id}" label="${esc f.label}" path="${esc f.path}" type="sendreceive" fsWatcherEnabled="true">''
        + lib.concatMapStrings (d: ''<device id="${esc devices.${d}.id}"></device>'') f.devices
        + versioningXml f.versioning
        + "</folder>"
      ) folders
      ++ lib.mapAttrsToList (
        n: d:
        ''<device id="${esc d.id}" name="${esc n}" compression="metadata" introducer="false">''
        + lib.concatMapStrings (a: "<address>${esc a}</address>") d.addresses
        + "</device>"
      ) devices
      ++ [
        ''<gui enabled="true" tls="false"><address>127.0.0.1:8384</address></gui>''
        "<options>"
        "<listenAddress>tcp://0.0.0.0:${toString port}</listenAddress>"
        "<globalAnnounceEnabled>false</globalAnnounceEnabled>"
        "<localAnnounceEnabled>false</localAnnounceEnabled>"
        "<relaysEnabled>false</relaysEnabled>"
        "<natEnabled>false</natEnabled>"
        "<urAccepted>-1</urAccepted>"
        "<crashReportingEnabled>false</crashReportingEnabled>"
        "<autoUpgradeIntervalH>0</autoUpgradeIntervalH>"
        "<startBrowser>false</startBrowser>"
        "</options>"
        "</configuration>"
      ]
    );
in
{
  den.aspects.kubernetes.services.network.syncthing-hub = {
    settings.live = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Run the hub and advertise it to the members in place of uplink's.";
    };

    # The hub's own device record, broadcast to every replicating user
    # (cluster-broadcast-syncthing-hub-peer), as uplink's was.
    syncthing-peers =
      { cluster, ... }:
      lib.optional cluster.settings.kubernetes.services.network.syncthing-hub.live {
        hostname = name;
        inherit deviceId;
        addresses = [ "tcp://${cluster.getAssignment name}:${toString port}" ];
        isHub = true;
      };

    age-secrets =
      { ... }:
      {
        # uplink's hub key: the same rekeyFile and generator as its host secret.
        age.secrets.syncthing-hub-key = {
          rekeyFile = identity + ".age";
          generator.script = "syncthing-identity";
          sopsOutput = {
            file = "syncthing-hub";
            key = "key.pem";
          };
        };
      };

    k8s-manifests =
      {
        config,
        cluster,
        images,
        syncthing-peers,
        replicateHome,
        ...
      }:
      let
        live = cluster.settings.kubernetes.services.network.syncthing-hub.live;
        xml = configXml (
          cluster.settings.core.network.syncthing.hub.mesh {
            inherit syncthing-peers replicateHome dataDir;
            self = name;
          }
        );
        hardened = {
          runAsUser = uid;
          runAsGroup = uid;
          runAsNonRoot = true;
          readOnlyRootFilesystem = true;
          allowPrivilegeEscalation = false;
          capabilities.drop = [ "ALL" ];
        };
        tcp = p: {
          port = toString p;
          protocol = "TCP";
        };
      in
      {
        applications.${name} = {
          inherit namespace;

          resources = {
            serviceAccounts.${name}.automountServiceAccountToken = false;

            configMaps."${name}-config".data = {
              "config.xml" = xml;
              "cert.pem" = builtins.readFile (identity + ".crt");
            };

            secrets."${name}-key".stringData."key.pem" = config.age.secrets.syncthing-hub-key.sopsRef;

            # The folders, their .stversions and the index. In Longhorn's nightly
            # off-cluster backup group.
            persistentVolumeClaims.${name} = {
              metadata.labels."recurring-job-group.longhorn.io/media-config" = "enabled";
              spec = {
                accessModes = [ "ReadWriteOnce" ];
                storageClassName = "longhorn";
                resources.requests.storage = "20Gi";
              };
            };

            deployments.${name}.spec = {
              replicas = if live then 1 else 0;
              # One writer on a ReadWriteOnce volume.
              strategy.type = "Recreate";
              selector.matchLabels = pod;
              template = {
                metadata.labels = pod;
                metadata.annotations."json64.dev/config-hash" = builtins.hashString "sha256" xml;
                spec = {
                  serviceAccountName = name;
                  automountServiceAccountToken = false;
                  enableServiceLinks = false;
                  securityContext = {
                    runAsUser = uid;
                    runAsGroup = uid;
                    runAsNonRoot = true;
                    fsGroup = uid;
                    fsGroupChangePolicy = "OnRootMismatch";
                    seccompProfile.type = "RuntimeDefault";
                  };
                  # nix's config, identity and key into the writable home on every
                  # start (Syncthing rewrites config.xml as it runs).
                  initContainers = [
                    {
                      name = "config";
                      image = ref images."syncthing/syncthing";
                      command = [
                        "/bin/sh"
                        "-c"
                        ''
                          set -eu
                          mkdir -p ${configDir} ${dataDir}
                          cp /nix-config/config.xml /nix-config/cert.pem ${configDir}/
                          cp /nix-key/key.pem ${configDir}/key.pem
                          chmod 0600 ${configDir}/key.pem
                        ''
                      ];
                      securityContext = hardened;
                      volumeMounts = [
                        {
                          name = "data";
                          mountPath = home;
                        }
                        {
                          name = "config";
                          mountPath = "/nix-config";
                          readOnly = true;
                        }
                        {
                          name = "key";
                          mountPath = "/nix-key";
                          readOnly = true;
                        }
                      ];
                    }
                  ];
                  containers = [
                    {
                      name = "syncthing";
                      image = ref images."syncthing/syncthing";
                      command = [
                        "/bin/syncthing"
                        "serve"
                        # The image's environment sets 0.0.0.0:8384; the GUI is unused.
                        "--gui-address=127.0.0.1:8384"
                        "--home=${configDir}"
                        "--no-browser"
                        "--no-upgrade"
                      ];
                      env = [
                        {
                          name = "STNOUPGRADE";
                          value = "1";
                        }
                      ];
                      securityContext = hardened;
                      ports = [
                        {
                          name = "sync";
                          containerPort = port;
                        }
                      ];
                      readinessProbe = {
                        tcpSocket.port = "sync";
                        periodSeconds = 10;
                      };
                      livenessProbe = {
                        tcpSocket.port = "sync";
                        initialDelaySeconds = 30;
                        periodSeconds = 30;
                        failureThreshold = 4;
                      };
                      resources.requests = {
                        cpu = "50m";
                        memory = "128Mi";
                      };
                      volumeMounts = [
                        {
                          name = "data";
                          mountPath = home;
                        }
                        {
                          name = "tmp";
                          mountPath = "/tmp";
                        }
                      ];
                    }
                  ];
                  volumes = [
                    {
                      name = "data";
                      persistentVolumeClaim.claimName = name;
                    }
                    {
                      name = "config";
                      configMap.name = "${name}-config";
                    }
                    {
                      name = "key";
                      secret = {
                        secretName = "${name}-key";
                        defaultMode = 288;
                      };
                    }
                    {
                      name = "tmp";
                      emptyDir = { };
                    }
                  ];
                };
              };
            };

            services.${name} = {
              metadata.annotations."lbipam.cilium.io/ips" = cluster.getAssignment name;
              spec = {
                type = "LoadBalancer";
                # Keeps the client's address, which the ingress rule matches. With
                # Cluster, a connection reaching another node arrives SNATed to that
                # node's pod-range address and Cilium sees it as world.
                externalTrafficPolicy = "Local";
                selector = pod;
                ports = [
                  {
                    name = "sync";
                    inherit port;
                    targetPort = "sync";
                    protocol = "TCP";
                  }
                ];
              };
            };

            ciliumNetworkPolicies = {
              "allow-${name}-ingress".spec = {
                description = "syncthing-hub: sync from the LAN and the tailnet on ${toString port}.";
                endpointSelector.matchLabels = pod;
                ingress = [
                  {
                    fromCIDR = [
                      "10.0.0.0/8"
                      "100.64.0.0/10"
                    ];
                    toPorts = [ { ports = [ (tcp port) ]; } ];
                  }
                ];
              };
              # Dials the members on their per-user sync ports.
              "allow-${name}-egress".spec = {
                description = "syncthing-hub: the members' sync ports on the LAN.";
                endpointSelector.matchLabels = pod;
                egress = [
                  {
                    toCIDR = [ "10.0.0.0/8" ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = toString port;
                            endPort = port + 99;
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
  };
}
