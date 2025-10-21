{ rootPath, ... }:
{
  flake.features.acme.nixos =
    {
      config,
      environment,
      ...
    }:
    {
      age.secrets.cloudflare-api-key = {
        rekeyFile = rootPath + "/.secrets/services/cloudflare-api-key.age";
      };

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
