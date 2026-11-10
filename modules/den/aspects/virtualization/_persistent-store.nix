# Helpers for microvm-guests.nix: a persistent-store guest's guest-side module and host-side
# units, the host-wide store sweep, and the verdict units the timer-driven ones report
# through. docs/microvm-persistent-store.md.
{ lib }:
rec {
  # The host's permanent GC roots for persistent-store guests, one directory per guest.
  rootsDir = "/nix/var/nix/gcroots/microvm-store";

  # The host daemon, reached from a guest over AF_VSOCK (§2.2).
  lowerPort = "5119";
  hostDaemonSocket = "/nix/var/nix/daemon-socket/socket";

  # The export, relative to the guest's /cache (the host's stateDir <guest> "/cache").
  exportRel = ".microvm-store/roots";

  # Runners that attach vhost-vsock, so a CID-2 connection reaches the host (§2.1).
  vsockHypervisors = [
    "qemu"
    "kvmtool"
    "alioth"
    "crosvm"
  ];

  # §2.1-§2.3, §2.5, §2.6: merged into microvm.vms.<name>.config.
  guestModule =
    {
      name,
      rwStore,
      roStore,
      image,
      size,
      maxExportPaths,
    }:
    {
      config,
      pkgs,
      ...
    }:
    let
      nix = config.nix.package;
      lowerSocket = "/run/nix-lower/socket";
      lowerUrl = "unix://${lowerSocket}?real=${roStore}";
      remountHook = pkgs.writeShellScript "nix-store-remount" ''
        exec ${pkgs.util-linux}/bin/mount -o remount "$1"
      '';
      storeConf = "nix-daemon/store.conf";
      prog = pkgs.writers.writePython3Bin "nix-persistent-store" {
        flakeIgnore = [
          "E501"
          "E203"
        ];
      } (builtins.readFile ./_store-guest.py);
      args = lib.escapeShellArgs [
        "--store-dir"
        builtins.storeDir
        "--state-dir"
        "/nix/var/nix"
        "--upper"
        "${rwStore}/store"
        "--ro"
        roStore
        "--lower"
        lowerUrl
        "--remount-hook"
        remountHook
        "--counters"
        "/nix/var/nix/reconcile"
        "--out"
        "/cache/${exportRel}"
        "--max-paths"
        (toString maxExportPaths)
      ];
      v = verdicts {
        inherit pkgs;
        systemd = config.systemd.package;
      };
      export = v "nix-store-roots-export";
      reconcile = v "nix-store-reconcile";
      gib = n: n * 1024 * 1024 * 1024;
    in
    {
      assertions = [
        {
          assertion = lib.elem config.microvm.hypervisor vsockHypervisors;
          message = "${name}: microvm.persistentStore needs a hypervisor that attaches vhost-vsock (${lib.concatStringsSep ", " vsockHypervisors}), not ${config.microvm.hypervisor}";
        }
      ];

      # One volume: the overlay's upper and work dirs, and /nix/var/nix (§2.1).
      microvm.volumes = [
        {
          inherit image size;
          mountPoint = rwStore;
          fsType = "ext4";
        }
      ];
      # The host's database holds the system closure, rooted by its `current` runner link.
      microvm.registerClosure = false;
      fileSystems."/nix/var/nix" = {
        device = "${rwStore}/var/nix";
        fsType = "none";
        options = [ "bind" ];
        neededForBoot = true;
        depends = [ rwStore ];
      };
      # The bind's source, made in the initrd (nixpkgs' overlayfs.nix pattern); builds/ is
      # emptied first, so build dirs stay boot-only as on the tmpfs root.
      boot.initrd.systemd.services.rw-sysroot-nix-var-nix = {
        requiredBy = [ "sysroot-nix-var-nix.mount" ];
        before = [ "sysroot-nix-var-nix.mount" ];
        unitConfig = {
          DefaultDependencies = false;
          RequiresMountsFor = "/sysroot${rwStore}";
        };
        serviceConfig = {
          Type = "oneshot";
          ExecStart = [
            "${pkgs.coreutils}/bin/rm -rf /sysroot${rwStore}/var/nix/builds"
            "${pkgs.coreutils}/bin/mkdir -p -m 0755 /sysroot${rwStore}/var/nix"
          ];
        };
      };

      # Only the daemon opens the local-overlay store; every client, root included, goes
      # through it. The URL is in a file, so systemd's % specifiers never see it, and in a
      # user conf file, which loads after /etc/nix/nix.conf and so wins (§2.1).
      nix.settings = {
        store = lib.mkForce "daemon";
        experimental-features = [ "local-overlay-store" ];
        # A guest GC first syncs a row per host store entry (§2.5).
        min-free = lib.mkForce (gib 8);
        max-free = lib.mkForce (gib 24);
      };
      # Off the host's 05:00 GC.
      nix.gc.dates = lib.mkForce "03:00";
      environment.etc.${storeConf}.text =
        "store = local-overlay://?lower-store=${lib.escapeURL lowerUrl}"
        + "&upper-layer=${rwStore}/store&check-mount=false&remount-hook=${remountHook}\n";
      # The lower store: the host daemon over vsock (§2.2).
      systemd.sockets.nix-lower = {
        wantedBy = [ "sockets.target" ];
        listenStreams = [ lowerSocket ];
        socketConfig = {
          SocketMode = "0600";
          Accept = true;
        };
      };
      systemd.services = {
        nix-daemon = {
          environment.NIX_USER_CONF_FILES = "/etc/${storeConf}";
          restartTriggers = [ config.environment.etc.${storeConf}.source ];
          requires = [ "nix-lower.socket" ];
          after = [ "nix-lower.socket" ];
        };
        "nix-lower@" = {
          description = "Host nix-daemon over vsock";
          serviceConfig = {
            ExecStart = "${pkgs.socat}/bin/socat STDIO VSOCK-CONNECT:2:${lowerPort}";
            StandardInput = "socket";
            StandardOutput = "socket";
            StandardError = "journal";
          };
        };
        # §2.3: the host-side closure of the guest's roots and upper paths, for the host
        # to keep as GC roots.
        nix-store-roots-export = export.work // {
          description = "Export the host paths this guest depends on";
          path = [ nix ];
          wants = [ "nix-daemon.socket" ];
          after = [ "nix-daemon.socket" ];
          unitConfig.RequiresMountsFor = [
            "/cache"
            rwStore
          ];
          serviceConfig = {
            Type = "oneshot";
            TimeoutStartSec = "5min";
            ExecStart = "${prog}/bin/nix-persistent-store export ${args}";
          };
        };
        # §2.6: repair what the guest depends on, give up on what no substituter has, drop
        # stale rows.
        nix-store-reconcile = reconcile.work // {
          description = "Repair the paths this guest depends on and drop stale rows";
          path = [ nix ];
          wants = [ "nix-daemon.socket" ];
          after = [ "nix-daemon.socket" ];
          unitConfig.RequiresMountsFor = [ rwStore ];
          serviceConfig = {
            Type = "oneshot";
            TimeoutStartSec = "6h";
            ExecStart = "${prog}/bin/nix-persistent-store reconcile ${args}";
          };
        };
      }
      // export.units
      // reconcile.units;
      systemd.timers = {
        nix-store-roots-export = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "1min";
            OnUnitActiveSec = "1min";
          };
        };
        # The boot delay lets the network come up: wait-online is off fleet-wide.
        nix-store-reconcile = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "5min";
            OnUnitInactiveSec = "15min";
          };
        };
      };
    };

  # §2.2: one listener per host with a persistent-store guest.
  hostListener =
    { systemd }:
    {
      boot.kernelModules = [ "vhost_vsock" ];
      systemd.sockets.microvm-nix-lower = {
        wantedBy = [ "sockets.target" ];
        listenStreams = [ "vsock::${lowerPort}" ];
      };
      # The host daemon sees an untrusted user.
      systemd.services.microvm-nix-lower = {
        description = "Host nix-daemon for persistent-store guests, over vsock";
        requires = [ "microvm-nix-lower.socket" ];
        after = [ "microvm-nix-lower.socket" ];
        serviceConfig = {
          ExecStart = "${systemd}/lib/systemd/systemd-socket-proxyd ${hostDaemonSocket}";
          DynamicUser = true;
        };
      };
    };

  # §2.4, §2.8: per persistent-store guest, on its host.
  hostUnits =
    {
      pkgs,
      systemd,
      name,
      image,
      size,
      cacheDir,
      maxExportPaths,
    }:
    let
      unit = "microvm-store-roots@${name}";
      v = verdicts { inherit pkgs systemd; } unit;
      prog = pkgs.writers.writePython3Bin "microvm-store-roots-import" { flakeIgnore = [ "E501" ]; } (
        builtins.readFile ./_store-roots-import.py
      );
      # microvm.nix creates a volume only when its image is missing, so a raised `size`
      # grows the image here; it never shrinks (an `epoch` bump does that).
      grow = pkgs.writeShellApplication {
        name = "microvm-store-grow-${name}";
        runtimeInputs = [
          pkgs.coreutils
          pkgs.e2fsprogs
        ];
        text = ''
          img=${lib.escapeShellArg image}
          [ -e "$img" ] || exit 0
          [ "$(stat -c %s "$img")" -lt ${toString (size * 1024 * 1024)} ] || exit 0
          truncate -s '>${toString size}M' "$img"
          e2fsck -fp "$img" || [ "$?" -le 1 ]
          resize2fs "$img"
        '';
      };
    in
    {
      services = {
        "microvm@${name}" = {
          wants = [ "microvm-nix-lower.socket" ];
          after = [ "microvm-nix-lower.socket" ];
          # An epoch bump restarts the guest onto the new image before the sweep runs.
          restartTriggers = [ image ];
          serviceConfig.ExecStartPre = [ "${grow}/bin/microvm-store-grow-${name}" ];
        };
        ${unit} = v.work // {
          description = "Apply ${name}'s store export as host GC roots";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = false;
            # Waits on the host GC lock; a long GC delays the import, never fails it.
            TimeoutStartSec = "infinity";
            ExecStart = "${prog}/bin/microvm-store-roots-import ${
              lib.escapeShellArgs [
                "--guest"
                name
                "--state-dir"
                cacheDir
                "--roots-dir"
                rootsDir
                "--store-dir"
                builtins.storeDir
                "--gc-lock"
                "/nix/var/nix/gc.lock"
                "--max-paths"
                (toString maxExportPaths)
              ]
            }";
          };
        };
        nix-gc = {
          wants = [ "${unit}.service" ];
          after = [ "${unit}.service" ];
        };
      }
      // v.units;
      paths.${unit} = {
        wantedBy = [ "paths.target" ];
        pathConfig.PathChanged = "${cacheDir}/${exportRel}";
      };
      timers.${unit} = {
        wantedBy = [ "timers.target" ];
        timerConfig.OnCalendar = "*:0/15";
      };
    };

  # A failing oneshot that outlives a retry (§2.8): `unit`'s OnFailure= starts
  # <unit>-verdict, which stays failed, so NodeSystemdServiceFailed keeps firing while a
  # retry is still activating; OnSuccess= starts <unit>-verdict-clear, which resets it.
  # An instance name (`a@b`) keeps the instance: a-verdict@b.
  verdicts =
    { pkgs, systemd }:
    unit:
    let
      at = lib.splitString "@" unit;
      named = s: if lib.length at == 2 then "${lib.head at}-${s}@${lib.last at}" else "${unit}-${s}";
    in
    {
      work = {
        onFailure = [ "${named "verdict"}.service" ];
        onSuccess = [ "${named "verdict-clear"}.service" ];
      };
      units = {
        ${named "verdict"} = {
          description = "${unit} failed (cleared by its next success)";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.coreutils}/bin/false";
          };
        };
        ${named "verdict-clear"} = {
          description = "${unit} succeeded";
          serviceConfig = {
            Type = "oneshot";
            # A verdict that never failed is not loaded; that is not an error.
            ExecStart = "-${systemd}/bin/systemctl reset-failed ${named "verdict"}.service";
          };
        };
      };
    };

  # §2.4: delete every image under scratchRoot and every root set under rootsDir that the
  # keep-set does not name. Runs at boot and on every keep-set change (RemainAfterExit, so
  # switch-to-configuration restarts it), after every guest so an image a guest restart
  # replaced is no longer open; and daily, so a removed guest that stopped since is cleaned
  # without a reboot.
  sweep =
    {
      pkgs,
      systemd,
      scratchRoot,
      keepImages,
      keepRoots,
      configured,
    }:
    let
      prog = pkgs.writers.writePython3Bin "microvm-store-sweep" { flakeIgnore = [ "E501" ]; } (
        builtins.readFile ./_store-sweep.py
      );
      keepSet = {
        images = keepImages;
        roots = keepRoots;
        inherit configured;
      };
      args = lib.escapeShellArgs (
        [
          "--scratch-root"
          scratchRoot
          "--roots-dir"
          rootsDir
        ]
        ++ lib.concatMap (i: [
          "--keep-image"
          i
        ]) keepImages
        ++ lib.concatMap (r: [
          "--keep-roots"
          r
        ]) keepRoots
        ++ lib.concatMap (c: [
          "--configured"
          c
        ]) configured
      );
      unit = {
        description = "Delete microvm images and root sets the configuration no longer names";
        path = [ systemd ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${prog}/bin/microvm-store-sweep ${args}";
        };
      };
      periodic = verdicts { inherit pkgs systemd; } "microvm-store-sweep-periodic";
    in
    {
      services = {
        microvm-store-sweep = lib.recursiveUpdate unit {
          wantedBy = [ "multi-user.target" ];
          after = map (n: "microvm@${n}.service") configured;
          restartTriggers = [ (builtins.toJSON keepSet) ];
          serviceConfig.RemainAfterExit = true;
        };
        microvm-store-sweep-periodic = unit // periodic.work;
      }
      // periodic.units;
      timers.microvm-store-sweep-periodic = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = "daily";
          Persistent = true;
        };
      };
    };
}
