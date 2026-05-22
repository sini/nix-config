{ den, ... }:
{
  den.aspects.system.ananicy = {
    nixos =
      {
        lib,
        pkgs,
        ...
      }:
      {
        services = {
          irqbalance.enable = true;
          ananicy = {
            enable = true;
            rulesProvider = pkgs.ananicy-rules-cachyos_git;
            extraRules = [
              {
                "name" = "/run/libvirt/nix-emulators/qemu-system-x86_64";
                "type" = "LowLatency_RT";
              }
            ];
            settings = {
              check_freq = 15;
              loglevel = "info";
              log_applied_rule = false;
              cgroup_load = true;
              rule_load = true;
              type_load = true;
              apply_cgroup = true;
              apply_ionice = true;
              apply_latnice = true;
              apply_nice = true;
              apply_oom_score_adj = true;
              apply_sched = true;
              cgroup_realtime_workaround = lib.mkForce false;
            };
          };
        };
      };
  };
}
