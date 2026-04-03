{
  den,
  config,
  lib,
  ...
}:
let
  allEnvironments = config.environments or { };
in
{
  den.aspects.acme = {
    includes = lib.attrValues den.aspects.acme._;

    _ = {
      config = den.lib.perHost (
        { host }:
        let
          envName = host.environment or "dev";
          environment = allEnvironments.${envName} or { };
        in
        {
          nixos =
            { config, ... }:
            let
              # Extract top-level domain from the host's FQDN
              fqdnParts = lib.splitString "." config.networking.fqdn;
              topDomain = lib.concatStringsSep "." (lib.reverseList (lib.take 2 (lib.reverseList fqdnParts)));

              # Look up the issuer for this domain
              domainConfig = (environment.certificates.domains or { }).${topDomain} or null;
              issuerName = if domainConfig != null then domainConfig.issuer else null;
            in
            {
              security.acme = {
                acceptTerms = true;
                defaults = {
                  email = environment.email.adminEmail;
                  inherit (environment.acme) dnsProvider;
                  inherit (environment.acme) dnsResolver;
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
        let
          envName = host.environment or "dev";
          environment = allEnvironments.${envName} or { };
        in
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
              ) (environment.certificates.issuers or { })
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
