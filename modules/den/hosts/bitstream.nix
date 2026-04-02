{ den, inputs, ... }:
{
  den.hosts.x86_64-linux.bitstream = { };

  den.aspects.bitstream = {
    includes = [
      den.aspects.shell
    ];

    nixos =
      { ... }:
      {
        imports = [
          inputs.nixos-facter-modules.nixosModules.facter
        ];

        facter.reportPath = ../../hosts/bitstream/facter.json;

        nixpkgs.hostPlatform = "x86_64-linux";

        boot.loader.systemd-boot.enable = true;
        boot.loader.efi.canTouchEfiVariables = true;
      };
  };
}
