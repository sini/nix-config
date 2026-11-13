# An external vantage host

Status: **accepted v0.2** (2026-11-12). Nothing is ordered or built.

## 1. Summary

One small NixOS VM at a cloud provider, outside the home network: the fleet's
first off-site den host. It answers what nothing inside the LAN can, namely how
the fleet looks from the internet. Today that view is the owner's phone on
cellular, which is manual and not repeatable.

## 2. What it is for

1. **Public reachability checks.** Probe the public names (through Cloudflare
   and direct to the WAN), the port forwards, and later the stage 2 public IPv6
   addresses (`docs/public-ipv6-services.md`).
2. **IPv6 from outside.** The stage 2 live test needs a vantage with working
   IPv6 that is not on our prefix. Most providers give each VM a native /64.
3. **Outside-in monitoring.** A Prometheus `blackbox_exporter` on the VM, its
   results scraped or pushed into the cluster's existing monitoring, so "the
   site is down from outside" becomes an alert instead of a report.
4. **Later, optional:** an off-site restic or Garage replica target, a second
   headscale DERP relay, or an off-site DNS secondary. None of these is part of
   this proposal.

## 3. Proposal

- **Size:** the provider's smallest shared VM. One vCPU, 2 GB RAM and 20 GB disk
  are plenty for probes and an exporter.
- **Provider:** one with native IPv6, NixOS installable through `nixos-anywhere`
  (or a NixOS image), and a stable public IPv4 and IPv6. Hetzner Cloud is the
  usual fit: native IPv6 /64, cheap, and EU or US locations. A US location
  (Ashburn or Hillsboro) is closer to Sonic. Price and region are to be
  confirmed at order time. I have not checked current prices.
- **In den:**
  - a host file like the others, in a new environment `edge`, so it gets no LAN
    assumptions, no DHCP reservation and no `served-domains`;
  - managed over the tailnet (headscale on uplink), with SSH from the public
    internet closed, and deployed with colmena like any host;
  - its agenix host key from `nix-flake-provision-keys`;
  - aspects: base and security, tailscale and `blackbox_exporter`; nothing else.
- **Monitoring path:** the exporter listens on the tailnet only, and Prometheus
  scrapes it through the existing scrape-target quirks. No new ingress on the
  cluster.

## 4. Costs and risks

- **Money:** a recurring monthly charge. It's the owner's decision.
- **A public host to keep patched.** It runs the same channel and deploy cadence
  as the rest, with no public listening services except what a probe needs.
- **Secrets off-site:** its host key, and the tailnet join key at install. No
  cluster or DNS credential lives on it.
- **One vantage is one view.** A provider-side outage reads as our outage, so
  alerts should require the probe itself to be healthy.

## 5. Decisions for the owner

1. Approve a recurring VM at all?
2. Provider and region (Hetzner US is my default)?
3. Environment name `edge`, or fold it into `prod`?

Once approved: the owner orders the VM and gives its address. Then the host
file, the install (`nixos-anywhere`), the tailnet join and the probes land as
code, and the stage 2 live test runs from it.

## 6. Owner decisions (2026-11-12)

1. Provider: Hetzner Cloud. The owner picks the size and region from current
   specs.
2. Environment: a new `edge` environment.
3. Install: the owner will oversee a redesign of the repo's nixos-anywhere
   integration first; this host waits on that.
