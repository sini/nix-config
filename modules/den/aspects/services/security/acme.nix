{ lib, ... }:
{
  den.aspects.services.security.acme = {
    nixos =
      {
        config,
        environment,
        host,
        ...
      }:
      let
        # Extract top-level domain from the host's FQDN
        fqdnParts = lib.splitString "." config.networking.fqdn;
        topDomain = lib.concatStringsSep "." (lib.reverseList (lib.take 2 (lib.reverseList fqdnParts)));
      in
      {
        security.acme = {
          acceptTerms = true;
          defaults = {
            email = (environment.email or { }).adminEmail or "admin@${topDomain}";
            inherit ((environment.acme or { })) dnsProvider;
            inherit ((environment.acme or { })) dnsResolver;
            dnsPropagationCheck = true;
            credentialFiles =
              let
                domainConfig = (environment.certificates.domains or { }).${topDomain} or null;
                issuerName = if domainConfig != null then domainConfig.issuer else null;
              in
              lib.optionalAttrs (issuerName != null) {
                CLOUDFLARE_DNS_API_TOKEN_FILE = config.age.secrets."${issuerName}-cloudflare-api-key".path;
              };
          };

          certs.${config.networking.fqdn} = {
            extraDomainNames = [ "*.${config.networking.fqdn}" ];
          };
        };
      };

    age-secrets =
      { environment, host, ... }:
      let
        issuers = environment.certificates.issuers or { };
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
