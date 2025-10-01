{ rootPath, ... }:
{
  flake.aspects.acme.nixos =
    { config, environment, ... }:
    {
      age.secrets.cloudflare-api-key = {
        rekeyFile = rootPath + "/.secrets/services/cloudflare-api-key.age";
      };

      security.acme = {
        acceptTerms = true;
        defaults = {
          email = environment.email.adminEmail;
          dnsProvider = environment.acme.dnsProvider;
          dnsResolver = environment.acme.dnsResolver;
          dnsPropagationCheck = true;
          credentialFiles = {
            CLOUDFLARE_DNS_API_TOKEN_FILE = config.age.secrets.cloudflare-api-key.path;
          };
        };

        certs.${config.networking.fqdn} = {
          extraDomainNames = [ "*.${config.networking.fqdn}" ];
        };
      };
    };
}
