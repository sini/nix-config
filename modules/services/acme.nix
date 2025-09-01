{ rootPath, ... }:
{
  flake.modules.nixos.acme = {
    age.secrets.cloudflare-api-key = {
      rekeyFile = rootPath + "/.secrets/services/cloudflare-api-key.age";
    };
  };
}
