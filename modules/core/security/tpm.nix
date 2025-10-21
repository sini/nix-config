{
  flake.features.security.nixos = {
    security.tpm2.enable = true;
    impermanence.ignorePaths = [
      "/var/lib/tpm2-udev-trigger/hash.txt"
    ];
  };
}
