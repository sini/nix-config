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
      prometheus
      grafana
      #loki
      #promtail
      bgp-uplink
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

      # BGP configuration
      services.bgp-uplink = {
        enable = true;
        localAsNumber = 65000;

        # Option 1: Manual neighbor configuration (default)
        neighbors = [
          {
            address = "10.10.10.2";
            asNumber = 65001;
            defaultOriginate = true;
          }
          {
            address = "10.10.10.3";
            asNumber = 65002;
            defaultOriginate = true;
          }
          {
            address = "10.10.10.4";
            asNumber = 65003;
            defaultOriginate = true;
          }
        ];

        # Option 2: Auto-discover neighbors from hosts (uncomment to use)
        # autoDiscoverNeighbors = true;
        # neighborSelector.role = "kubernetes";  # Or use tag-based selection
        # neighborAsNumberBase = 65001;
        # defaultOriginateToNeighbors = true;
      };
    };
}
