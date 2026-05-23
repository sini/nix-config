{
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
      let
        env = environments.${host.environment} or { };
        issuers = env.certificates.issuers or { };
      in
      {
        age.secrets = lib.mkMerge (
          lib.mapAttrsToList (
            issuerName: issuer:
            lib.optionalAttrs (issuer.ageKeyFile or null != null) {
              "${issuerName}-cloudflare-api-key" = {
                rekeyFile = issuer.ageKeyFile;
              };
            }
          ) issuers
        );
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
