# The failback timer's VM test (docs/dns-resolver.md §2.4, test 5), on cortex's
# nixpkgs and the shared unit (_failback.nix): two resolvers and two clients
# that list them in order. Stopping the first and querying moves each client to
# the second; once the first is back, the timer returns `client` to it, and the
# control (`control`, the timer disabled) stays on the second.
#   nix build .#checks.x86_64-linux.dns-failback-vm
{ config, lib, ... }:
let
  nixos = config.flake.nixosConfigurations.cortex;
  inherit (nixos) pkgs;
  probe = "probe.test";

  resolverNode = {
    services.dnsmasq = {
      enable = true;
      resolveLocalQueries = false;
      settings = {
        no-resolv = true;
        # Both families: a REFUSED AAAA would itself rotate the client.
        address = [
          "/${probe}/192.0.2.10"
          "/${probe}/2001:db8::10"
        ];
      };
    };
    networking.firewall.allowedUDPPorts = [ 53 ];
  };

  clientNode =
    timer:
    { config, nodes, ... }:
    let
      failback = import ./_failback.nix {
        inherit pkgs;
        systemd = config.systemd.package;
      } probe;
      ip = n: n.networking.primaryIPAddress;
    in
    {
      networking.useNetworkd = true;
      services.resolved.enable = true;
      # The test framework's eth1 network; the default route gives the script its link.
      systemd.network.networks."40-eth1" = {
        dns = [
          (ip nodes.r1)
          (ip nodes.r2)
        ];
        gateway = [ (ip nodes.r2) ];
      };
      environment.systemPackages = [ pkgs.dnsutils ];
      systemd.services.dns-failback = failback.service;
      systemd.timers.dns-failback = failback.timer // {
        enable = timer;
        timerConfig = {
          OnBootSec = "5s";
          OnUnitActiveSec = "5s";
          AccuracySec = "1s";
        };
      };
    };
in
{
  perSystem =
    { system, ... }:
    {
      checks = lib.optionalAttrs (system == pkgs.stdenv.hostPlatform.system) {
        dns-failback-vm = pkgs.testers.runNixOSTest {
          name = "dns-failback";
          nodes = {
            r1 = resolverNode;
            r2 = resolverNode;
            client = clientNode true;
            control = clientNode false;
          };
          testScript =
            { nodes, ... }:
            let
              r1 = nodes.r1.networking.primaryIPAddress;
              r2 = nodes.r2.networking.primaryIPAddress;
            in
            ''
              import time

              def current(m):
                  return m.succeed("resolvectl status eth1 | awk '/Current DNS Server:/ {print $NF}'").strip()

              def restarts(m):
                  return int(m.succeed("journalctl -u dns-failback | grep -c 'restarting systemd-resolved' || true").strip())

              start_all()
              for r in (r1, r2):
                  r.wait_for_unit("dnsmasq.service")
              clients = (client, control)
              for m in clients:
                  m.wait_for_unit("systemd-resolved.service")
                  # A boot-time query may have rotated before r1 answered: start from the first.
                  m.succeed("systemctl restart systemd-resolved")
                  m.wait_until_succeeds("resolvectl query --cache=no ${probe}")
                  assert current(m) == "${r1}", current(m)

              before = restarts(client)

              # Force the rotation: the first resolver stops answering.
              r1.succeed("systemctl stop dnsmasq")
              for m in clients:
                  m.wait_until_succeeds("resolvectl query --cache=no ${probe}", timeout=60)
                  assert current(m) == "${r2}", current(m)
              # While the first is down, the timer leaves the link alone.
              time.sleep(15)
              assert current(client) == "${r2}", current(client)
              assert restarts(client) == before, "restarted while the first was down"

              r1.succeed("systemctl start dnsmasq")
              r1.wait_for_unit("dnsmasq.service")
              client.wait_until_succeeds("resolvectl status eth1 | grep -q 'Current DNS Server: ${r1}$'", timeout=60)
              assert restarts(client) > before, "the link moved back without the timer"
              client.succeed("resolvectl query --cache=no ${probe}")

              # Control: without the timer the link stays on the second resolver.
              time.sleep(20)
              assert current(control) == "${r2}", current(control)
              control.succeed("resolvectl query --cache=no ${probe}")
              assert current(control) == "${r2}", current(control)
            '';
        };
      };
    };
}
