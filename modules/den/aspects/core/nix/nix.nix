{ lib, ... }:
{
  den.aspects.core.nix = {
    # A host's build parallelism budget (the bgp pattern: the aspect declares, the host file sets).
    # Memory scales with max-jobs × cores, not with either alone: two link-heavy builds (a kernel
    # and chromium) each fanning out to every core is what pushes a host OOM, so a large host
    # keeps the product near its core count rather than at its square.
    settings = {
      maxJobs = lib.mkOption {
        type = lib.types.either lib.types.ints.positive (lib.types.enum [ "auto" ]);
        default = "auto";
        description = "Concurrent builds this host runs (nix max-jobs)";
      };
      cores = lib.mkOption {
        type = lib.types.ints.unsigned;
        default = 0;
        description = "Cores each build may use (nix cores; 0 = all)";
      };
      # A share of PHYSICAL RAM, not of what is free: a host whose own workload (a Kubernetes node's
      # pods) already holds most of its memory needs a smaller slice, or the slice's bound sits
      # above what the host can give.
      daemonMemoryHigh = lib.mkOption {
        type = lib.types.str;
        default = "60%";
        description = "nix-daemon.slice MemoryHigh (reclaim throttle)";
      };
      daemonMemoryMax = lib.mkOption {
        type = lib.types.str;
        default = "85%";
        description = "nix-daemon.slice MemoryMax (one build fails past it)";
      };
    };

    os =
      { host, ... }:
      {
        nix = {
          nixPath = [ "nixpkgs=flake:nixpkgs" ];
          settings = {
            experimental-features = [
              "auto-allocate-uids"
              "cgroups"
              "flakes"
              "nix-command"
              "pipe-operators"
            ];

            allow-import-from-derivation = true;
            max-jobs = host.settings.core.nix.maxJobs;
            inherit (host.settings.core.nix) cores;
            use-xdg-base-directories = true;
            http-connections = 128;
            max-substitution-jobs = 128;
            log-lines = 25;
            min-free = 128000000;
            max-free = 1000000000;
            auto-optimise-store = true;
            warn-dirty = false;
            keep-outputs = true;
            keep-derivations = true;

            substituters = [
              "https://cache.nixos.org/"
              "https://nix-community.cachix.org"
              "https://numtide.cachix.org"
              # What our CI builds (services/nix/attic.nix): public-read.
              "https://attic.json64.dev/ci"
            ];

            trusted-public-keys = [
              "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
              "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
              "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
              "ci:1i+3fr0BNdABCWGG0CGUpcvzWCLpnx7/EuEQujmowmg="
            ];

            connect-timeout = 5;
            builders-use-substitutes = true;
            sandbox = "relaxed";
            fallback = true;
          };

          gc = {
            automatic = true;
            options = "--delete-older-than 8d";
          };
        };
      };

    darwin = {
      nix.settings = {
        # trusted-users (root-equivalent nix power) stays admin-only; allowed-users
        # (mere daemon access) covers every local login user. See the nixos arm.
        trusted-users = [
          "root"
          "@admin"
        ];
        allowed-users = [ "*" ];
      };
      nix.gc.interval = {
        Hour = 5;
        Minute = 0;
      };
    };

    nixos =
      { lib, host, ... }:
      {
        nix = {
          settings = {
            # trusted-users grants root-equivalent nix power (override settings,
            # add substituters, import untrusted store paths) — admins only.
            trusted-users = [
              "root"
              "@wheel"
            ];
            # allowed-users only gates who may connect to the daemon; every local
            # login user needs it (HM activation, nix-shell). It is NOT a privilege
            # boundary, so it must not track wheel — decoupled from sudo like login.
            # With mutableUsers = false, local accounts are exactly the resolved
            # registry users, so "*" is precisely the login set.
            allowed-users = [ "*" ];
            # One cgroup per build under nix-daemon.slice, so the slice's MemoryMax and oomd's
            # pressure kill take a whole build out cleanly rather than its largest process (a
            # linker, a substitution, or the daemon itself).
            use-cgroups = true;
          };

          gc.dates = "05:00";
          daemonCPUSchedPolicy = lib.mkDefault "batch";
          daemonIOSchedClass = lib.mkDefault "idle";
          daemonIOSchedPriority = lib.mkDefault 7;
        };

        # OOM prevention: separate slice for nix-daemon
        systemd = {
          slices."nix-daemon".sliceConfig = {
            ManagedOOMMemoryPressure = "kill";
            ManagedOOMMemoryPressureLimit = "50%";
            # A pressure policy alone only reacts once the host is already
            # struggling, and it cannot act at all while the kernel still sees
            # swap to hand out. These are the standing bound: High throttles the
            # slice into reclaim, Max fails one build rather than letting the
            # builds take the machine with them. systemd resolves both against
            # physical RAM; a host with its own heavy workload sets smaller shares.
            MemoryHigh = host.settings.core.nix.daemonMemoryHigh;
            MemoryMax = host.settings.core.nix.daemonMemoryMax;
          };
          services."nix-daemon".serviceConfig = {
            Slice = "nix-daemon.slice";
            OOMScoreAdjust = lib.mkDefault 250;
          };
          services.nix-gc.serviceConfig = {
            CPUSchedulingPolicy = "batch";
            IOSchedulingClass = "idle";
            IOSchedulingPriority = 7;
          };
        };
      };
  };
}
