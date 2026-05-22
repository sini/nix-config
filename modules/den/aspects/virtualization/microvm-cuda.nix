# CUDA GPU passthrough MicroVM for cortex workstation.
# Passes through the NVIDIA GPU for ollama inference inside an isolated VM.
{
  den,
  lib,
  config,
  inputs,
  ...
}:
let
  allUsers = config.den.users.registry or { };

  # Collect SSH keys from wheel/admins users for root access to the VM
  pubkeys = lib.concatMap (
    u:
    lib.optionals (builtins.any (g: g == "admins" || g == "wheel") (u.groups or [ ])) (
      map (k: k.key) (u.identity.sshKeys or [ ])
    )
  ) (lib.attrValues allUsers);
in
{
  den.aspects.virtualization.microvm-cuda = {
    includes = [ den.aspects.virtualization.microvm ];

    nixos =
      {
        config,
        pkgs,
        ...
      }:
      let
        nvidiaCard = lib.lists.findFirst (
          card: card.vendor.name == "nVidia Corporation"
        ) null config.facter.report.hardware.graphics_card;

        nvidiaGpuDeviceID =
          if nvidiaCard != null then nvidiaCard.sysfs_bus_id else "0000:05:00.0";

        nvidiaAudioController = lib.lists.findFirst (
          card: card.vendor.name == "nVidia Corporation"
        ) null config.facter.report.hardware.sound;

        nvidiaAudioDeviceID =
          if nvidiaAudioController != null then
            nvidiaAudioController.sysfs_bus_id
          else
            "0000:05:00.1";

        vfioStatusCheck = pkgs.writeScript "check_vfio_status.sh" ''
          #! ${pkgs.runtimeShell} -e
          content=$(< /sys/bus/pci/drivers/vfio-pci/${nvidiaGpuDeviceID}/enable)

          echo "VFIO enable check: device ${nvidiaGpuDeviceID} enable=$content" | ${pkgs.systemd}/bin/systemd-cat -t vfio-check -p info

          if [ "$content" == "0" ]; then
            exit 0
          else
            exit 1
          fi
        '';
      in
      {
        systemd.services."microvm-pci-devices@cuda".serviceConfig.ExecCondition = vfioStatusCheck;
        systemd.services."microvm@cuda".serviceConfig.ExecCondition = vfioStatusCheck;

        microvm.vms.cuda = {
          autostart = true;

          # Separate pkgs with CUDA support enabled
          pkgs = import inputs.nixpkgs {
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
            inherit (pkgs.stdenv.hostPlatform) system;
          };

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

              networking.firewall.allowedTCPPorts = [ 22 ];

              systemd = {
                network = {
                  enable = true;
                  networks."20-lan" = {
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
                };

                services = {
                  nvidia-gpu-config = {
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

                  ollama = {
                    after = [ "nvidia-gpu-config.service" ];
                    serviceConfig = {
                      DeviceAllow = lib.mkForce [ ];
                      DevicePolicy = lib.mkForce "auto";
                    };
                  };
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
                    "NVreg_UsePageAttributeTable=1"
                    "nvidia.NVreg_EnableGpuFirmware=1"
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

              hardware.graphics = {
                enable = true;
                extraPackages = [
                  pkgs.libva-vdpau-driver
                  pkgs.libvdpau
                  pkgs.libvdpau-va-gl
                  pkgs.nvidia-vaapi-driver
                  pkgs.vdpauinfo
                  pkgs.libva
                  pkgs.libva-utils
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

              environment.systemPackages = [
                pkgs.pciutils
                pkgs.lm_sensors
                pkgs.nvtopPackages.nvidia
                pkgs.libva-utils
                pkgs.gwe
                pkgs.vulkan-tools
                pkgs.mesa-demos
                pkgs.zenith-nvidia
                pkgs.nvitop
                pkgs.btop-cuda
              ];

              services = {
                openssh = {
                  enable = true;
                  settings = {
                    PasswordAuthentication = false;
                    PermitRootLogin = "yes";
                  };
                };

                xserver.videoDrivers = [ "nvidia" ];

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
                    OLLAMA_KV_CACHE_TYPE = "q8_0";
                    OLLAMA_KEEP_ALIVE = "10m";
                    OLLAMA_MAX_LOADED_MODELS = "4";
                    OLLAMA_MAX_QUEUE = "64";
                    OLLAMA_NUM_PARALLEL = "1";
                    OLLAMA_ORIGINS = "*";
                  };
                };
              };

              users = {
                mutableUsers = false;
                users = {
                  root.openssh.authorizedKeys.keys = pubkeys;
                  ollama = {
                    isSystemUser = true;
                    group = "ollama";
                    uid = 962;
                  };
                };
                groups.ollama.gid = 962;
              };

              system.stateVersion = "25.05";
            };
        };
      };
  };
}
