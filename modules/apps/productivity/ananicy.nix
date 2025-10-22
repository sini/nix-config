{
  flake.features.ananicy.nixos =
    { lib, pkgs, ... }:
    {
      services = {
        irqbalance.enable = true;
        ananicy = {
          # Core service configuration
          enable = true;
          rulesProvider = pkgs.ananicy-rules-cachyos_git;
          extraRules = [
            {
              "name" = "/run/libvirt/nix-emulators/qemu-system-x86_64";
              # "cmdlines" = [ "guest=win11,debug-threads=on" ];
              "type" = "LowLatency_RT";
            }
          ];
          settings = {
            # Core timing and logging settings
            ## Ananicy 2.X configuration
            # Ananicy run full system scan every "check_freq" seconds
            # supported values 0.01..86400
            # values which have sense: 1..60
            check_freq = 15;
            # Loglevel configuration
            # supported values: trace, debug, info, warn, error, critical
            loglevel = "info";
            log_applied_rule = false;

            # Module loading settings
            cgroup_load = true;
            rule_load = true;
            type_load = true;

            # Feature application settings
            apply_cgroup = true;
            apply_ionice = true;
            apply_latnice = true;
            apply_nice = true;
            apply_oom_score_adj = true;
            apply_sched = true;

            # Advanced settings
            # It tries to move realtime task to root cgroup to be able to move it to the ananicy-cpp controlled one
            # NOTE: may introduce issues, for example with polkit
            cgroup_realtime_workaround = lib.mkForce false;
          };
        };
      };
    };
}
