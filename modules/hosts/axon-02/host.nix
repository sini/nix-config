{ config, ... }:
{
  flake.hosts.axon-02 = {
    ipv4 = "10.10.10.3";
    roles = [
      "server"
      "kubernetes"
    ];
    extra_modules = with config.flake.modules.nixos; [
      disk-longhorn
      cpu-amd
      gpu-amd
    ];
    tags = {
      "kubernetes-cluster" = "dev";
    };
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDanYqvi+/2Pp57Vw19DHVfQ0VSMXHBdnHLntW+Lr/8h root@axon-02";
    facts = ./facter.json;
  };

  flake.modules.nixos.host_axon-02 =
    {
      pkgs,
      ...
    }:
    {
      boot.kernelPackages = pkgs.linuxPackages_latest;

      hardware = {
        disk.longhorn = {
          os_drive = {
            device_id = "nvme-KINGSTON_OM8PGP41024Q-A0_50026B738300BDD8";
            swap_size = 8192;
          };
          longhorn_drive = {
            device_id = "nvme-Force_MP600_192482300001285610CF";
          };
        };
      };

      system.stateVersion = "25.05";
    };
}
