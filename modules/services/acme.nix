{ rootPath, ... }:
{
  flake.modules.nixos.acme =
    { config, ... }:
    {
      age.secrets.cloudflare-api-key = {
        rekeyFile = rootPath + "/.secrets/services/cloudflare-api-key.age";
      };

      security.acme = {
        acceptTerms = true;
        defaults = {
          email = "jason@json64.dev";
          dnsProvider = "cloudflare";
          credentialFiles = {
            CLOUDFLARE_DNS_API_TOKEN_FILE = config.age.secrets.cloudflare-api-key.path;
          };
        };

        certs.${config.networking.domain} = {
          extraDomainNames = [ "*.${config.networking.domain}" ];
        };
      };
    };
}
