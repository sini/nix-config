# Helpers for microvm-guests.nix: the host-wide store sweep, and the verdict units the
# timer-driven ones report through. docs/microvm-persistent-store.md.
{ lib }:
rec {
  # The host's permanent GC roots for persistent-store guests, one directory per guest.
  rootsDir = "/nix/var/nix/gcroots/microvm-store";

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
