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
          credentialsFile = config.age.secrets.cloudflare-api-key.path;
        };

        certs.${config.networking.domain} = {
          extraDomainNames = [ "*.${config.networking.domain}" ];
        };
      };
    };
}
