# host-alerts-check: the cluster's host rules (kubernetes/services/monitoring/
# prometheus.nix) pass promtool, and their role-scoped thresholds fire on the
# right hosts, read off axon's rendered rules and the hosts' real roles:
#   NodeMemoryMajorPagesFaults  axon-01 (server) at 6000/s and cortex (dev) at
#                               30000/s fire; bitstream (dev) at 6000/s does not
#   NodeMemoryPressure          cortex at 10% stall fires; bitstream at 1% does not
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
  # A counter rising `perMin` per minute for 40 minutes.
  counter = metric: instance: perMin: {
    series = ''${metric}{job="node-exporter", instance="${instance}"}'';
    values = "0+${toString perMin}x40";
  };
  test = {
    rule_files = [ "rules.json" ];
    evaluation_interval = "1m";
    tests = [
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
            promtool check rules rules.json
            promtool test rules test.json
            touch $out
          '';
    };
}
