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

      environment.persistence."/persist".directories = [
        {
          directory = "/var/lib/swtpm";
          user = "tss";
          group = "tss";
          mode = "0750";
        }
        {
          directory = "/var/lib/swtpm-localca";
          user = "tss";
          group = "tss";
          mode = "0750";
        }
      ];
      impermanence.ignorePaths = [
        "/var/lib/tpm2-udev-trigger/hash.txt"
      ];
    };
}
