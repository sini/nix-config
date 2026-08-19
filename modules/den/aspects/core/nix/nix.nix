{
  den.aspects.core.nix = {
    os = {
      nix = {
        settings = {
          experimental-features = [
            "auto-allocate-uids"
            "cgroups"
            "flakes"
            "nix-command"
            "pipe-operators"
          ];

          allow-import-from-derivation = true;
          max-jobs = "auto";
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
          ];

          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
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
      { lib, ... }:
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
            # physical RAM, so a build host and a small node are bounded in the
            # same proportion without either being named here.
            MemoryHigh = "60%";
            MemoryMax = "85%";
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
