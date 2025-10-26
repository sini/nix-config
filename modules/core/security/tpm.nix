{
  flake.features.security.nixos =
    { pkgs, ... }:
    {
      security.tpm2 = {
        enable = true;
        abrmd.enable = true;
        pkcs11.enable = true;
        tctiEnvironment.enable = true;
      };

      environment.systemPackages = [
        pkgs.clevis
        pkgs.jose
      ];

      impermanence.ignorePaths = [
        "/var/lib/tpm2-udev-trigger/hash.txt"
      ];
    };
}
