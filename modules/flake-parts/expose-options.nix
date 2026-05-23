# Re-expose den configuration as flake outputs for external consumers.
{ config, ... }:
{
  config.flake = {
    inherit (config.den) environments;
  };
}
