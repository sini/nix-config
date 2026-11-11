# The address plan (docs/address-plan.md §2): the site ULA, the /56 subnet-id
# rule and host tokens. Pure; den never holds the delegated prefix, so a GUA
# slice is its subnet id alone.
{ lib }:
let
  # RFC 4193 §3.2: a 40-bit global ID, here sha256 over prod's domain and name in
  # place of the RFC's time-and-EUI-64 seed. It was prod's ULA before it was the
  # site's, and is kept so Blocky's ::53 does not move.
  globalId = builtins.substring 0 10 (builtins.hashString "sha256" "json64.dev/prod");
  hex = from: len: builtins.substring from len globalId;
  ulaHead = "fd${hex 0 2}:${hex 2 4}:${hex 6 4}";

  octetsOf =
    ip:
    let
      o = lib.splitString "." ip;
    in
    if lib.length o == 4 && lib.all (x: builtins.match "0|[1-9][0-9]{0,2}" x != null && lib.toInt x < 256) o then
      o
    else
      throw "address-plan: ${ip} is not a dotted-quad IPv4 address";
  ipToInt = ip: lib.foldl' (acc: o: acc * 256 + lib.toInt o) 0 (octetsOf ip);
in
rec {
  # The site's ULA /48; subnet 00ss mirrors the GUA subnet id s.
  ula = "${ulaHead}::/48";

  # P, the low nibble of the subnet id.
  purposes = {
    lan = 0;
    lb = 1;
    cluster = 2;
  };

  # The /56 subnet id s = E·16 + P, E the environment's declared nibble.
  subnetId =
    nibble: purpose:
    if !(builtins.isInt nibble && nibble >= 0 && nibble <= 15) then
      throw "address-plan: environment nibble ${toString nibble} is not 0-15"
    else if !(builtins.isInt purpose && purpose >= 0 && purpose <= 15) then
      throw "address-plan: purpose ${toString purpose} is not 0-15"
    else
      nibble * 16 + purpose;

  # s as the controller's ipv6_pd_prefixid and as a group: lowercase hex, unpadded.
  subnetHex = s: lib.toLower (lib.toHexString s);

  # The cluster slice (P = 2) of an environment's site ULA, as its four leading
  # groups: pods, services and fabric loopbacks are carved from it.
  clusterUla = nibble: "${ulaHead}:${subnetHex (subnetId nibble purposes.cluster)}";

  # The site ULA's /64 with subnet id s, compressed (subnet 0 is ${ulaHead}::/64).
  ulaSubnet = s: if s == 0 then "${ulaHead}::/64" else "${ulaHead}:${subnetHex s}::/64";

  # A host's interface identifier on a LAN: its IPv4 there, each decimal octet
  # written as one group (10.10.10.1 -> ::10:10:10:1).
  tokenOf = ip: "::" + lib.concatStringsSep ":" (octetsOf ip);

  # The address a token takes in a /64 (prefix length kept).
  addressIn =
    cidr: token:
    let
      p = lib.network.ipv6.fromString cidr;
    in
    if p.prefixLength != 64 then
      throw "address-plan: ${cidr} is not a /64"
    else
      lib.concatStringsSep ":" (lib.take 4 (lib.splitString ":" p.address))
      + ":${lib.removePrefix "::" token}/64";

  # Whether an IPv4 address (no prefix) lies in an IPv4 CIDR.
  ipv4InCidr =
    cidr: ip:
    let
      parts = lib.splitString "/" cidr;
      size = lib.foldl' (acc: _: acc * 2) 1 (lib.range 1 (32 - lib.toInt (lib.last parts)));
    in
    ipToInt ip / size == ipToInt (lib.head parts) / size;
}
