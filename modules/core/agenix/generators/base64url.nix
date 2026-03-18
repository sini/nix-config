# Base64URL (URL-safe, typically without padding), good for opaque client secrets.
# settings.length = number of random BYTES.
{
  flake.features.agenix-generators.system =
    { lib, ... }:
    {
      age.generators.base64url = lib.mkForce (
        {
          pkgs,
          secret,
          ...
        }:
        # `basenc` with --wrap=0 helps make this URL safe (RFC-4648).
        ''
          ${pkgs.openssl}/bin/openssl rand ${
            toString (secret.settings.length or 60)
          } | ${pkgs.coreutils}/bin/basenc --base64url --wrap=0
        ''
      );
    };
}
