# Domain resolution: fleet -> top-level domains -> their sub-zones.
#
# A domain's parent is its nearest proper ancestor among den.domains
# (dev.json64.dev nests under json64.dev); a domain with none resolves at the
# fleet, beside the environments, since no environment owns a zone.
{
  lib,
  den,
  config,
  ...
}:
let
  inherit (den.lib.policy) resolve;
  inherit (import ../domains/_lib.nix { inherit lib; }) parentOf;

  domains = config.den.domains;
  names = builtins.attrNames domains;
  childrenOf = parent: builtins.filter (n: parentOf names n == parent) names;
  resolveDomain = n: resolve.to "domain" { domain = domains.${n}; };
in
{
  den.policies.fleet-to-domains = { fleet, ... }: map resolveDomain (childrenOf null);

  den.policies.domain-to-subdomains = { domain, ... }: map resolveDomain (childrenOf domain.name);

  den.schema.fleet.includes = [ den.policies.fleet-to-domains ];
  den.schema.domain.includes = [ den.policies.domain-to-subdomains ];
}
