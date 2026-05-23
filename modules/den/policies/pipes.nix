# Pipe collection policies for cross-host discovery.
#
# Declares collection policies for host-addrs and bgp-peers quirks,
# wired into host schema so every host collects pipe entries from peers.
{ den, ... }:
let
  inherit (den.lib.policy) pipe;
in
{
  den.policies.collect-host-addrs = _: [
    (pipe.from "host-addrs" [
      (pipe.collect (_: true))
    ])
  ];

  den.policies.collect-bgp-peers = _: [
    (pipe.from "bgp-peers" [
      (pipe.collect (_: true))
    ])
  ];

  den.schema.host.includes = [
    den.policies.collect-host-addrs
    den.policies.collect-bgp-peers
  ];
}
