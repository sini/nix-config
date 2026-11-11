# The resolver's VM tests (docs/dns-resolver.md §3), on uplink's nixpkgs and the
# shared definition (_settings.nix, _unit.nix):
#   blocky-boot   test 5: the LAN address arrives after Blocky's first start; with
#                 the restart guard it recovers (NRestarts >= 1), and the control
#                 without it ends failed with start-limit-hit
#   blocky-lists-vm  test 9: a fresh download loads and is cached; a 404 is not
#                 served from the cache (the fresh-download control); a truncated
#                 body shrinks the group below half, a whole one does not; a dead
#                 URL never stops startup; an empty allowlist logs nothing, and
#                 the forced "" control logs `could not init allowlist`
#   nix build .#checks.x86_64-linux.blocky-boot .#checks.x86_64-linux.blocky-lists-vm
{ config, lib, ... }:
let
  nixos = config.flake.nixosConfigurations.uplink;
  inherit (nixos) pkgs;
  render = import ./_settings.nix { inherit lib; };
  base = {
    upstreams = [ "192.0.2.1#resolver.invalid" ];
    internalNames = [ ];
    internalResolver = "192.0.2.53";
    tailnetDomain = "ts.invalid";
    cachePath = "/var/lib/blocky";
    filter = {
      denylists = [ ];
      allowlist = [ ];
    };
  };
  common = {
    environment.systemPackages = [
      pkgs.dnsutils
      pkgs.curl
    ];
  };

  bridgeAddress = "192.168.50.1";
  # br0 has no port at boot, so networkd holds its static address until a port gives it carrier.
  bootNode = guarded: {
    imports = [ common ];
    networking.useNetworkd = true;
    systemd.network = {
      netdevs."10-br0".netdevConfig = {
        Name = "br0";
        Kind = "bridge";
      };
      networks."10-br0" = {
        matchConfig.Name = "br0";
        address = [ "${bridgeAddress}/24" ];
      };
    };
    services.blocky = {
      enable = true;
      settings = render (
        base
        // {
          filter = base.filter // {
            denylists = [ "blocked.test\n" ];
          };
          dnsListen = [ "${bridgeAddress}:53" ];
          httpListen = [ "${bridgeAddress}:4000" ];
        }
      );
    };
    systemd.services.blocky = lib.mkIf guarded (import ./_unit.nix);
  };

  listPort = 8080;
  listUrl = "http://127.0.0.1:${toString listPort}/list.txt";
  listSize = 4000;
  listBody = pkgs.writeText "list.txt" (
    lib.concatMapStrings (i: "d${toString i}.test\n") (lib.range 1 listSize)
  );
  listsNode =
    {
      denylists,
      override ? { },
    }:
    {
      imports = [ common ];
      services.blocky = {
        enable = true;
        settings = lib.recursiveUpdate (render (
          base
          // {
            filter = base.filter // {
              inherit denylists;
            };
            dnsListen = [ "127.0.0.1:53" ];
            httpListen = [ "127.0.0.1:4000" ];
          }
        )) override;
      };
      systemd.services.blocky = import ./_unit.nix;
      systemd.services.list-server = {
        wantedBy = [ "multi-user.target" ];
        before = [ "blocky.service" ];
        preStart = "test -e /run/list-mode || echo whole > /run/list-mode";
        serviceConfig.ExecStart = "${lib.getExe pkgs.python3} -I ${./_list-server.py} ${listBody} /run/list-mode ${toString listPort}";
      };
    };

  helpers = ''
    import hashlib
    import re

    def metric(m, name):
        out = m.succeed("curl -sf http://127.0.0.1:4000/metrics")
        total = 0.0
        for line in out.splitlines():
            if re.match(name + r'(\{[^}]*group="default"[^}]*\})? ', line) or (
                name == "blocky_failed_downloads_total" and line.startswith(name)
            ):
                total += float(line.split()[-1])
        return total

    def invocation(m):
        return m.succeed("systemctl show -p InvocationID --value blocky").strip()

    def unit_log(m, inv):
        return m.succeed(f"journalctl -o cat _SYSTEMD_INVOCATION_ID={inv}")
  '';
in
{
  perSystem =
    { system, ... }:
    {
      checks = lib.optionalAttrs (system == pkgs.stdenv.hostPlatform.system) {
        blocky-boot = pkgs.testers.runNixOSTest {
          name = "blocky-boot";
          nodes = {
            guarded = bootNode true;
            unguarded = bootNode false;
          };
          testScript = ''
            import time

            start_all()
            for m in (guarded, unguarded):
                m.wait_for_unit("multi-user.target")
                m.wait_until_succeeds("journalctl -u blocky | grep -q 'cannot assign requested address'")

            # Control: without the guard the default restarts hit the start limit.
            unguarded.wait_until_succeeds("systemctl show -p Result --value blocky | grep -qx start-limit-hit")
            unguarded.succeed("systemctl show -p ActiveState --value blocky | grep -qx failed")

            for m in (guarded, unguarded):
                m.succeed("ip link add dummy0 type dummy && ip link set dummy0 master br0 && ip link set dummy0 up")
            added = time.monotonic()

            guarded.wait_until_succeeds(
                "dig +time=1 +tries=1 @${bridgeAddress} blocked.test | grep -q '0\\.0\\.0\\.0'", timeout=15
            )
            print(f"guarded answered {time.monotonic() - added:.1f}s after the port was added")
            guarded.succeed("systemctl show -p ActiveState --value blocky | grep -qx active")
            restarts = int(guarded.succeed("systemctl show -p NRestarts --value blocky").strip())
            assert restarts >= 1, f"NRestarts = {restarts}: the test did not hit the race"

            unguarded.wait_until_succeeds("ip -4 addr show br0 | grep -q ${bridgeAddress}")
            time.sleep(5)
            unguarded.succeed("systemctl show -p Result --value blocky | grep -qx start-limit-hit")
            unguarded.fail("dig +time=1 +tries=1 @${bridgeAddress} blocked.test")
          '';
        };

        blocky-lists-vm = pkgs.testers.runNixOSTest {
          name = "blocky-lists";
          nodes = {
            lists = listsNode { denylists = [ listUrl ]; };
            # A dead denylist URL, and the empty allowlist forced to [ "" ].
            dead = listsNode {
              denylists = [ "https://127.0.0.1:9/none.txt" ];
              override.blocking.allowlists.default = [ "" ];
            };
          };
          testScript = ''
            ${helpers}
            N = ${toString listSize}
            cache_file = "/var/lib/private/blocky/" + hashlib.sha256(b"${listUrl}").hexdigest()
            downloaded = "import succeeded count=${toString listSize} source=${listUrl}"

            start_all()

            # A fresh download: loaded, counted clean, logged by a refresh, and cached.
            lists.wait_for_unit("blocky.service")
            lists.wait_until_succeeds("curl -sf http://127.0.0.1:4000/metrics | grep -q '^blocky_denylist_cache_entries'")
            lists.wait_until_succeeds(f"curl -sf http://127.0.0.1:4000/metrics | grep -q 'blocky_denylist_cache_entries{{group=\"default\"}} {N}'")
            inv = invocation(lists)
            text = unit_log(lists, inv)
            assert "group import finished" in text and downloaded in text, text
            assert metric(lists, "blocky_failed_downloads_total") == 0
            lists.succeed(f"test -s {cache_file}")
            lists.succeed("dig +time=2 +tries=1 @127.0.0.1 d1.test | grep -q '0\\.0\\.0\\.0'")
            assert "could not init allowlist" not in text, "empty allowlist logged an init error"

            # A 404 is not served from the cache: seeded from disk, a failed download, no import.
            lists.succeed("echo 404 > /run/list-mode")
            lists.succeed("systemctl restart blocky")
            inv = invocation(lists)
            lists.wait_until_succeeds("curl -sf http://127.0.0.1:4000/metrics | grep -q '^blocky_failed_downloads_total'")
            lists.wait_until_succeeds(f"journalctl -o cat _SYSTEMD_INVOCATION_ID={inv} | grep -q 'Populating of group cache failed'")
            assert metric(lists, "blocky_denylist_cache_entries") > 0
            assert metric(lists, "blocky_failed_downloads_total") > 0
            text = unit_log(lists, inv)
            # The disk seed logs its own `import succeeded`, with the cache file as its source.
            assert "source=file://" + cache_file.replace("/private", "") in text, text
            assert "group import finished" not in text and downloaded not in text, text

            # A whole body twice does not shrink the group (the control), a truncated one does.
            lists.succeed("echo whole > /run/list-mode")
            lists.succeed("systemctl restart blocky")
            inv = invocation(lists)
            lists.wait_until_succeeds(f"journalctl -o cat _SYSTEMD_INVOCATION_ID={inv} | grep -c 'group import finished' | grep -qx 1")
            first = metric(lists, "blocky_denylist_cache_entries")
            assert first == N, first
            lists.succeed("curl -sf -X POST http://127.0.0.1:4000/api/lists/refresh")
            lists.wait_until_succeeds(f"journalctl -o cat _SYSTEMD_INVOCATION_ID={inv} | grep -c 'group import finished' | grep -qx 2")
            whole = metric(lists, "blocky_denylist_cache_entries")
            assert not (whole < 0.5 * max(first, whole)), whole
            lists.succeed("echo truncate > /run/list-mode")
            lists.succeed("curl -sf -X POST http://127.0.0.1:4000/api/lists/refresh")
            lists.wait_until_succeeds(f"journalctl -o cat _SYSTEMD_INVOCATION_ID={inv} | grep -c 'group import finished' | grep -qx 3")
            partial = metric(lists, "blocky_denylist_cache_entries")
            print(f"denylist entries: first {first}, whole {whole}, truncated {partial}")
            # BlockyDenylistShrunk's expression over the day's samples.
            assert 0 < partial < 0.5 * max(first, whole, partial), partial

            # A dead list never stops startup; the forced "" allowlist logs its init error.
            dead.wait_for_unit("blocky.service")
            dead.wait_until_succeeds("journalctl -u blocky | grep -q 'could not init allowlist'")
            dead.succeed("systemctl show -p ActiveState --value blocky | grep -qx active")
            dead.succeed("systemctl show -p NRestarts --value blocky | grep -qx 0")
            assert metric(dead, "blocky_denylist_cache_entries") == 0
            dead.succeed("dig +time=2 +tries=1 @127.0.0.1 example.test | grep -q 'status:'")
          '';
        };
      };
    };
}
