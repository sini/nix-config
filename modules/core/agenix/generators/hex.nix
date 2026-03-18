# Hex-encoded random bytes.
# settings.length = number of random bytes (24 was the original default).
{
  flake.features.agenix-generators.system =
    { lib, ... }:
    {
      age.generators.hex = lib.mkForce (
        {
          pkgs,
          secret,
          ...
        }:
        "${pkgs.openssl}/bin/openssl rand -hex ${toString (secret.settings.length or 24)}"
      );
    };
}
