flakeConfig: {
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

      systemd.services."microvm@cuda".serviceConfig.ExecCondition =
        pkgs.writeScript "check_vfio_status.sh" ''
          #! ${pkgs.runtimeShell} -e
          content=$(< /sys/bus/pci/drivers/vfio-pci/${nvidiaGpuDeviceID}/enable)

          # Check if the content is equal to 0
          if [ "$content" == "0" ]; then
            exit 0
          else
            exit 1
          fi
        '';

      # systemd.tmpfiles.rules =
      #   let
      #     machineId = (builtins.hashString "md5" "cortex-cuda");
      #   in
      #   [
      #     "L+ /var/log/journal/${machineId} - - - - /var/lib/microvms/cortex-cuda/journal/${machineId}"
      #   ];

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
            nvidia.acceptLicense = true;
            cudaSupport = true;
            cudnnSupport = true;
          };
          system = pkgs.stdenv.hostPlatform.system;
        };

        # (Optional) A set of special arguments to be passed to the MicroVM's NixOS modules.
        #specialArgs = {};

        # The configuration for the MicroVM.
        # Multiple definitions will be merged as expected.
        config =
          {
            config,
            lib,
            pkgs,
            ...
          }:
          {
            networking.hostName = "cortex-cuda";

            microvm = {
              guest.enable = true;
              optimize.enable = true;
              vcpu = 32;
              mem = 32768;

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
                  source = "/cache/var/lib/private/ollama";
                  mountPoint = "/var/lib/private/ollama";
                  tag = "ollama";
                  proto = "virtiofs";

                }
                # {
                #   # On the host
                #   source = "/var/lib/microvms/cortex-cuda/journal";
                #   # In the MicroVM
                #   mountPoint = "/var/log/journal";
                #   tag = "journal";
                #   proto = "virtiofs";
                #   socket = "journal.sock";
                # }
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

            environment.etc."machine-id" = {
              mode = "0644";
              text = (builtins.hashString "md5" "cortex-cuda") + "\n";
            };

            services.openssh.enable = true;
            services.openssh.settings.PasswordAuthentication = false;
            services.openssh.settings.PermitRootLogin = "yes";

            networking.firewall.allowedTCPPorts = [ 22 ];

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
                  "10.9.2.2/16"
                  "fe80::ff:fe01:101/64"
                ];
                Gateway = "10.9.0.1";
                DNS = [
                  "1.1.1.1"
                  "8.8.8.8"
                ];
                IPv6AcceptRA = true;
                DHCP = "no";
              };
            };

            boot = {
              kernelModules = [
                "nvidia"
                "nvidia_modeset"
                "nvidia_drm"
                "nvidia_uvm"
              ];

              kernelParams = [
                "nvidia-drm.modeset=1"
                "nvidia-drm.fbdev=1"
              ];

              extraModprobeConfig =
                "options nvidia "
                + lib.concatStringsSep " " [
                  # nvidia assume that by default your CPU does not support PAT,
                  # but this is effectively never the case in 2023
                  "NVreg_UsePageAttributeTable=1"
                  "nvidia.NVreg_EnableGpuFirmware=1"
                  # This is sometimes needed for ddc/ci support, see
                  # https://www.ddcutil.com/nvidia/
                  #
                  # Current monitor does not support it, but this is useful for
                  # the future
                  "NVreg_RegistryDwords=RMUseSwI2c=0x01;RMI2cSpeed=100"
                ];
            };

            nix.settings = {
              substituters = [
                "https://cuda-maintainers.cachix.org"
              ];
              trusted-public-keys = [
                "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
              ];
            };

            services.xserver.videoDrivers = [ "nvidia" ];

            hardware.graphics = {
              enable = true;
              extraPackages = with pkgs; [
                libva-vdpau-driver
                libvdpau
                libvdpau-va-gl
                nvidia-vaapi-driver
                vdpauinfo
                libva
                libva-utils
              ];
            };

            hardware.nvidia = {
              forceFullCompositionPipeline = true;
              modesetting.enable = true;
              powerManagement.enable = true;
              open = true;
              nvidiaSettings = false;
              nvidiaPersistenced = true;
              package = config.boot.kernelPackages.nvidiaPackages.beta;
            };

            environment.systemPackages = with pkgs; [
              pciutils
              lm_sensors
              nvtopPackages.nvidia
              libva-utils
              gwe
              vulkan-tools
              mesa-demos
              zenith-nvidia
              nvitop
              btop-cuda
              # vulkanPackages_latest.vulkan-loader
              # vulkanPackages_latest.vulkan-validation-layers # From unstable
              # vulkanPackages_latest.vulkan-validation-layers
              # vulkanPackages_latest.vulkan-tools
            ];

            services = {
              ollama = {
                enable = true;
                user = "ollama";
                group = "ollama";
                openFirewall = true;

                package = pkgs.ollama-cuda;

                host = "0.0.0.0";
                port = 11434;

                home = "/var/lib/ollama";

                environmentVariables = {
                  OLLAMA_FLASH_ATTENTION = "true";
                  OLLAMA_CONTEXT_LENGTH = "32768";
                  # OLLAMA_CONTEXT_LENGTH = "16384";
                  OLLAMA_KV_CACHE_TYPE = "q8_0";
                  OLLAMA_KEEP_ALIVE = "10m";
                  OLLAMA_MAX_LOADED_MODELS = "4";
                  OLLAMA_MAX_QUEUE = "64";
                  OLLAMA_NUM_PARALLEL = "1";
                  OLLAMA_ORIGINS = "*";
                };
              };
            };

            systemd.services.nvidia-gpu-config = {
              description = "Configure NVIDIA GPU";
              wantedBy = [ "multi-user.target" ];
              path = [ config.hardware.nvidia.package.bin ];
              script = ''
                echo 'Limiting NVIDIA GPU TDP to 450W...'
                nvidia-smi -pl 450
                nvidia-smi -rmc
              '';
              serviceConfig.Type = "oneshot";
            };

            systemd.services.ollama.after = [ "nvidia-gpu-config.service" ];

            systemd.services.ollama.serviceConfig = {
              DeviceAllow = lib.mkForce [ ];
              DevicePolicy = lib.mkForce "auto";
            };

            users.mutableUsers = false;
            users.users.root.openssh.authorizedKeys.keys = pubkeys;
            users.users.ollama = {
              isSystemUser = true;
              group = "ollama";
              uid = 962;
            };

            users.groups.ollama = {
              gid = 962;
            };

            system.stateVersion = "25.05";
          };

      };

      # systemd.services."microvm@fancontrol".restartIfChanged = true;
    };
}
