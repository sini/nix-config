# Settings for the romm aspect. Surfaced onto the cluster as
# `cluster.settings.kubernetes.services.media.romm.*`; set per cluster via
# `den.clusters.<name>.settings.kubernetes.services.media.romm.<key>`.
{ lib, ... }:
{
  # SCAN_TIMEOUT — wall-clock cap on a single background scan/rescan job. RomM's
  # scan is ONE low-prio RQ job; when this elapses the job is killed mid-flight.
  # A normal (non-"complete") rescan is additive (already-identified ROMs are
  # skipped), so the library still converges across repeated runs — but a large
  # first-pass scan (~100k ROMs) wants a single long window. Upstream default
  # 14400 (4h).
  den.aspects.kubernetes.services.media.romm.settings.scanTimeout = lib.mkOption {
    type = lib.types.ints.positive;
    default = 14400; # 4h — RomM upstream default
    description = ''
      Timeout (seconds) for RomM's background scan/rescan job (SCAN_TIMEOUT).
      The scan runs as a single RQ job and is terminated when this elapses, so
      raise it for a large first-pass scan. Non-complete rescans are additive, so
      the library still converges across runs.
    '';
  };

  # SCAN_WORKERS — RomM bounds concurrent per-ROM identification with an
  # asyncio.Semaphore(SCAN_WORKERS) inside the single scan job (backend/endpoints/
  # sockets/scan.py). This is I/O concurrency over the metadata-provider round
  # trips (Hasheous / IGDB / SteamGridDB / RetroAchievements), NOT OS processes —
  # so it is the real throughput lever for a network-bound scan. Default 1 = fully
  # serial (one ROM at a time). Ceiling is set by provider rate limits (IGDB
  # ~4 req/s); Hasheous hash-matching is the fast bulk path.
  den.aspects.kubernetes.services.media.romm.settings.scanWorkers = lib.mkOption {
    type = lib.types.ints.positive;
    default = 1; # RomM upstream default (serial)
    description = ''
      Concurrent per-ROM identifications within a scan job (SCAN_WORKERS). This is
      asyncio concurrency over metadata-provider I/O, not OS processes — the
      primary lever for scan throughput. Bounded by provider rate limits.
    '';
  };

  # Deployment replica count. NOTE: replicas do NOT speed a single scan — a scan
  # is one RQ job run by one worker (intra-job concurrency is SCAN_WORKERS above).
  # Extra replicas only add web/API + RQ-worker capacity for *other* jobs. Also:
  # the userdata PVC (romm-userdata) is ReadWriteOnce longhorn, so replicas > 1
  # scheduled across nodes cannot co-mount it — bumping this first needs an RWX
  # userdata volume (or same-node affinity). Kept at 1.
  den.aspects.kubernetes.services.media.romm.settings.replicas = lib.mkOption {
    type = lib.types.ints.positive;
    default = 1;
    description = ''
      RomM Deployment replica count. Does not accelerate a single scan (that is
      SCAN_WORKERS); only adds capacity for concurrent web/API and other RQ jobs.
      Replicas > 1 require an RWX userdata volume — the current romm-userdata PVC
      is ReadWriteOnce.
    '';
  };
}
