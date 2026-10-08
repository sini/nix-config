# Domain entities: one per zone or sub-zone, composed from aspects
# (modules/den/aspects/domain/). A domain has no owning environment: records
# from every environment route to the zone that contains them
# (modules/den/policies/domains.nix, modules/flake-parts/terranix/dns.nix).
{
  lib,
  inputs,
  den,
  ...
}:
let
  schemaLib = (inputs.gen.lib.mkGenLibs { }).schema;
in
{
  options.den.domains = schemaLib.mkInstanceRegistry {
    description = "Domains (zones and sub-zones) by FQDN, composed from aspects";
  } den.schema.domain;

  config = {
    den.schema.domain.isEntity = true;

    den.schema.domain.imports = [
      (_: {
        options.includes = lib.mkOption {
          type = lib.types.listOf lib.types.raw;
          default = [ ];
          description = "Aspects composing this domain (dns.cloudflare, tls.dns01, web.landing, ...)";
        };
      })
    ];
  };
}
