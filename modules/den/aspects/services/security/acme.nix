{ lib, ... }:
{
  den.aspects.services.security.acme = {
    settings = {
      fqdnCert = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Order a certificate for the host's FQDN and its wildcard";
      };
    };

    nixos =
      {
        config,
        environment,
        host,
        certificate-domains,
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
                domainConfig = lib.findFirst (d: d.domain == topDomain) null certificate-domains;
                issuerName = if domainConfig != null then domainConfig.issuer else null;
              in
              lib.optionalAttrs (issuerName != null) {
                CLOUDFLARE_DNS_API_TOKEN_FILE = config.age.secrets."${issuerName}-cloudflare-api-key".path;
              };
          };

          certs = lib.mkIf host.settings.services.security.acme.fqdnCert {
            ${config.networking.fqdn}.extraDomainNames = [ "*.${config.networking.fqdn}" ];
          };
        };
      };

    age-secrets =
      { environment, host, ... }:
      let
        issuers = environment.certificates.issuers or { };
      in
      {
        # Plain disjoint merge (one secret per issuer), not mkMerge: the secrets
        # collector deduplicates broadcast emissions by name with a shallow
        # merge, so emitters must return a plain attrset.
        age.secrets = lib.mergeAttrsList (
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
