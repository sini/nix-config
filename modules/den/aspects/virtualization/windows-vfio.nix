# Windows VFIO VM with GPU passthrough, hugepage management,
# and CPU isolation for near-native gaming performance.
{ den, ... }:
{
  den.aspects.virtualization.windows-vfio = {
    includes = [
      den.aspects.hardware.gpu.nvidia-vfio
    ];

    gpu-claims = {
      device = "nvidia";
      priority = "interactive";
      kind = "libvirt";
    };

    nixos =
      {
        gpu-claims,
        config,
        lib,
        pkgs,
        ...
      }:
      {
        virtualisation.libvirtd = {
          enable = true;
          qemu = {
            swtpm.enable = true;
            vhostUserPackages = [ pkgs.virtiofsd ];
          };

          hooks.qemu =
            let
              memory = 33554432;
              hugepages = builtins.ceil (builtins.div memory 2048);
              hugepagesWithOverhead = hugepages + 64;
            in
            {
              "windows-vfio" =
                let
                  inherit (lib) getExe;
                  awk = getExe pkgs.gawk;
                  bash = getExe pkgs.bash;
                  renice = "${pkgs.util-linux}/bin/renice";
                  sponge = "${pkgs.moreutils}/bin/sponge";
                  systemctl = "${config.systemd.package}/bin/systemctl";
                  virsh = "${pkgs.libvirt}/bin/virsh";
                  preemptUnits = map (c: c.unit) (
                    lib.filter (c: c.priority == "background" && c.device == "nvidia") gpu-claims
                  );
                  stopBackground = lib.concatMapStringsSep "\n" (u: "${systemctl} stop ${u}") preemptUnits;
                  startBackground = lib.concatMapStringsSep "\n" (u: "${systemctl} start ${u}") preemptUnits;
                in
                pkgs.writeScript "windows-vfio-hook" ''
                  #!${bash}
                  vmname="$1"
                  event="$2"

                  if [ "$vmname" != "windows-vfio" ]; then
                    exit 0
                  fi

                  vmpid=$(cat /var/run/libvirt/qemu/$vmname.pid)
                  vmpgid=$(ps -o pgid --no-heading $vmpid | ${awk} '{print $1}')

                  if [ "$event" = "prepare" ]; then
                    ${stopBackground}

                    # Unbind USB controller for passthrough
                    echo "0000:14:00.4" > /sys/bus/pci/drivers/xhci_hcd/unbind
                    echo "1022 15b7" > /sys/bus/pci/drivers/vfio-pci/new_id

                    # Performance governor and disable SCX
                    CPU_COUNT=0
                    for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
                    do
                      echo performance > $file;
                      echo "CPU $CPU_COUNT governor: performance";
                      let CPU_COUNT+=1
                    done
                    ${systemctl} stop scx.service
                    ${systemctl} start irqbalance.service

                    # Allocate hugepages
                    echo 3 | ${sponge} /proc/sys/vm/drop_caches
                    echo 1 | ${sponge} /proc/sys/vm/compact_memory

                    ${virsh} allocpages 2M ${toString hugepagesWithOverhead} || {
                      echo Failed to allocate hugepages for windows-vfio
                      exit 1
                    }

                    # Pin Linux to second CCD (AMD Ryzen 9950X3D)
                    ${systemctl} set-property --runtime -- init.scope AllowedCPUs=8-15,24-31
                    ${systemctl} set-property --runtime -- system.slice AllowedCPUs=8-15,24-31
                    ${systemctl} set-property --runtime -- user.slice AllowedCPUs=8-15,24-31

                  elif [ "$event" = "started" ]; then
                    ${renice} -1 -g $vmpgid

                  elif [ "$event" = "release" ]; then
                    ${virsh} allocpages 2M 0

                    # Restore full CPU access
                    systemctl set-property --runtime -- init.scope AllowedCPUs=0-31
                    systemctl set-property --runtime -- system.slice AllowedCPUs=0-31
                    systemctl set-property --runtime -- user.slice AllowedCPUs=0-31

                    # Restore SCX scheduler
                    CPU_COUNT=0
                    for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
                    do
                      echo schedutil > $file;
                      echo "CPU $CPU_COUNT governor: schedutil";
                      let CPU_COUNT+=1
                    done
                    ${systemctl} start scx.service
                    ${systemctl} start irqbalance.service

                    # Rebind USB controller
                    echo "0000:14:00.4" > /sys/bus/pci/drivers/vfio-pci/unbind
                    echo "1022 15b7" > /sys/bus/pci/drivers/vfio-pci/remove_id
                    echo "0000:14:00.4" > /sys/bus/pci/drivers/xhci_hcd/bind

                    # Restore preempted background GPU claims
                    ${startBackground}
                  fi
                '';
            };
        };
      };
  };
}
