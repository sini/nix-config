{
  flake.features.microvm-cuda.nixos =
    {
      lib,
      config,
      pkgs,
      pkgs',
      ...
    }:
    with lib;
    let

      nvidiaCard = lib.lists.findFirst (
        card: card.vendor.name == "nVidia Corporation"
      ) null config.facter.report.hardware.graphics_card;

      nvidiaGpuDeviceID = if nvidiaCard != null then nvidiaCard.sysfs_bus_id else "0000:05:00.0";

      nvidiaAudioController = lib.lists.findFirst (
        card: card.vendor.name == "nVidia Corporation"
      ) null config.facter.report.hardware.sound;

      nvidiaAudioDeviceID =
        if nvidiaAudioController != null then nvidiaAudioController.sysfs_bus_id else "0000:05:00.1";

      pubkeys = concatLists (
        mapAttrsToList (
          _name: user: if elem "wheel" user.extraGroups then user.openssh.authorizedKeys.keys else [ ]
        ) config.users.users
      );
    in
    {

      # systemd.services."microvm@fancontrol".serviceConfig.ExecCondition =
      #   pkgs.writeScript "check_vfio_status.sh" ''
      #     #! ${pkgs.runtimeShell} -e
      #     content=$(< /sys/bus/pci/drivers/vfio-pci/0000\:18\:00.0/enable)

      #     # Check if the content is equal to 0
      #     if [ "$content" == "0" ]; then
      #       exit 0
      #     else
      #       exit 1
      #     fi
      #   '';

      systemd.tmpfiles.rules =
        let
          machineId = (builtins.hashString "md5" "cortex-cuda");
        in
        [
          "L+ /var/log/journal/${machineId} - - - - /var/lib/microvms/cortex-cuda/journal/${machineId}"
        ];

      microvm.vms.cuda = {
        autostart = true;
        # We construct a separate pkgs to avoid host systems options interfering
        pkgs = import pkgs' {
          config = {
            allowUnfree = true;
            allowUnfreePredicate =
              pkg:
              builtins.elem (lib.getName pkg) [
                "nvidia-x11"
              ];
          };
          system = pkgs.system;
        };

        # (Optional) A set of special arguments to be passed to the MicroVM's NixOS modules.
        #specialArgs = {};

        # The configuration for the MicroVM.
        # Multiple definitions will be merged as expected.
        config = {
          environment.etc."machine-id" = {
            mode = "0644";
            text = (builtins.hashString "md5" "cortex-cuda") + "\n";
          };

          microvm = {
            guest.enable = true;
            optimize.enable = true;
            vcpu = 2;
            mem = 4096;

            interfaces = [
              {
                id = "vm-cuda";
                type = "tap";
                mac = "02:00:00:01:01:01";
              }
            ];

            shares = [
              {
                source = "/nix/store";
                mountPoint = "/nix/.ro-store";
                tag = "ro-store";
                proto = "virtiofs";
              }
              {
                # On the host
                source = "/var/lib/microvms/cortex-cuda/journal";
                # In the MicroVM
                mountPoint = "/var/log/journal";
                tag = "journal";
                proto = "virtiofs";
                socket = "journal.sock";
              }
            ];

            devices = [
              {
                bus = "pci";
                path = nvidiaGpuDeviceID;
              }
              {
                bus = "pci";
                path = nvidiaAudioDeviceID;
              }
            ];
          };

          services.openssh.enable = true;
          services.openssh.settings.PasswordAuthentication = false;
          services.openssh.settings.PermitRootLogin = "yes";

          networking.firewall.allowedTCPPorts = [ 22 ];

          system.stateVersion = "25.05";

          # # Just use 99-ethernet-default-dhcp.network
          # systemd.network.enable = true;
          # systemd.network.networks."20-lan" = {
          #   matchConfig.Type = "ether";
          #   networkConfig.DHCP = "yes";
          # };

          systemd.network.enable = true;

          systemd.network.networks."20-lan" = {
            matchConfig.Type = "ether";
            networkConfig = {
              Address = [
                "10.10.10.8/16"
                "fe80::ff:fe01:101/64"
              ];
              Gateway = "10.10.0.1";
              DNS = [
                "1.1.1.1"
                "8.8.8.8"
              ];
              IPv6AcceptRA = true;
              DHCP = "no";
            };
          };

          # Enable OpenGL
          hardware.graphics.enable = true;

          # NVidia
          hardware.nvidia = {

            # Modesetting is required.
            modesetting.enable = true;

            # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
            powerManagement.enable = true;

            # Fine-grained power management. Turns off GPU when not in use.
            # Experimental and only works on modern Nvidia GPUs (Turing or newer).
            powerManagement.finegrained = true;

            # Use the NVidia open source kernel module (not to be confused with the
            # independent third-party "nouveau" open source driver).
            # Support is limited to the Turing and later architectures. Full list of
            # supported GPUs is at:
            # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
            # Only available from driver 515.43.04+
            # Currently alpha-quality/buggy, so false is currently the recommended setting.
            open = true;

            # Enable the Nvidia settings menu,
            # accessible via `nvidia-settings`.
            nvidiaSettings = true;

            # Optionally, you may need to select the appropriate driver version for your specific GPU.
            # package = config.boot.kernelPackages.nvidiaPackages.stable;
          };

          networking.hostName = "cortex-cuda";

          environment.systemPackages = with pkgs; [
            pciutils
            lm_sensors
            nvtopPackages.nvidia
          ];

          users.mutableUsers = false;
          users.users.root.openssh.authorizedKeys.keys = pubkeys;
        };

      };

      # systemd.services."microvm@fancontrol".restartIfChanged = true;
    };
}
