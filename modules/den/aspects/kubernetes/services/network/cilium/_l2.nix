# The Service label that puts a LoadBalancer on the LAN pool and its L2 (ARP)
# announcement, and keeps it out of the BGP advertisement (cilium.nix,
# cilium-bgp-resources.nix; docs/dns-resolver.md §2.7).
{
  "lan.json64.dev/l2-announce" = "true";
}
