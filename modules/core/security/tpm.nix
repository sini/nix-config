{
  flake.features.security.nixos = {
    security.tpm2.enable = true;
  };
}
