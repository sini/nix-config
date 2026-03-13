{ lib, ... }:
{
  flake.features.acme.linux =
    {
      config,
      environment,
      ...
    }:
    let
      # Extract top-level domain from the host's FQDN
      fqdnParts = lib.splitString "." config.networking.fqdn;
      topDomain = lib.concatStringsSep "." (lib.reverseList (lib.take 2 (lib.reverseList fqdnParts)));

      # Look up the issuer for this domain
      domainConfig = environment.certificates.domains.${topDomain} or null;
      issuerName = if domainConfig != null then domainConfig.issuer else null;

      # Get the issuer configuration
      issuerConfig =
        if issuerName != null then environment.certificates.issuers.${issuerName} or null else null;
      rekeyFile =
        if issuerConfig != null && issuerConfig.ageKeyFile != null then issuerConfig.ageKeyFile else null;

      # Generate age secrets for ALL issuers (not just the ones used by this host)
      # This allows the secrets to be used by nginx, cert-manager, and other services
      issuerSecrets = lib.listToAttrs (
        lib.flatten (
          lib.mapAttrsToList (
            issuerName: issuerConfig:
            lib.optional (issuerConfig.ageKeyFile != null) {
              name = "${issuerName}-cloudflare-api-key";
              value = {
                rekeyFile = issuerConfig.ageKeyFile;
              };
            }
          ) environment.certificates.issuers
        )
      );
    in
    lib.mkIf (rekeyFile != null) {
      age.secrets = issuerSecrets;

      environment.persistence."/persist".directories = [
        {
          directory = "/var/lib/acme";
          user = "acme";
          group = "acme";
          mode = "0755";
        }
      ];

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
