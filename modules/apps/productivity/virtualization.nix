{ config, ... }:
let
  user = config.flake.meta.user.username;
in
{
  flake.features.virtualization.nixos =
    { config, pkgs, ... }:
    {

      boot.kernelModules = [
        "kvm"
        "vhost-net"
      ];
      # Sysctl parameters for virtualization
      boot.kernel.sysctl = {
        # Network performance
        "net.bridge.bridge-nf-call-iptables" = 0;
        "net.bridge.bridge-nf-call-arptables" = 0;
        "net.bridge.bridge-nf-call-ip6tables" = 0;

        # Virtual memory
        "vm.swappiness" = 10;
        "vm.dirty_ratio" = 15;
        "vm.dirty_background_ratio" = 5;

        # Huge pages
        "vm.nr_hugepages" = 1024;
      };

      boot.kernelParams = [
        # Memory Management
        "default_hugepagesz=2M" # Set default huge page size to 2MB
        "hugepagesz=2M" # Configure huge page size as 2MB
        "transparent_hugepage=never" # Disable transparent huge pages
        "mem_sleep_default=deep" # Set default sleep mode to deep sleep
      ];

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

        virtiofsd
        looking-glass-client # For KVM
        qemu # Virtualizer
        OVMF # UEFI Firmware
        gvfs # Shared Directory
        swtpm # TPM
        virglrenderer # Virtual OpenGL
      ];

      programs.virt-manager.enable = true;

      # TODO: remove hardcoded user 'sini'
      systemd.tmpfiles.rules = [
        "d /dev/hugepages 1770 root kvm -"
        "d /dev/shm 1777 root root -"
        "f /dev/shm/looking-glass 0660 ${user} kvm -"
      ];

      fileSystems."/dev/hugepages" = {
        device = "hugetlbfs";
        fsType = "hugetlbfs";
        options = [
          "mode=01770"
          "gid=kvm"
        ];
      };

      networking = {
        # Firewall rules for virtualization
        firewall = {
          # Allow libvirt bridge traffic
          trustedInterfaces = [ "virbr0" ] ++ config.hardware.networking.bridges;

          # Allow SPICE and VNC ports
          allowedTCPPorts = [
            5900
            5901
            5902
            5903
            5904
            5905
          ];
          allowedTCPPortRanges = [
            {
              from = 5900;
              to = 5999;
            } # VNC
            {
              from = 61000;
              to = 61999;
            } # SPICE
          ];
        };
      };

      systemd.services = {
        # Custom libvirt network setup
        libvirt-networks = {
          description = "Setup libvirt networks";
          after = [ "libvirtd.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            # Wait for libvirtd to be ready
            sleep 5

            # Define and start default network if it doesn't exist
            if ! ${pkgs.libvirt}/bin/virsh net-list --all | grep -q "default"; then
              ${pkgs.libvirt}/bin/virsh net-define ${pkgs.writeText "default-network.xml" ''
                <network>
                  <name>default</name>
                  <uuid>d5ee6d97-4d4b-4e05-87bb-69b682182cf4</uuid>
                  <forward mode='nat'>
                    <nat>
                      <port start='1024' end='65535'/>
                    </nat>
                  </forward>
                  <bridge name='virbr0' stp='on' delay='0'/>
                  <ip address='192.168.122.1' netmask='255.255.255.0'>
                    <dhcp>
                      <range start='192.168.122.2' end='192.168.122.254'/>
                    </dhcp>
                  </ip>
                </network>
              ''}
            fi

            # Auto-start default network
            ${pkgs.libvirt}/bin/virsh net-autostart default 2>/dev/null || true
            ${pkgs.libvirt}/bin/virsh net-start default 2>/dev/null || true
          '';
        };
      };

      # Manage the virtualisation services
      virtualisation = {
        kvmgt.enable = true;
        libvirtd = {
          enable = true;
          allowedBridges = [
            "br0"
            "nm-bridge"
            "virbr0"
          ];
          onBoot = "ignore";
          onShutdown = "shutdown";
          qemu = {
            swtpm.enable = true;
            runAsRoot = true;
            verbatimConfig = ''
              user = "${user}"
              group = "kvm"
              cgroup_device_acl = [
                "/dev/null", "/dev/full", "/dev/zero",
                "/dev/random", "/dev/urandom",
                "/dev/ptmx", "/dev/kvm", "/dev/kqemu",
                "/dev/rtc","/dev/hpet", "/dev/sev",
                "/dev/kvmfr0",
                "/dev/vfio/vfio"
              ]
              hugetlbfs_mount = "/dev/hugepages"
              bridge_helper = "/run/wrappers/bin/qemu-bridge-helper"
            '';
          };
        };
        spiceUSBRedirection.enable = true;
      };

      # Security optimizations for VMs
      security = {
        # Allow QEMU guest agent
        polkit.extraConfig = ''
          polkit.addRule(function(action, subject) {
            if (action.id == "org.freedesktop.machine1.manage-machines" &&
              subject.isInGroup("libvirtd")) {
              return polkit.Result.YES;
            }
          });

          polkit.addRule(function(action, subject) {
            if (action.id == "org.libvirt.unix.manage" &&
              subject.isInGroup("libvirtd")) {
                return polkit.Result.YES;
            }
          });

          polkit.addRule(function(action, subject) {
            if (action.id == "org.libvirt.api.domain.start" &&
              subject.isInGroup("libvirtd")) {
                return polkit.Result.YES;
            }
          });
        '';
      };

      services.spice-vdagentd.enable = true;
    };
}
