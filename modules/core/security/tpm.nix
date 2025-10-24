{
  flake.features.security.nixos =
    { pkgs, ... }:
    {
      security.tpm2.enable = true;

      environment.systemPackages = [
        pkgs.clevis
        pkgs.jose
      ];

      impermanence.ignorePaths = [
        "/var/lib/tpm2-udev-trigger/hash.txt"
      ];
    };
}
