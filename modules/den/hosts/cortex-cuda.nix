{ den, inputs, ... }:
{
  den.hosts.x86_64-linux.cortex-cuda = {
    channel = "nixpkgs-master";
    intoAttr = [ ]; # do not emit a standalone nixosConfiguration output

    networking.interfaces.vm-cuda.ipv4 = [ "10.9.2.2/16" ];

    # B2: passthrough intent on the ENTITY (the producer reads vm.microvm.passthrough).
    microvm.passthrough = [ "nvidia" ];

    # Settings on the ENTITY (cascade reads hosts.<name>.settings) → ollama-cuda.
    settings.services.ai.ollama.acceleration = "cuda";
  };

  den.aspects.cortex-cuda = {
    includes = with den.aspects; [
      roles.inference
      hardware.gpu.nvidia
    ];

    # M2: CUDA-enable the guest's package set at the microvm submodule level.
    microvm.pkgs = import inputs.nixpkgs {
      system = "x86_64-linux";
      config = {
        allowUnfree = true;
        nvidia.acceptLicense = true;
        cudaSupport = true;
        cudnnSupport = true;
      };
    };

    nixos =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      {
        networking.hostName = "cortex-cuda";
        system.stateVersion = "25.05";

        # The guest uses our externally-created CUDA pkgs (microvm.pkgs), so its
        # own nixpkgs.config must be empty (allowUnfree/acceptLicense are baked
        # into that external instance). hardware.gpu.nvidia otherwise sets
        # nixpkgs.config.nvidia.acceptLicense, tripping the external-instance assertion.
        nixpkgs.config = lib.mkForce { };

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
              source = "/cache/var/lib/private/ollama";
              mountPoint = "/cache/var/lib/private/ollama";
              tag = "ollama";
              proto = "virtiofs";
            }
          ];
        };

        environment.etc."machine-id" = {
          mode = "0644";
          text = (builtins.hashString "md5" "cortex-cuda") + "\n";
        };

        systemd.services.nvidia-gpu-config = {
          description = "Configure NVIDIA GPU";
          wantedBy = [ "multi-user.target" ];
          path = [ config.hardware.nvidia.package.bin ];
          script = ''
            nvidia-smi -pl 450
            nvidia-smi -rmc
          '';
          serviceConfig.Type = "oneshot";
        };
        systemd.services.ollama.after = [ "nvidia-gpu-config.service" ];

        networking.firewall.allowedTCPPorts = [ 22 ];

        systemd.network = {
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

        services.openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = false;
            PermitRootLogin = "yes";
          };
        };
      };
  };
}
