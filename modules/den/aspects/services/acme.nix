{
  den,
  lib,
  ...
}:
{
  den.aspects.acme = {
    includes = lib.attrValues den.aspects.acme._;

    _ = {
      config = den.lib.perHost (
        { host }:
        {
          nixos =
            { config, ... }:
            let
              fqdnParts = lib.splitString "." config.networking.fqdn;
              topDomain = lib.concatStringsSep "." (lib.reverseList (lib.take 2 (lib.reverseList fqdnParts)));
              domainConfig = (host.environment.certificates.domains or { }).${topDomain} or null;
              issuerName = if domainConfig != null then domainConfig.issuer else null;
            in
            {
              security.acme = {
                acceptTerms = true;
                defaults = {
                  email = host.environment.email.adminEmail;
                  inherit (host.environment.acme) dnsProvider;
                  inherit (host.environment.acme) dnsResolver;
                  dnsPropagationCheck = true;
                  credentialFiles = {
                    CLOUDFLARE_DNS_API_TOKEN_FILE = config.age.secrets."${issuerName}-cloudflare-api-key".path;
                  };
                };

                certs.${config.networking.fqdn} = {
                  extraDomainNames = [ "*.${config.networking.fqdn}" ];
                };
              };
            };
        }
      );

      secrets = den.lib.perHost (
        { host }:
        {
          secrets = lib.listToAttrs (
            lib.flatten (
              lib.mapAttrsToList (
                issuerName: issuerConfig:
                lib.optional (issuerConfig.ageKeyFile != null) {
                  name = "${issuerName}-cloudflare-api-key";
                  value = {
                    rekeyFile = issuerConfig.ageKeyFile;
                  };
                }
              ) (host.environment.certificates.issuers or { })
            )
          );
        }
      );

      impermanence = den.lib.perHost {
        persist.directories = [
          {
            directory = "/var/lib/acme";
            user = "acme";
            group = "acme";
            mode = "0755";
          }
        ];
      };
    };
  };
}
