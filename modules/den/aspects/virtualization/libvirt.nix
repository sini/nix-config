_: {
  den.aspects.virtualization.libvirt = {
    nixos =
      {
        host,
        pkgs,
        ...
      }:
      let
        user = host.system-owner;

        primaryNetwork = pkgs.writeText "default-network.xml" ''
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
        '';

        primarybridgeNetwork = pkgs.writeText "default-bridge.xml" ''
          <network>
            <name>default-bridge</name>
            <uuid>6dea79f2-1512-40c6-a2a3-ed0b15a9c72d</uuid>
            <forward mode='bridge'/>
            <bridge name='virbr1'/>
          </network>
        '';
      in
      {
        boot = {
          kernelModules = [
            "kvm"
            "vhost-net"
          ];

          kernel.sysctl = {
            "net.bridge.bridge-nf-call-iptables" = 0;
            "net.bridge.bridge-nf-call-arptables" = 0;
            "net.bridge.bridge-nf-call-ip6tables" = 0;
            "vm.nr_hugepages" = 1024;
          };

          kernelParams = [
            "default_hugepagesz=2M"
            "hugepagesz=2M"
            "transparent_hugepage=never"
            "mem_sleep_default=deep"

            # ACPI & Power Management
            "acpi_osi=Linux"
            "acpi=force"
            "acpi_enforce_resources=lax"

            # Performance
            "mitigations=off"
            "nowatchdog"
            "nmi_watchdog=0"
          ];
        };

        environment.systemPackages = [
          pkgs.libguestfs
          pkgs.spice
          pkgs.spice-gtk
          pkgs.spice-protocol
          pkgs.virt-manager
          pkgs.virt-viewer
          pkgs.virtio-win
          pkgs.win-spice
          pkgs.cloud-utils
          pkgs.bridge-utils
          pkgs.virtiofsd
          pkgs.local.looking-glass-client
          pkgs.qemu
          pkgs.OVMF
          pkgs.gvfs
          pkgs.swtpm
          pkgs.virglrenderer
        ];

        programs.virt-manager.enable = true;

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

        networking.firewall = {
          trustedInterfaces = [ "virbr0" ];
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
            }
            {
              from = 61000;
              to = 61999;
            }
          ];
        };

        systemd.services.libvirt-networks = {
          description = "Setup libvirt networks";
          after = [ "libvirtd.service" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
          };
          script = ''
            sleep 5

            if ! ${pkgs.libvirt}/bin/virsh net-list --all | grep -q "default "; then
              ${pkgs.libvirt}/bin/virsh net-define ${primaryNetwork}
            fi

            if ! ${pkgs.libvirt}/bin/virsh net-list --all | grep -q "default-bridge"; then
              ${pkgs.libvirt}/bin/virsh net-define ${primarybridgeNetwork}
            fi

            ${pkgs.libvirt}/bin/virsh net-autostart default 2>/dev/null || true
            ${pkgs.libvirt}/bin/virsh net-start default 2>/dev/null || true

            ${pkgs.libvirt}/bin/virsh net-autostart default-bridge 2>/dev/null || true
            ${pkgs.libvirt}/bin/virsh net-start default-bridge 2>/dev/null || true
          '';
        };

        services = {
          qemuGuest.enable = true;
          spice-vdagentd.enable = true;
          spice-webdavd.enable = true;
        };

        virtualisation = {
          libvirtd = {
            enable = true;
            allowedBridges = [
              "br0"
              "virbr0"
              "virbr1"
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

        security.polkit.extraConfig = ''
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

    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.spice-gtk
          pkgs.virtio-win
        ];

        dconf.settings = {
          "org/virt-manager/virt-manager/connections" = {
            autoconnect = [ "qemu:///system" ];
            uris = [ "qemu:///system" ];
          };

          "org/virt-manager/virt-manager" = {
            xmleditor-enabled = true;
            stats-update-interval = 1;
            console-accels = true;
          };

          "org/virt-manager/virt-manager/console" = {
            resize-guest = 1;
            scaling = 1;
          };

          "org/virt-manager/virt-manager/new-vm" = {
            graphics-type = "spice";
            cpu-default = "host-passthrough";
            storage-format = "qcow2";
          };

          "org/virt-manager/virt-manager/urls" = {
            isos = [ "/var/lib/libvirt/isos" ];
          };
        };

        xdg.configFile."looking-glass/client.ini".text = ''
          [app]
          shmFile=/dev/kvmfr0

          [input]
          rawMouse=yes
          escapeKey=KEY_RIGHTALT
        '';
      };

    persist.directories = [ "/var/lib/libvirt" ];
  };
}
