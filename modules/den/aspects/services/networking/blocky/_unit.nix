# The blocky unit's restart guard (docs/dns-resolver.md §2.2). On a boot where
# the LAN link has no carrier, the address arrives late and Blocky's bind fails
# with EADDRNOTAVAIL; the default 100 ms restarts would hit the start limit and
# leave it dead. It retries every 2 s, without limit, until the address appears.
{
  startLimitIntervalSec = 0;
  serviceConfig.RestartSec = "2s";
}
