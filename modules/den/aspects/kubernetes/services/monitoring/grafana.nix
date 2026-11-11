# Grafana — Helm chart for in-cluster dashboards.
#
# Routed through the default gateway; auth is grafana-native OIDC against
# kanidm (client grafana), mapping kanidm groups to Grafana roles. Dashboards are
# provisioned by the sidecar from ConfigMaps labeled grafana_dashboard;
# kube-prometheus-stack force-deploys its standard dashboard set even
# with its bundled grafana disabled (see prometheus.nix).
{
  den.aspects.kubernetes.services.monitoring.grafana = {
    # The fleet's Grafana, at grafana.<domain> (DNS record + gateway listener).
    served-domains = { cluster, ... }: cluster.servedDomains [ "grafana" ];

    k8s-manifests =
      {
        config,
        cluster,
        charts,
        lib,
        pkgs,
        ...
      }:
      let
        domain = cluster.domainFor "grafana";
        kanidmDomain = cluster.domainFor "kanidm";

        # Canonical upstream dashboards that no deployed chart bundles,
        # pinned and transformed at BUILD time (no runtime downloads): title
        # normalized, grafana.com `__inputs` datasource placeholders bound to
        # the Prometheus datasource. Rendered below as sidecar ConfigMaps
        # with a grafana_folder annotation.
        mkDashboardJson =
          {
            name,
            title,
            url,
            sha256,
            fixDatasource ? false,
            # Filter colon-form (pod-IP:port) values out of any `*instance*`
            # template variable. Our media exporters relabel `instance` to a
            # stable app-name, but deleted pre-relabel pod-IP series linger in
            # the prometheus index until head compaction, so `label_values`
            # still offers them → duplicate repeated panels. Drop them at the
            # variable. Only for dashboards whose instance IS app-name (NOT
            # node-exporter dashboards where instance is legitimately host:port).
            excludeColonInstances ? false,
            # A jq program applied last, for local corrections to an upstream dashboard.
            jqFilter ? null,
          }:
          builtins.readFile (
            pkgs.runCommand "grafana-dashboard-${name}"
              {
                src = pkgs.fetchurl { inherit url sha256; };
                nativeBuildInputs = [
                  pkgs.jq
                  pkgs.gnused
                ];
              }
              ''
                ${
                  if fixDatasource then
                    # Bind the grafana.com datasource input to ours. The
                    # legacy line sed rewrites bare-string datasource refs
                    # ("datasource": "$datasource" | "''${DS_X}" | null) to
                    # the "Prometheus" name. Newer dashboards instead use the
                    # object form ({"type":"prometheus","uid":"''${DS_X}"})
                    # split across lines, which that sed misses, so a first
                    # pass substitutes any ''${DS_*} input placeholder with
                    # the pinned datasource uid (a no-op for dashboards that
                    # use a different placeholder, which the line sed then
                    # catches by the string rule).
                    ''sed -E 's/\$\{DS_[A-Z0-9_]+\}/prometheus/g' "$src" | sed '/-- .* --/! s/"datasource":.*,/"datasource": "Prometheus",/g' ''
                  else
                    ''cat "$src"''
                } | jq '.title = "${title}"'${lib.optionalString excludeColonInstances " | jq '(.templating.list) |= map(if ((.name // \"\") | test(\"instance\")) then . + {regex:\"/^[^:]+$/\"} else . end)'"}${
                  lib.optionalString (
                    jqFilter != null
                  ) " | jq -f ${pkgs.writeText "grafana-dashboard-${name}.jq" jqFilter}"
                } > "$out"
              ''
          );

        envoyDashboardUrl =
          name:
          "https://raw.githubusercontent.com/envoyproxy/gateway/v1.8.1/charts/gateway-addons-helm/dashboards/${name}.json";

        # Log-browsing dashboards authored here (community ones key off a
        # job-based label schema; ours is namespace/pod/container). Stable
        # uids give stable URLs; the loki datasource uid is pinned above.
        lokiDs = {
          type = "loki";
          uid = "loki";
        };

        mkLabelVar = name: query: {
          inherit name;
          type = "query";
          datasource = lokiDs;
          inherit query;
          refresh = 2;
          includeAll = true;
          multi = true;
          allValue = ".+";
          current = {
            selected = true;
            text = [ "All" ];
            value = [ "$__all" ];
          };
        };

        searchVar = {
          name = "search";
          type = "textbox";
          label = "search";
          current = {
            text = "";
            value = "";
          };
        };

        mkLogsDashboard =
          {
            uid,
            title,
            variables,
            selector,
            volumeBy,
          }:
          {
            inherit uid title;
            schemaVersion = 39;
            version = 1;
            editable = true;
            time = {
              from = "now-1h";
              to = "now";
            };
            templating.list = variables ++ [ searchVar ];
            panels = [
              {
                title = "Log volume";
                type = "timeseries";
                datasource = lokiDs;
                gridPos = {
                  h = 6;
                  w = 24;
                  x = 0;
                  y = 0;
                };
                options.legend.displayMode = "list";
                fieldConfig.defaults.custom = {
                  drawStyle = "bars";
                  fillOpacity = 50;
                };
                targets = [
                  {
                    refId = "A";
                    datasource = lokiDs;
                    expr = "sum by (${volumeBy}) (count_over_time(${selector} |= `$search` [$__auto]))";
                    legendFormat = "{{${volumeBy}}}";
                  }
                ];
              }
              {
                title = "Logs";
                type = "logs";
                datasource = lokiDs;
                gridPos = {
                  h = 20;
                  w = 24;
                  x = 0;
                  y = 6;
                };
                options = {
                  showTime = true;
                  wrapLogMessage = true;
                  enableLogDetails = true;
                  sortOrder = "Descending";
                  dedupStrategy = "none";
                };
                targets = [
                  {
                    refId = "A";
                    datasource = lokiDs;
                    expr = "${selector} |= `$search`";
                  }
                ];
              }
            ];
          };

        localDashboards = {
          pod-logs = {
            folder = "Logs";
            dashboard = mkLogsDashboard {
              uid = "pod-logs";
              title = "Pod Logs";
              variables = [
                (mkLabelVar "namespace" "label_values(namespace)")
                (mkLabelVar "pod" "label_values({namespace=~\"$namespace\"}, pod)")
                (mkLabelVar "container" "label_values({namespace=~\"$namespace\", pod=~\"$pod\"}, container)")
              ];
              selector = "{namespace=~\"$namespace\", pod=~\"$pod\", container=~\"$container\"}";
              volumeBy = "pod";
            };
          };
          # Blocky's query log: one journal line per query (queryLog.type = console).
          blocky-queries = {
            folder = "Networking";
            dashboard =
              let
                base = mkLogsDashboard {
                  uid = "blocky-queries";
                  title = "Blocky Queries";
                  variables = [
                    (mkLabelVar "instance" "label_values({unit=\"blocky.service\"}, instance)")
                  ];
                  selector = "{unit=\"blocky.service\", instance=~\"$instance\"}";
                  volumeBy = "instance";
                };
                # Query lines only, narrowed by the search box. The line is
                # `key=value` sorted by key, but answer and response_reason
                # hold spaces, so fields are cut by regexp, not logfmt.
                queries = "{unit=\"blocky.service\", instance=~\"$instance\"} |= \"queryLog\" |= `$search`";
                domain = "regexp `question_name=(?P<domain>\\S+)`";
                mkTop =
                  {
                    title,
                    filter ? "",
                    field,
                    regexp,
                    x,
                  }:
                  {
                    inherit title;
                    type = "table";
                    datasource = lokiDs;
                    gridPos = {
                      h = 10;
                      w = 8;
                      inherit x;
                      y = 0;
                    };
                    targets = [
                      {
                        refId = "A";
                        datasource = lokiDs;
                        queryType = "instant";
                        expr = "topk(15, sum by (${field}) (count_over_time(${queries}${filter} | ${regexp} [$__range])))";
                        legendFormat = "{{${field}}}";
                      }
                    ];
                    # One frame per series: fold each to a row, largest first.
                    transformations = [
                      {
                        id = "reduce";
                        options.reducers = [ "lastNotNull" ];
                      }
                      {
                        id = "organize";
                        options.renameByName = {
                          Field = field;
                          "Last *" = "queries";
                        };
                      }
                    ];
                    options.sortBy = [
                      {
                        displayName = "queries";
                        desc = true;
                      }
                    ];
                    fieldConfig.overrides = [
                      {
                        matcher = {
                          id = "byName";
                          options = "queries";
                        };
                        properties = [
                          {
                            id = "custom.cellOptions";
                            value = {
                              type = "gauge";
                              mode = "basic";
                            };
                          }
                        ];
                      }
                    ];
                  };
                shift =
                  p:
                  p
                  // {
                    gridPos = p.gridPos // {
                      y = p.gridPos.y + 36;
                    };
                  };
              in
              base
              // {
                panels = [
                  (mkTop {
                    title = "Top queried domains";
                    field = "domain";
                    regexp = domain;
                    x = 0;
                  })
                  (mkTop {
                    title = "Top blocked domains";
                    filter = " |= \"response_type=BLOCKED\"";
                    field = "domain";
                    regexp = domain;
                    x = 8;
                  })
                  (mkTop {
                    title = "Top clients";
                    field = "client";
                    regexp = "regexp `client_ip=(?P<client>\\S+)`";
                    x = 16;
                  })
                  {
                    title = "Queries by response type";
                    type = "timeseries";
                    datasource = lokiDs;
                    gridPos = {
                      h = 6;
                      w = 24;
                      x = 0;
                      y = 10;
                    };
                    fieldConfig.defaults.custom = {
                      drawStyle = "bars";
                      fillOpacity = 50;
                      stacking.mode = "normal";
                    };
                    targets = [
                      {
                        refId = "A";
                        datasource = lokiDs;
                        expr = "sum by (type) (count_over_time(${queries} | regexp `response_type=(?P<type>\\S+)` [$__auto]))";
                        legendFormat = "{{type}}";
                      }
                    ];
                  }
                  {
                    title = "Query log";
                    type = "table";
                    datasource = lokiDs;
                    gridPos = {
                      h = 20;
                      w = 24;
                      x = 0;
                      y = 16;
                    };
                    targets = [
                      {
                        refId = "A";
                        datasource = lokiDs;
                        expr = lib.concatStringsSep " | " [
                          queries
                          "regexp `client_ip=(?P<client>\\S+)`"
                          "regexp `question_name=(?P<domain>\\S+) question_type=(?P<qtype>\\S+)`"
                          "regexp `response_code=(?P<rcode>\\S+) response_reason=(?P<reason>.*) response_type=(?P<type>\\S+)`"
                          "regexp `answer=(?P<answer>.*) client_ip=`"
                          "regexp `duration_ms=(?P<duration_ms>\\d+)`"
                        ];
                      }
                    ];
                    # Loki's labels object to columns, the stream labels and raw line hidden.
                    transformations = [
                      {
                        id = "extractFields";
                        options.source = "labels";
                      }
                      {
                        id = "organize";
                        options = {
                          excludeByName = lib.genAttrs [
                            "labels"
                            "Line"
                            "tsNs"
                            "id"
                            "cluster"
                            "detected_level"
                            "instance"
                            "job"
                            "level"
                            "service_name"
                            "unit"
                          ] (_: true);
                          indexByName = lib.listToAttrs (
                            lib.imap0 (i: n: lib.nameValuePair n i) [
                              "Time"
                              "client"
                              "domain"
                              "qtype"
                              "type"
                              "reason"
                              "rcode"
                              "answer"
                              "duration_ms"
                            ]
                          );
                        };
                      }
                    ];
                  }
                ]
                ++ map shift base.panels;
              };
          };
          kubernetes-events = {
            folder = "Logs";
            dashboard = mkLogsDashboard {
              uid = "k8s-events";
              title = "Kubernetes Events";
              variables = [
                (mkLabelVar "namespace" "label_values({job=\"loki.source.kubernetes_events\"}, namespace)")
              ];
              selector = "{job=\"loki.source.kubernetes_events\", namespace=~\"$namespace\"}";
              volumeBy = "namespace";
            };
          };
          # Media file-tail logs: the per-app Alloy sidecars ship loki streams
          # labelled app/namespace + a static `log_file` (= app name). The raw
          # rotating `filename` label was dropped to bound stream cardinality,
          # and only the active info log is tailed (one logical file per app) —
          # so `app` IS the file provenance. `level` and free text are
          # filterable via the search box.
          media-logs = {
            folder = "Media";
            dashboard = mkLogsDashboard {
              uid = "media-logs";
              title = "Media Logs";
              variables = [
                (mkLabelVar "app" "label_values({namespace=\"media\"}, app)")
              ];
              # Require log_file → file-tail streams only; excludes the kept
              # sidecar (exportarr/logtail) stdout and any pre-fix streams.
              selector = "{namespace=\"media\", app=~\"$app\", log_file=~\".+\"}";
              volumeBy = "app";
            };
          };
        };

        importedDashboards = {
          argocd = {
            title = "ArgoCD";
            folder = "GitOps";
            url = "https://grafana.com/api/dashboards/14584/revisions/1/download";
            sha256 = "1ab8sdrd8ngaw4p9vzldzln5x1xqbp09wbmy9lkyv0gaxnl7nyqr";
            fixDatasource = true;
          };
          cert-manager = {
            title = "cert-manager";
            folder = "Security";
            url = "https://grafana.com/api/dashboards/11001/revisions/1/download";
            sha256 = "01q5ks0q3sabnw1rmmpz1yl864i47hbfxw0ksk6vpibrwm52p879";
            fixDatasource = true;
          };
          longhorn = {
            title = "Longhorn";
            folder = "Storage";
            url = "https://grafana.com/api/dashboards/13032/revisions/6/download";
            sha256 = "0rfdrixrj53czyxawvqf47z5rcgbiz2fr91ih9a7rj1n9akzhgvw";
            fixDatasource = true;
          };
          envoy-gateway = {
            title = "Envoy Gateway";
            folder = "Networking";
            url = envoyDashboardUrl "envoy-gateway-global";
            sha256 = "0knr3cgqf4cg31hk4ds39mywz1xpxxfirb886y2d42i7bdh2rp1c";
          };
          envoy-proxy = {
            title = "Envoy Proxy";
            folder = "Networking";
            url = envoyDashboardUrl "envoy-proxy-global";
            sha256 = "1dv7rgcmxap5cr7ww9q6icl0kwhjgaygs89acxgaqf7k1kcr40kz";
          };
          envoy-clusters = {
            title = "Envoy Clusters";
            folder = "Networking";
            url = envoyDashboardUrl "envoy-clusters";
            sha256 = "1ghh652xv48l72scyan0d2fjx9ll19kgx9xm3cifhqn5763mjvl9";
          };
          envoy-resources = {
            title = "Envoy Gateway Resources";
            folder = "Networking";
            url = envoyDashboardUrl "resources-monitor.gen";
            sha256 = "0h55cpc8k3294w8pjri6shkqqxscqnr8qs87k1dkhhk79xrmrzhl";
          };
          # Blocky's own dashboard, at the packaged release (services/networking/blocky).
          blocky = {
            title = "Blocky";
            folder = "Networking";
            url = "https://raw.githubusercontent.com/0xERR0R/blocky/v0.35.0/docs/blocky-grafana.json";
            sha256 = "00hpb1j3km226nwcyn9a0bp3ii3fm3y3c3qy1932fnf2pmh4xvpj";
            fixDatasource = true;
            # Live-checked against uplink's blocky: drop what never has data
            # here, add query rate by type and upstream latency, and size the
            # rate window to the scrape interval.
            jqFilter = ''
              def panel($id): first(.panels[] | select(.id == $id));
              def target($expr; $legend): {
                refId: "A", datasource: {type: "prometheus", uid: "prometheus"}, editorMode: "code",
                expr: $expr, legendFormat: $legend, range: true, instant: false
              };
              def resolved($window): "blocky_request_duration_seconds_bucket{response_type=\"RESOLVED\", job=~\"$job\", instance=~\"$instance\"}[\($window)]";
              panel(5) as $stat | panel(16) as $byOutcome | panel(23) as $percentiles
              | .panels |= map(
                  # DNSSEC and rate limiting are off on our blocky, so these rows only ever hold empty panels.
                  select((.type == "row" and (.title == "DNSSEC" or .title == "Rate limiting")) | not)
                  # Its buttons call $blocky_url from the browser: unbound here, and mixed content from https Grafana.
                  | if .id == 14 then
                      $stat + {
                        id: 14, title: "Upstream p95",
                        description: "95th percentile duration of queries resolved by an upstream (response_type RESOLVED), over the dashboard range.",
                        gridPos: .gridPos,
                        # Over the range: most queries are cached or conditional, so a short window is often empty.
                        targets: [target("histogram_quantile(0.95, sum by (le) (rate(\(resolved("$__range")))))"; "") | .range = false | .instant = true]
                      }
                    elif .id == 2 then .description = "Ad/tracker blocking status."
                    elif .id == 16 or .id == 25 then .gridPos.w = 12
                    else . end)
              | .panels += [
                  $byOutcome + {
                    id: 50, title: "Queries by type",
                    description: "Query rate by DNS record type.",
                    gridPos: {h: 9, w: 12, x: 12, y: 10},
                    fieldConfig: ($byOutcome.fieldConfig | .overrides = []),
                    targets: [target("sum by (type) (rate(blocky_query_total{job=~\"$job\", instance=~\"$instance\"}[$__rate_interval]))"; "{{type}}")]
                  },
                  $percentiles + {
                    id: 51, title: "Upstream response time",
                    description: "Median, 95th and 99th percentile duration of queries resolved by an upstream (response_type RESOLVED).",
                    gridPos: {h: 8, w: 12, x: 12, y: 46},
                    targets: [
                      target("histogram_quantile(0.50, sum by (le) (rate(\(resolved("$__rate_interval")))))"; "p50"),
                      (target("histogram_quantile(0.95, sum by (le) (rate(\(resolved("$__rate_interval")))))"; "p95") | .refId = "B"),
                      (target("histogram_quantile(0.99, sum by (le) (rate(\(resolved("$__rate_interval")))))"; "p99") | .refId = "C")
                    ]
                  }
                ]
              | .panels |= sort_by(.gridPos.y, .gridPos.x)
              # Alloy scrapes blocky every 60s, not the datasource's 30s: a 1m min
              # interval makes $__rate_interval 4m, so a rate window never holds one sample.
              | .panels |= map(if .type == "row" then .panels |= map(.interval = "1m") else .interval = "1m" end)
              | .description |= sub(", DNSSEC, rate limiting and"; " and")
              | .templating.list |= map(select(.name != "blocky_url"))
              | .__inputs |= map(select(.name != "VAR_BLOCKY_URL"))
            '';
          };

          # Media exporters. The *arr/sabnzbd metrics come from exportarr
          # (app-prefixed series, e.g. sonarr_*, prowlarr_*); these community
          # dashboards are authored against exportarr's schema and filter by
          # the datasource/instance template vars (no hardcoded job), so they
          # match our job="media/<app>" series.
          media-sonarr = {
            title = "Sonarr";
            folder = "Media";
            url = "https://grafana.com/api/dashboards/12530/revisions/2/download";
            sha256 = "0nqnl7vyg0nlskgxskhkyfyn2c0izf2wq5350sg4x8sp1zv1q429";
            fixDatasource = true;
            excludeColonInstances = true;
          };
          media-radarr = {
            title = "Radarr";
            folder = "Media";
            url = "https://grafana.com/api/dashboards/12896/revisions/1/download";
            sha256 = "1fqpwp544sc3m0gvnn9cvgiampkwilpp5vizhix2182c120waqih";
            fixDatasource = true;
            excludeColonInstances = true;
          };
          # exportarr's own multi-app "Media Dashboard" — the only
          # exportarr-schema dashboard covering Lidarr/Prowlarr/SABnzbd (no
          # standalone grafana.com ids exist for those); per-app instance
          # template vars, no hardcoded job filters.
          media-exportarr = {
            title = "Media (exportarr)";
            folder = "Media";
            url = "https://raw.githubusercontent.com/onedr0p/exportarr/88b9d3d0916ca701b89a2bdefe8b1d5b45294111/examples/grafana/dashboard2.json";
            sha256 = "158bvaf8djk9rda9vswpqkigkpawbw3arpg2vraaqgdblqqdlhs1";
            fixDatasource = true;
            excludeColonInstances = true;
          };
          # qBittorrent via the esanchezm exporter — this dashboard ships in
          # that exporter's repo and matches our qbittorrent_* schema
          # (qbittorrent_alltime_dl_total, _connected, _dht_nodes, …). The
          # common grafana.com id 15116 targets a DIFFERENT exporter
          # (qbittorrent_global_*/_torrent_*) and would not bind.
          media-qbittorrent = {
            title = "qBittorrent";
            folder = "Media";
            url = "https://raw.githubusercontent.com/esanchezm/prometheus-qbittorrent-exporter/fac38ac30d29e3bac4d3044c2011f523fc7c04c6/grafana/dashboard.json";
            sha256 = "0l7z8dfnm4crxlczd5a6cdgnz9jy91vmxq25x78rjkskky02an8h";
            fixDatasource = true;
            excludeColonInstances = true;
          };
          # Unpackerr — golift's own dashboard, keyed on unpackerr_* with an
          # instance template var our series populate.
          media-unpackerr = {
            title = "Unpackerr";
            folder = "Media";
            url = "https://grafana.com/api/dashboards/18817/revisions/1/download";
            sha256 = "1p7xlfm7kbydymh7gxl60bm7bj3cphjbf69hnqqsbkm0npj99jgw";
            fixDatasource = true;
            excludeColonInstances = true;
          };
          # Tdarr via the homeylab/tdarr-exporter v3 sidecar — the exporter's
          # own v3 dashboard (examples/dashboard.json pinned at the v3.0.0 tag;
          # archive/ holds the retired v1/v2 ones). Keyed on the v3 tdarr_*
          # schema: tdarr_size_diff_bytes (space saved), files/transcode counts,
          # per-library tdarr_library_transcodes_completed_total joined to
          # tdarr_library_info for the name, node/worker status
          # (tdarr_node_worker_status), and tdarr_server_uptime_seconds. No
          # excludeColonInstances: this dashboard's instance variable is
          # `tdarr_instance` (the exporter-set server hostname — here `localhost`,
          # never a colon-form pod-IP), not the prometheus `instance` label our
          # PodMonitor relabels, so the pod-IP churn that option fixes can't arise.
          media-tdarr = {
            title = "Tdarr";
            folder = "Media";
            url = "https://raw.githubusercontent.com/homeylab/tdarr-exporter/28de93aaea020744ce246f4eb33ef9e830a52419/examples/dashboard.json";
            sha256 = "03h41n18csh0jjvxlxqbk9ssf8gaxk4k210wq6nla32zzrlc2n5w";
            fixDatasource = true;
          };
        };
      in
      {
        applications.grafana = {
          namespace = "monitoring";

          # Dashboard ConfigMaps (the CNPG one is ~250KiB) blow past the
          # 256KiB last-applied annotation limit under client-side apply.
          syncPolicy.syncOptions.serverSideApply = true;
          compareOptions.serverSideDiff = true;

          # CNPG cluster dashboard — rendered as a labeled ConfigMap the
          # sidecar picks up. The operator chart's grafanaDashboard.create is
          # a stub (the JSON moved to the dedicated dashboards repo this
          # chart is pinned from).
          helm.releases.cnpg-grafana-cluster = {
            chart = charts.cnpg-grafana-dashboards.cluster;
            values.grafanaDashboard.annotations.grafana_folder = "Databases";
          };

          helm.releases.grafana = {
            chart = charts.grafana.grafana;

            values = {
              # State lives in monitoring-pg (see monitoring-pg.nix);
              # dashboards/datasources are fully provisioned, so the pod is
              # stateless: no PVC, rolling updates are safe.
              persistence.enabled = false;

              # Without this the chart mints a render-time random admin
              # password — rotated on EVERY sync while the database keeps the
              # first-boot value: local admin unusable, sidecar reload 401s,
              # and perpetual SopsSecret drift in the diffs.
              admin = {
                existingSecret = "grafana-admin";
                userKey = "admin-user";
                passwordKey = "admin-password";
              };

              serviceMonitor.enabled = true;

              # Provision dashboards from labeled ConfigMaps; the
              # grafana_folder annotation routes each into a real folder.
              sidecar.dashboards = {
                enabled = true;
                searchNamespace = "monitoring";
                folderAnnotation = "grafana_folder";
                provider.foldersFromFilesStructure = true;
                # No credentialed reload POSTs — there is no password-bearing
                # account to authenticate them; the file provider polls.
                skipReload = true;
              };

              # Secrets land as env vars (GF_ vars override grafana.ini),
              # sourced from SopsSecrets / the CNPG role secret.
              envValueFrom = {
                GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET.secretKeyRef = {
                  name = "grafana-oidc-client-secret";
                  key = "client-secret";
                };
                GF_DATABASE_PASSWORD.secretKeyRef = {
                  name = "monitoring-pg-grafana-password";
                  key = "password";
                };
                GF_SECURITY_SECRET_KEY.secretKeyRef = {
                  name = "grafana-secret-key";
                  key = "secret-key";
                };
              };

              datasources."datasources.yaml" = {
                apiVersion = 1;
                # The original records were created without explicit uids;
                # provisioning matches BY uid once one is specified and
                # hard-fails on the lookup miss. Deleting by name first makes
                # the pinned-uid recreate idempotent (provisioned datasources
                # carry no state worth keeping).
                deleteDatasources = [
                  {
                    name = "Prometheus";
                    orgId = 1;
                  }
                  {
                    name = "Loki";
                    orgId = 1;
                  }
                ];
                datasources = [
                  {
                    name = "Prometheus";
                    uid = "prometheus";
                    type = "prometheus";
                    access = "proxy";
                    url = "http://kube-prometheus-stack-prometheus.monitoring:9090";
                    isDefault = true;
                    jsonData = {
                      # min step = the slowest scraper feeding it: hosts arrive
                      # through Alloy at its default 60s (kps scrapes at 30s), and a
                      # 30s step gives rate() windows that hold a single sample.
                      timeInterval = "60s";
                      httpMethod = "POST";
                    };
                  }
                  {
                    name = "Loki";
                    uid = "loki";
                    type = "loki";
                    access = "proxy";
                    url = "http://loki.monitoring:3100";
                    jsonData = {
                      maxLines = 1000;
                    };
                  }
                  # The cluster Alertmanager, so its alerts and silences
                  # (Alerting > Silences, choose this Alertmanager) are
                  # manageable from Grafana.
                  {
                    name = "Alertmanager";
                    uid = "alertmanager";
                    type = "alertmanager";
                    access = "proxy";
                    url = "http://kube-prometheus-stack-alertmanager.monitoring:9093";
                    jsonData = {
                      implementation = "prometheus";
                      handleGrafanaManagedAlerts = false;
                    };
                  }
                ];
              };

              "grafana.ini" = {
                server = {
                  inherit domain;
                  root_url = "https://${domain}";
                  enforce_domain = false;
                };

                # Passwordless, mirroring the host-level grafana: no admin
                # user is ever created, so the login form stays harmless and
                # kanidm is the only authority (server-admins map to
                # GrafanaAdmin). secret_key is pinned via env above — the
                # stateless pod must not sign cookies with the shipped
                # default.
                security = {
                  disable_initial_admin_creation = true;
                  cookie_secure = true;
                  disable_gravatar = true;
                  hide_version = true;
                };

                # Backing store in monitoring-pg (password via
                # GF_DATABASE_PASSWORD above). ssl_mode require: CNPG serves
                # TLS with a cluster-internal CA.
                database = {
                  type = "postgres";
                  host = "monitoring-pg-rw.monitoring:5432";
                  name = "grafana";
                  user = "grafana";
                  ssl_mode = "require";
                };

                analytics = {
                  reporting_enabled = false;
                  check_for_updates = false;
                };

                users = {
                  allow_sign_up = false;
                  auto_assign_org = true;
                  auto_assign_org_role = "Viewer";
                };

                auth.oauth_auto_login = true;

                # Mirrors the host-level grafana OIDC config (same kanidm
                # ACL groups: grafana.{editors,admins,server-admins}).
                "auth.generic_oauth" = {
                  enabled = true;
                  name = "KanIDM";
                  icon = "signin";
                  allow_sign_up = true;
                  auto_login = true;
                  client_id = "grafana";
                  scopes = "openid email profile";
                  login_attribute_path = "preferred_username";
                  auth_url = "https://${kanidmDomain}/ui/oauth2";
                  token_url = "https://${kanidmDomain}/oauth2/token";
                  api_url = "https://${kanidmDomain}/oauth2/openid/grafana/userinfo";
                  use_pkce = true;
                  use_refresh_token = true;
                  role_attribute_path = "contains(groups[*], 'server_admin') && 'GrafanaAdmin' || contains(groups[*], 'admin') && 'Admin' || contains(groups[*], 'editor') && 'Editor' || 'Viewer'";
                  role_attribute_strict = false;
                  allow_assign_grafana_admin = true;
                  skip_org_role_sync = false;
                };
              };
            };
          };

          resources = {
            configMaps =
              lib.mapAttrs' (
                name: d:
                lib.nameValuePair "dashboard-${name}" {
                  metadata = {
                    labels.grafana_dashboard = "1";
                    annotations.grafana_folder = d.folder;
                  };
                  data."${name}.json" = mkDashboardJson {
                    inherit name;
                    inherit (d) title url sha256;
                    fixDatasource = d.fixDatasource or false;
                    excludeColonInstances = d.excludeColonInstances or false;
                    jqFilter = d.jqFilter or null;
                  };
                }
              ) importedDashboards
              // lib.mapAttrs' (
                name: d:
                lib.nameValuePair "dashboard-${name}" {
                  metadata = {
                    labels.grafana_dashboard = "1";
                    annotations.grafana_folder = d.folder;
                  };
                  data."${name}.json" = builtins.toJSON d.dashboard;
                }
              ) localDashboards;

            httpRoutes.grafana.spec = {
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.domainForResource "grafana"}-https";
                }
              ];
              hostnames = [ (cluster.domainFor "grafana") ];
              rules = [
                {
                  backendRefs = [
                    {
                      name = "grafana";
                      port = 80;
                    }
                  ];
                }
              ];
            };

            secrets = {
              grafana-oidc-client-secret = {
                type = "Opaque";
                stringData.client-secret = config.age.secrets.grafana-oidc-client-secret.sopsRef;
              };

              grafana-admin = {
                type = "Opaque";
                stringData = {
                  admin-user = "admin";
                  admin-password = config.age.secrets.grafana-admin-password.sopsRef;
                };
              };

              grafana-secret-key = {
                type = "Opaque";
                stringData.secret-key = config.age.secrets.grafana-secret-key.sopsRef;
              };
            };

            ciliumNetworkPolicies = {
              # The dashboard sidecar watches ConfigMaps via the apiserver.
              allow-grafana-kube-apiserver-egress.spec = {
                description = "Allow the grafana dashboard sidecar to watch the kube-apiserver.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "grafana";
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

              # OIDC token/userinfo calls go server-side from the grafana pod
              # to kanidm, which lives outside the cluster (world entity).
              allow-grafana-kanidm-egress.spec = {
                description = "Allow grafana to reach kanidm for OIDC token/userinfo calls.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "grafana";
                egress = [
                  {
                    toEntities = [ "world" ];
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

    age-secrets =
      { environment, ... }:
      {
        age.secrets.grafana-oidc-client-secret = {
          rekeyFile = environment.secretPath + "/oidc/grafana-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          sopsOutput = {
            file = "oidc";
            key = "grafana";
          };
        };

        # The admin secret stays pinned but is inert: with
        # disable_initial_admin_creation no account exists to use it, and
        # removing it would regress the chart to render-time random
        # passwords (diff churn).
        age.secrets.grafana-admin-password = {
          rekeyFile = environment.secretPath + "/grafana/admin-password.age";
          generator.script = "rfc3986-secret";
          sopsOutput = {
            file = "grafana";
            key = "admin-password";
          };
        };

        age.secrets.grafana-secret-key = {
          rekeyFile = environment.secretPath + "/grafana/secret-key.age";
          settings.length = "32";
          generator.script = "hex";
          sopsOutput = {
            file = "grafana";
            key = "secret-key";
          };
        };
      };
  };
}
