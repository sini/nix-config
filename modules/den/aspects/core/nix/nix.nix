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
            "pipe-operator"
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
            "https://cache.garnix.io"
          ];

          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "numtide.cachix.org-1:2ps1kLBUWjxIneOy1Ik6cQjb41X0iXVXeHigGmycPPE="
            "cache.garnix.io:CTFPyKSLcx5RMJKfLo5EEPUObbA78b0YQ2DTCJXqr9g="
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
      nix.settings =
        let
          users = [
            "root"
            "@admin"
          ];
        in
        {
          trusted-users = users;
          allowed-users = users;
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
          settings =
            let
              users = [
                "root"
                "@wheel"
              ];
            in
            {
              trusted-users = users;
              allowed-users = users;
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
