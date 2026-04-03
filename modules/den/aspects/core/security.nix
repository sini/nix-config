{ den, lib, ... }:
{
  den.aspects.security = {
    includes = lib.attrValues den.aspects.security._;

    _ = {
      config = den.lib.perHost {
        nixos =
          { pkgs, ... }:
          {
            security.polkit.enable = true;

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
          };
      };

      impermanence = den.lib.perHost {
        persist.directories = [
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
      };
    };
  };
}
