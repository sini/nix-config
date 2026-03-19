# Standard Base64 (with padding, no line breaks).
# settings.length = number of random BYTES before encoding.
{
  features.agenix-generators.system =
    { lib, ... }:
    {
      age.generators.base64 = lib.mkForce (
        {
          pkgs,
          secret,
          ...
        }:
        ''
          ${pkgs.openssl}/bin/openssl rand --base64 ${toString (secret.settings.length or 32)} | tr -d '\n'
        ''
      );
    };
}
