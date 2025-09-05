{ config, ... }:
{
  flake.hosts.uplink = {
    ipv4 = "10.10.10.1";
    roles = [
      "server"
    ];
    extra_modules = with config.flake.modules.nixos; [
      cpu-amd
      gpu-intel
      disk-single
      podman
      acme
      nginx
      kanidm
    ];
    public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIA9Q/KHuuigi5EU8I36EQQzw4QCXj3dEh0bzz/uZ1y+p";
    facts = ./facter.json;
  };

  flake.modules.nixos.host_uplink =
    {
      pkgs,
      ...
    }:
    {
      hardware = {
        disk.single.device_id = "nvme-Samsung_SSD_990_EVO_Plus_4TB_S7U8NJ0XC20015K";
        networking.interfaces = [ "enp10s0" ];
      };
      boot.kernelPackages = pkgs.linuxPackages_latest;
      system.stateVersion = "25.05";
    };
}
