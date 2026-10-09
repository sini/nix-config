# kube-prometheus-stack — Helm chart for in-cluster Prometheus monitoring.
#
# Scopes itself to kubernetes-level signals: apiserver, kubelet/cadvisor,
# coredns, kube-state-metrics, and in-cluster ServiceMonitors/PodMonitors.
# Node-level metrics stay with the host stack (every server already runs
# prometheus-exporter on :9100 — an in-cluster node-exporter would clash
# on the hostPort and duplicate the host stack's ownership).
{
  den.aspects.kubernetes.services.monitoring.prometheus = {
    k8s-manifests =
      {
        charts,
        cluster,
        environment,
        lib,
        prometheus-targets,
        ...
      }:
      let
        # The outside Alertmanager (services.monitoring.alertmanager): it
        # receives only the Watchdog and alerts when that stops arriving.
        outsideAlertmanagers = lib.concatMap (
          t: map (e: "${t.ip}:${toString e.port}") (lib.filter (e: e.job == "alertmanager") t.exporters)
        ) (lib.filter (t: t.environment.name == cluster.environment) prometheus-targets);

        # Hosts that push here (their environment's monitoring.ingest names
        # this cluster) and run a node exporter: the set HostSilent expects.
        expectedHosts = lib.unique (
          map (t: t.hostname) (
            lib.filter (
              t:
              (t.environment.monitoring.ingest or null) == cluster.name
              && lib.any (e: e.job == "node-exporter") t.exporters
            ) prometheus-targets
          )
        );
        nodeUp = instance: ''up{job="node-exporter", instance="${instance}"}'';
      in
      {
        applications.kube-prometheus-stack = {
          namespace = "monitoring";

          # The chart annotates ALL of its dashboards into the Kubernetes
          # folder (grafana.sidecar.dashboards.annotations is global); a few
          # belong elsewhere.
          objectTransforms = [
            {
              name = "dashboard-folder-overrides";
              match.kind = "ConfigMap";
              rewrite =
                cm:
                let
                  folders = {
                    "kube-prometheus-stack-k8s-coredns" = "Networking";
                    "kube-prometheus-stack-alertmanager-overview" = "Monitoring";
                    "kube-prometheus-stack-prometheus" = "Monitoring";
                    "kube-prometheus-stack-grafana-overview" = "Monitoring";
                    "kube-prometheus-stack-nodes" = "Hosts";
                    "kube-prometheus-stack-node-rsrc-use" = "Hosts";
                    "kube-prometheus-stack-node-cluster-rsrc-use" = "Hosts";
                  };
                  folder = folders.${cm.metadata.name} or null;
                in
                if folder == null then
                  cm
                else
                  lib.recursiveUpdate cm { metadata.annotations.grafana_folder = folder; };
            }
          ];

          # The prometheus-operator CRDs blow past the 256KiB annotation
          # limit under client-side apply.
          syncPolicy.syncOptions.serverSideApply = true;

          helm.releases.kube-prometheus-stack = {
            chart = charts.prometheus-community.kube-prometheus-stack;

            values = {
              prometheus = {
                prometheusSpec = {
                  additionalAlertManagerConfigs = lib.optional (outsideAlertmanagers != [ ]) {
                    static_configs = [ { targets = outsideAlertmanagers; } ];
                    alert_relabel_configs = [
                      {
                        source_labels = [ "alertname" ];
                        regex = "Watchdog";
                        action = "keep";
                      }
                    ];
                  };

                  retention = "30d";
                  retentionSize = "10GB";
                  enableRemoteWriteReceiver = true;

                  # Expose the admin TSDB API (--web.enable-admin-api):
                  # /api/v1/admin/tsdb/delete_series + clean_tombstones, so
                  # stale/orphaned series can be force-purged (e.g. churned
                  # pod-IP `instance` series) instead of waiting out retention —
                  # the prometheus analogue of loki's delete API. Prometheus has
                  # no external route; the endpoint is reachable only in-cluster
                  # (kubectl port-forward / monitoring ns). These endpoints are
                  # DESTRUCTIVE — always scope match[] selectors tightly. See
                  # docs/runbooks/monitoring-data-cleanup.md.
                  enableAdminAPI = true;

                  # Pick up ServiceMonitors/PodMonitors/Probes/Rules from any
                  # namespace regardless of release label — CNPG, exportarr,
                  # and other app-owned monitors don't carry the chart's
                  # release label.
                  serviceMonitorSelectorNilUsesHelmValues = false;
                  podMonitorSelectorNilUsesHelmValues = false;
                  probeSelectorNilUsesHelmValues = false;
                  ruleSelectorNilUsesHelmValues = false;

                  storageSpec.volumeClaimTemplate.spec = {
                    storageClassName = "longhorn";
                    accessModes = [ "ReadWriteOnce" ];
                    resources.requests.storage = "50Gi";
                  };
                };
              };

              # The bundled grafana stays off (grafana.nix owns the instance),
              # but its standard dashboard ConfigMaps still render for the
              # sidecar there to pick up.
              # Host monitoring (hosts push through monitoring/ingest.nix).
              # The node-exporter mixin's alerts already select job
              # node-exporter; its Linux dashboards go to Hosts.
              nodeExporter = {
                forceDeployDashboards = true;
                operatingSystems = {
                  aix.enabled = false;
                  darwin.enabled = false;
                };
              };

              additionalPrometheusRulesMap.hosts.groups = [
                {
                  name = "hosts";
                  rules =
                    map (instance: {
                      alert = "HostSilent";
                      expr = "absent_over_time(${nodeUp instance}[5m]) or max_over_time(${nodeUp instance}[5m]) < 1";
                      "for" = "5m";
                      labels = {
                        severity = "critical";
                        inherit instance;
                      };
                      annotations.summary = "${instance} has sent no node metrics for 10m";
                    }) expectedHosts
                    ++ [
                      {
                        alert = "IngestDown";
                        expr = ''absent_over_time(up{job="node-exporter"}[5m])'';
                        "for" = "5m";
                        labels.severity = "critical";
                        annotations.summary = "No host has pushed node metrics for 10m: the ingest path is down";
                      }
                    ];
                }
              ];

              grafana = {
                enabled = false;
                forceDeployDashboards = true;
                sidecar.dashboards.annotations.grafana_folder = "Kubernetes";
              };
              alertmanager = {
                enabled = true;
                # Mail goes through the cluster's Postfix relay to Proton
                # (communication/smtp-relay.nix), which accepts in-cluster
                # senders from the environment's domain without auth.
                # Replaces the chart's default config, so its inhibit rules
                # are restated here.
                config = {
                  global = {
                    resolve_timeout = "5m";
                    smtp_smarthost = "smtp.${environment.email.domain}:587";
                    smtp_from = "alertmanager@${environment.email.domain}";
                    smtp_require_tls = true;
                  };
                  route = {
                    receiver = "email";
                    group_by = [
                      "namespace"
                      "alertname"
                    ];
                    group_wait = "30s";
                    group_interval = "5m";
                    repeat_interval = "12h";
                    routes = [
                      # Always firing by design: proves the pipeline is alive,
                      # never a page.
                      {
                        receiver = "null";
                        matchers = [ ''alertname = "Watchdog"'' ];
                      }
                      {
                        receiver = "null";
                        matchers = [ ''alertname = "InfoInhibitor"'' ];
                      }
                      # Informational alerts stay visible in Alertmanager only.
                      {
                        receiver = "null";
                        matchers = [ ''severity = "info"'' ];
                      }
                    ];
                  };
                  inhibit_rules = [
                    {
                      source_matchers = [ "severity = critical" ];
                      target_matchers = [ "severity =~ warning|info" ];
                      equal = [
                        "namespace"
                        "alertname"
                        "instance"
                      ];
                    }
                    {
                      source_matchers = [ "severity = warning" ];
                      target_matchers = [ "severity = info" ];
                      equal = [
                        "namespace"
                        "alertname"
                        "instance"
                      ];
                    }
                    {
                      source_matchers = [ "alertname = InfoInhibitor" ];
                      target_matchers = [ "severity = info" ];
                      equal = [
                        "namespace"
                        "instance"
                      ];
                    }
                    { target_matchers = [ "alertname = InfoInhibitor" ]; }
                    # Nothing reaches the cluster: every host looks silent.
                    {
                      source_matchers = [ "alertname = IngestDown" ];
                      target_matchers = [ "alertname = HostSilent" ];
                    }
                  ];
                  receivers = [
                    { name = "null"; }
                    {
                      name = "email";
                      email_configs = [
                        {
                          to = environment.email.adminEmail;
                          send_resolved = true;
                        }
                      ];
                    }
                  ];
                  templates = [ "/etc/alertmanager/config/*.tmpl" ];
                };
              };

              # Admission webhook certs via cert-manager instead of the
              # certgen hook jobs: PreSync hooks run before any of the app's
              # resources (including its network policies) are applied, so
              # the job can never reach the apiserver under the cluster's
              # default-deny egress.
              prometheusOperator.admissionWebhooks.certManager.enabled = true;

              # Node metrics are host-stack-owned (see header).
              nodeExporter.enabled = false;
              kubeStateMetrics.enabled = true;

              # k3s embeds the control-plane components in the k3s process;
              # there are no separate endpoints for these to scrape.
              kubeControllerManager.enabled = false;
              kubeScheduler.enabled = false;
              kubeProxy.enabled = false;
              kubeEtcd.enabled = false;

              # The chart's coredns Service selects k8s-app=kube-dns; our
              # coredns chart labels its pods k8s-app=coredns, so the default
              # selector matches nothing and the coredns dashboards read empty.
              coreDns.service.selector."k8s-app" = "coredns";
            };
          };

          # PodMonitors for workloads whose charts ship no monitor of their
          # own (gateway-helm has none). They live here in monitoring and
          # select across namespaces; raw objects because there is no typed
          # accessor without a kube-prometheus-stack crds bridge (planned
          # alongside PrometheusRule authoring for alerting).
          objects = [
            {
              apiVersion = "monitoring.coreos.com/v1";
              kind = "PodMonitor";
              metadata = {
                name = "envoy-gateway";
                namespace = "monitoring";
              };
              spec = {
                namespaceSelector.matchNames = [ "envoy-gateway-system" ];
                selector.matchLabels."control-plane" = "envoy-gateway";
                podMetricsEndpoints = [ { port = "metrics"; } ];
              };
            }
            {
              apiVersion = "monitoring.coreos.com/v1";
              kind = "PodMonitor";
              metadata = {
                name = "envoy-proxies";
                namespace = "monitoring";
              };
              spec = {
                namespaceSelector.matchNames = [ "gateways" ];
                selector.matchLabels."app.kubernetes.io/component" = "proxy";
                # Envoy serves prometheus on the admin-style stats path, not
                # /metrics (the controller does use /metrics).
                podMetricsEndpoints = [
                  {
                    port = "metrics";
                    path = "/stats/prometheus";
                  }
                ];
              };
            }
          ];

          # The cluster default-denies egress to anything that isn't a
          # cilium-managed endpoint; the apiserver and kubelets are
          # host-network and need explicit entity rules.
          resources.ciliumNetworkPolicies = {
            allow-operator-kube-apiserver-egress = {
              spec = {
                endpointSelector.matchLabels.app = "kube-prometheus-stack-operator";
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

            allow-prometheus-scrape-egress = {
              spec = {
                endpointSelector.matchLabels."app.kubernetes.io/name" = "prometheus";
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
                  # Host-network scrape targets on every node: kubelet
                  # (10250), cilium agent (9962), cilium operator (9963),
                  # hubble metrics (9965).
                  {
                    toEntities = [
                      "host"
                      "remote-node"
                    ];
                    toPorts = [
                      {
                        ports = [
                          {
                            port = "10250";
                            protocol = "TCP";
                          }
                          {
                            port = "9962";
                            protocol = "TCP";
                          }
                          {
                            port = "9963";
                            protocol = "TCP";
                          }
                          {
                            port = "9965";
                            protocol = "TCP";
                          }
                        ];
                      }
                    ];
                  }
                ]
                # The Watchdog push to the outside Alertmanager.
                ++ map (target: {
                  toCIDR = [ "${lib.head (lib.splitString ":" target)}/32" ];
                  toPorts = [
                    {
                      ports = [
                        {
                          port = lib.last (lib.splitString ":" target);
                          protocol = "TCP";
                        }
                      ];
                    }
                  ];
                }) outsideAlertmanagers;
              };
            };

            allow-kube-state-metrics-kube-apiserver-egress = {
              spec = {
                endpointSelector.matchLabels."app.kubernetes.io/name" = "kube-state-metrics";
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
          };
        };
      };
  };
}
