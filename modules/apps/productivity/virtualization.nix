{ config, ... }:
let
  username = config.flake.meta.user.username;
in
{
  flake.aspects.virtualization.nixos =
    { pkgs, ... }:
    {
      # Add user to libvirtd group
      users.users.${username}.extraGroups = [ "libvirtd" ];

      # Install necessary packages
      environment.systemPackages = with pkgs; [
        libguestfs
        spice
        spice-gtk
        spice-protocol
        virt-manager
        virt-viewer
        win-virtio
        win-spice
      ];

      # Manage the virtualisation services
      virtualisation = {
        kvmgt.enable = true;
        libvirtd = {
          enable = true;
          allowedBridges = [
            "nm-bridge"
            "virbr0"
          ];
          onBoot = "ignore";
          onShutdown = "shutdown";
          qemu = {
            swtpm.enable = true;
            ovmf = {
              enable = true;
              packages = [
                (pkgs.OVMF.override {
                  secureBoot = true;
                  tpmSupport = true;
                }).fd
              ];
            };
          };
        };
        spiceUSBRedirection.enable = true;
      };

      services.spice-vdagentd.enable = true;
    };
}
