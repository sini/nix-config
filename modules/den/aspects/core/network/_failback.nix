# The failback timer (docs/dns-resolver.md §2.4): resolved keeps a link on the
# gateway after a failover (measured 2026-11-10: one SERVFAIL from Blocky moved
# cortex's br0 there and it stayed). When the link's first server answers `probe`
# again, restart resolved; re-setting the same list with `resolvectl dns` does not
# move the current server back (measured), a restart does.
# The link and its servers are read at runtime: den holds no LAN-link name.
{ pkgs, systemd }:
probe: {
  service = {
    description = "Return the LAN link to its first DNS server";
    after = [ "systemd-resolved.service" ];
    environment.DNS_FAILBACK_PROBE = probe;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.lib.getExe (
        pkgs.writeShellApplication {
          name = "dns-failback";
          runtimeInputs = [
            systemd
            pkgs.dnsutils
            pkgs.iproute2
            pkgs.gawk
            pkgs.gnugrep
          ];
          text = ''
            link=$(ip -o route show default | awk '{print $5; exit}')
            [ -n "$link" ] || exit 0 # no default route yet
            # "Link 2 (br0): 10.10.10.1 10.9.0.1"
            first=$(resolvectl dns "$link" | awk '{print $4}')
            current=$(resolvectl status "$link" | awk '/Current DNS Server:/ {print $NF}')
            [ -n "$first" ] && [ -n "$current" ] && [ "$current" != "$first" ] || exit 0
            # Asked directly, so the probe needs nothing of resolved's state.
            answer=$(dig +time=2 +tries=1 @"$first" "$DNS_FAILBACK_PROBE" A) || exit 0
            grep -q 'status: NOERROR' <<<"$answer" && grep -q 'ANSWER: [1-9]' <<<"$answer" || exit 0
            echo "dns-failback: $link on $current; $first answers $DNS_FAILBACK_PROBE; restarting systemd-resolved"
            systemctl restart systemd-resolved
          '';
        }
      );
    };
  };
  timer = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "1min";
    };
  };
}
