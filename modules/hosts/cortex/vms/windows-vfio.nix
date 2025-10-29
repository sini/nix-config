flakeConfig: {
  flake.features.windows-vfio = {
    requires = [
      "microvm-cuda"
      "gpu-nvidia-vfio"
    ];

    nixos =
      {
        lib,
        config,
        pkgs,
        ...
      }:
      # with lib;
      # let

      #   nvidiaCard = lib.lists.findFirst (
      #     card: card.vendor.name == "nVidia Corporation"
      #   ) null config.facter.report.hardware.graphics_card;

      #   nvidiaGpuDeviceID = if nvidiaCard != null then nvidiaCard.sysfs_bus_id else "0000:05:00.0";

      #   nvidiaAudioController = lib.lists.findFirst (
      #     card: card.vendor.name == "nVidia Corporation"
      #   ) null config.facter.report.hardware.sound;

      #   nvidiaAudioDeviceID =
      #     if nvidiaAudioController != null then nvidiaAudioController.sysfs_bus_id else "0000:05:00.1";

      #   pubkeys = concatLists (
      #     mapAttrsToList (
      #       _name: user: if elem "wheel" user.extraGroups then user.openssh.authorizedKeys.keys else [ ]
      #     ) config.users.users
      #   );
      # in
      {

        virtualisation = {
          libvirtd = {
            enable = true;
            qemu = {
              swtpm.enable = true;

              vhostUserPackages = [
                pkgs.virtiofsd
              ];
            };

            # Hook to (de)allocate hugepages for Windows gaming VM
            hooks.qemu =
              let
                memory = 33554432;
                hugepages = builtins.ceil (builtins.div memory 2048);
                hugepagesWithOverhead = hugepages + 64; # 128MiB extra (64 pages) for eventual overhead
              in
              {
                "windows-vfio" =
                  let
                    awk = lib.getExe pkgs.gawk;
                    bash = lib.getExe pkgs.bash;
                    renice = "${pkgs.util-linux}/bin/renice";
                    sponge = "${pkgs.moreutils}/bin/sponge";
                    sysctl = lib.getExe pkgs.sysctl;
                    systemctl = "${config.systemd.package}/bin/systemctl";
                    virsh = "${pkgs.libvirt}/bin/virsh";
                  in
                  pkgs.writeScript "windows-vfio-hook" # bash
                    ''
                      #!${bash}
                      # See https://libvirt.org/hooks.html#etc-libvirt-hooks-qemu for hook documentation

                      vmname="$1" # vm name is passed as first argument
                      event="$2" # hooked event is passed as second argument

                      # Only run this hook for gaming VM
                      if [ "$vmname" != "windows-vfio" ]; then
                        exit 0
                      fi

                      # Get the process id of the VM
                      vmpid=$(cat /var/run/libvirt/qemu/$vmname.pid)
                      # Get the process group id of the VM so we can renice all threads
                      vmpgid=$(ps -o pgid --no-heading $vmpid | ${awk} '{print $1}')

                      if [ "$event" = "prepare" ]; then
                        # Stop the microvm-cuda service
                        ${systemctl} stop microvm@cuda.service

                        # Disable SCX and set the cpu governor
                        CPU_COUNT=0
                        for file in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
                        do
                          echo performance > $file;
                          echo "CPU $CPU_COUNT governor: performance";
                          let CPU_COUNT+=1
                        done
                        ${systemctl} stop scx.service
                        ${systemctl} start irqbalance.service

                        # Prepare kernel memory for gaming VM hugepages

                        # Drop filesystem caches
                        echo 3 | ${sponge} /proc/sys/vm/drop_caches

                        # Compact memory to make hugepages available
                        echo 1 | ${sponge} /proc/sys/vm/compact_memory

                        # Allocate 2M hugepages for vm (count = VM MiB / 2)
                        ${virsh} allocpages 2M ${toString hugepagesWithOverhead} || {
                          echo Failed to allocate hugepages for windows-vfio
                          exit 1
                        }

                        # Disable split_lock mitigations
                        ${sysctl} kernel.split_lock_mitigate=0

                        # Only schedule Linux stuff on the second CCD (AMD Ryzen 9950X3D)
                        ${systemctl} set-property --runtime -- init.scope AllowedCPUs=8-15,24-31
                        ${systemctl} set-property --runtime -- system.slice AllowedCPUs=8-15,24-31
                        ${systemctl} set-property --runtime -- user.slice AllowedCPUs=8-15,24-31

                      elif [ "$event" = "started" ]; then
                        # Renice VM to -1
                        ${renice} -1 -g $vmpgid


                      elif [ "$event" = "release" ]; then
                        # shutoff-reason is passed as fourth argument
                        reason="$4"
                        # Release hugepages back to the system
                        ${virsh} allocpages 2M 0

                        # Restore split_lock mitigations
                        ${sysctl} kernel.split_lock_mitigate=1

                        # Reset scheduling back to use the entire CPU
                        systemctl set-property --runtime -- init.scope AllowedCPUs=0-31
                        systemctl  set-property --runtime -- system.slice AllowedCPUs=0-31
                        systemctl  set-property --runtime -- user.slice AllowedCPUs=0-31


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

                        # Restore ollama cuda VM...
                        ${systemctl} start microvm@cuda.service


                      fi
                    '';
              };
          };
        };
      };
  };
}
