{
  den,
  lib,
  config,
  ...
}:
let
  environments = config.den.environments;
in
{
  den.aspects.services.acme = {
    nixos =
      { config, host, ... }:
      let
        # Extract top-level domain from the host's FQDN
        fqdnParts = lib.splitString "." config.networking.fqdn;
        topDomain = lib.concatStringsSep "." (lib.reverseList (lib.take 2 (lib.reverseList fqdnParts)));

        # Look up the issuer for this domain via environment certificates config
        env = environments.${host.environment} or { };
        domainConfig = (env.certificates.domains or { }).${topDomain} or null;
        issuerName = if domainConfig != null then domainConfig.issuer else null;
      in
      {
        security.acme = {
          acceptTerms = true;
          defaults = {
            email = (env.email or { }).adminEmail or "admin@${topDomain}";
            dnsProvider = (env.acme or { }).dnsProvider or "cloudflare";
            dnsResolver = (env.acme or { }).dnsResolver or "1.1.1.1:53";
            dnsPropagationCheck = true;
          };

          certs.${config.networking.fqdn} = {
            extraDomainNames = [ "*.${config.networking.fqdn}" ];
          };
        };
      };

    age-secrets =
      { host, ... }:
      {
        # Secret declarations for ACME cloudflare API keys
        # Wired per-issuer once environment ref + certificates config is available
        age.secrets = { };
      };

    persist = {
      directories = [
        {
          directory = "/var/lib/acme";
          user = "acme";
          group = "acme";
          mode = "0755";
        }
      ];
    };
  };
}
