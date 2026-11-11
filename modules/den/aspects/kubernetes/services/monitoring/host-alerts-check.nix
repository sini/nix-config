# host-alerts-check: the cluster's host rules (kubernetes/services/monitoring/
# prometheus.nix) pass promtool, and their role-scoped thresholds fire on the
# right hosts, read off axon's rendered rules and the hosts' real roles:
#   NodeMemoryMajorPagesFaults  axon-01 (server) at 6000/s and cortex (dev) at
#                               30000/s fire; bitstream (dev) at 6000/s does not
#   NodeMemoryPressure          cortex at 10% stall fires; bitstream at 1% does not
#   NodeCPUHighUsage            at 100% CPU, axon-01 (server) fires by 30m;
#                               bitstream (nix-builder) only after an hour
#   BlockyDown                  uplink's blocky stopping (up 1 to 0) fires 10m later, not 9m
#   BlockyDenylistShrunk        a denylist cut from 4000 to 1661 entries fires;
#                               the whole list held does not
#   nix build .#checks.x86_64-linux.host-alerts
{ config, lib, ... }:
let
  rulesMap =
    config.flake.nixidyEnvs.x86_64-linux.axon.config.applications.kube-prometheus-stack.helm.releases.kube-prometheus-stack.values.additionalPrometheusRulesMap;
  rules = {
    groups = rulesMap.hosts.groups ++ rulesMap.host-roles.groups;
  };
  alertOf =
    name: lib.findFirst (r: r.alert or null == name) null (lib.head rulesMap.hosts.groups).rules;
  # The annotations promtool renders for an alert at instance and value.
  annotationsOf =
    alert: instance: subs:
    let
      a = (alertOf alert).annotations;
    in
    a
    // {
      description = lib.replaceStrings ([ "{{ $labels.instance }}" ] ++ lib.attrNames subs) (
        [ instance ] ++ lib.attrValues subs
      ) a.description;
    };
  expect = alert: instance: subs: {
    exp_labels = {
      severity = "warning";
      job = "node-exporter";
      inherit instance;
    };
    exp_annotations = annotationsOf alert instance subs;
  };
  faults = n: { "{{ printf \"%.0f\" $value }}" = toString n; };
  expectCpu =
    instance:
    let
      rule = alertOf "NodeCPUHighUsage";
    in
    {
      exp_labels = {
        severity = "info";
        job = "node-exporter";
        inherit instance;
      };
      exp_annotations = rule.annotations // {
        description =
          lib.replaceStrings [ "{{ $labels.instance }}" "{{ printf \"%.0f\" $value }}" ] [ instance "100" ]
            rule.annotations.description;
      };
    };
  # One CPU fully busy (user) for 90 minutes.
  busyCpu = instance: {
    series = ''node_cpu_seconds_total{job="node-exporter", instance="${instance}", cpu="0", mode="user"}'';
    values = "0+60x90";
  };
  # A counter rising `perMin` per minute for 40 minutes.
  counter = metric: instance: perMin: {
    series = ''${metric}{job="node-exporter", instance="${instance}"}'';
    values = "0+${toString perMin}x40";
  };
  summaryOf = alert: (alertOf alert).annotations.summary or null;
  blocky = alert: instance: {
    exp_labels = {
      severity = "warning";
      job = "blocky";
      inherit instance;
    };
    exp_annotations.summary = lib.replaceStrings [ "{{ $labels.instance }}" ] [ instance ] (
      summaryOf alert
    );
  };
  denylist = instance: values: {
    series = ''blocky_denylist_cache_entries{job="blocky", instance="${instance}", group="default"}'';
    inherit values;
  };
  test = {
    rule_files = [ "rules.json" ];
    evaluation_interval = "1m";
    tests = [
      {
        interval = "1m";
        input_series = [
          {
            series = ''up{job="blocky", instance="uplink"}'';
            values = "1x10 0x30";
          }
          (denylist "uplink" "4000x10 1661x30")
          (denylist "uplink-dev" "4000x40")
        ];
        alert_rule_test = [
          {
            eval_time = "19m";
            alertname = "BlockyDown";
            exp_alerts = [ ];
          }
          {
            eval_time = "21m";
            alertname = "BlockyDown";
            exp_alerts = [ (blocky "BlockyDown" "uplink") ];
          }
          {
            eval_time = "30m";
            alertname = "BlockyDenylistShrunk";
            exp_alerts = [
              (lib.recursiveUpdate (blocky "BlockyDenylistShrunk" "uplink") { exp_labels.group = "default"; })
            ];
          }
        ];
      }
      {
        interval = "1m";
        input_series = [
          (counter "node_vmstat_pgmajfault" "bitstream" 360000)
          (counter "node_vmstat_pgmajfault" "axon-01" 360000)
          (counter "node_vmstat_pgmajfault" "cortex" 1800000)
          (counter "node_pressure_memory_stalled_seconds_total" "cortex" 6)
          (counter "node_pressure_memory_stalled_seconds_total" "bitstream" 0.6)
        ];
        alert_rule_test = [
          {
            eval_time = "30m";
            alertname = "NodeMemoryMajorPagesFaults";
            exp_alerts = [
              (expect "NodeMemoryMajorPagesFaults" "axon-01" (faults 6000))
              (expect "NodeMemoryMajorPagesFaults" "cortex" (faults 30000))
            ];
          }
          {
            eval_time = "30m";
            alertname = "NodeMemoryPressure";
            exp_alerts = [
              (expect "NodeMemoryPressure" "cortex" { "{{ $value | humanizePercentage }}" = "10%"; })
            ];
          }
        ];
      }
      {
        interval = "1m";
        input_series = [
          (busyCpu "bitstream")
          (busyCpu "axon-01")
        ];
        alert_rule_test = [
          {
            eval_time = "30m";
            alertname = "NodeCPUHighUsage";
            exp_alerts = [ (expectCpu "axon-01") ];
          }
          {
            eval_time = "75m";
            alertname = "NodeCPUHighUsage";
            exp_alerts = [
              (expectCpu "bitstream")
              (expectCpu "axon-01")
            ];
          }
        ];
      }
    ];
  };
in
{
  perSystem =
    { pkgs, system, ... }:
    lib.optionalAttrs (system == "x86_64-linux") {
      checks.host-alerts =
        pkgs.runCommand "host-alerts" { nativeBuildInputs = [ pkgs.prometheus.cli ]; }
          ''
            cp ${pkgs.writeText "rules.json" (builtins.toJSON rules)} rules.json
            cp ${pkgs.writeText "test.json" (builtins.toJSON test)} test.json
            promtool check rules --lint-fatal rules.json
            promtool test rules test.json
            touch $out
          '';
    };
}
