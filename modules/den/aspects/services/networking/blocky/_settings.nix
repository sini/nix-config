# The one Blocky definition (docs/dns-resolver.md §2.2): instance inputs to
# Blocky's settings attrset. Each instance supplies only its listen addresses,
# its CoreDNS address and its list cache directory.
{ lib }:
let
  # resolved's "address#tls-name" to Blocky's DoT form, "tcp-tls:<ip>:853#<tls-name>".
  toBlockyUpstream =
    server:
    let
      parts = lib.splitString "#" server;
      ip = lib.head parts;
      host = if lib.hasInfix ":" ip then "[${ip}]" else ip;
    in
    "tcp-tls:${host}:853" + lib.optionalString (lib.length parts > 1) "#${lib.last parts}";
in
{
  upstreams,
  internalNames,
  internalResolver,
  tailnetDomain,
  cachePath,
  filter,
  dnsListen,
  httpListen,
}:
{
  upstreams = {
    strategy = "parallel_best";
    init.strategy = "fast";
    groups.default = map toBlockyUpstream upstreams;
  };
  # Unset, Blocky falls back to the OS resolver, which on a resolver host is Blocky itself.
  bootstrapDns = [ (toBlockyUpstream (lib.head upstreams)) ];
  conditional.mapping = lib.genAttrs internalNames (_: internalResolver) // {
    ${tailnetDomain} = "100.100.100.100";
  };
  blocking = {
    denylists.default = filter.denylists;
  }
  # An empty inline list renders "" and Blocky loads it as a file path.
  // lib.optionalAttrs (filter.allowlist != [ ]) {
    allowlists.default = [ (lib.concatLines filter.allowlist) ];
  }
  // {
    clientGroupsBlock.default = [ "default" ];
    # A positive answer, so a racing resolver's public answer can't displace it.
    blockType = "zeroIp";
    blockTTL = "1m";
    loading = {
      refreshPeriod = "4h";
      strategy = "fast";
      maxErrorsPerSource = 5;
      downloads = {
        inherit cachePath;
        # Per attempt, body read included; the 5s default truncates a multi-MB list on a slow WAN.
        timeout = "60s";
      };
    };
  };
  caching.prefetching = true;
  queryLog.type = "console";
  prometheus.enable = true;
  ports = {
    dns = dnsListen;
    http = httpListen;
  };
}
