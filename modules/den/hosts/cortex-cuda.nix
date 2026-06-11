{ den, inputs, ... }:
{
  den.hosts.x86_64-linux.cortex-cuda = {
    channel = "nixpkgs-master";
    environment = "dev";
    intoAttr = [ ]; # do not emit a standalone nixosConfiguration output (delivered as a child)

    # Delivered as a microvm guest of cortex (see cortex.nix `guests`).
    # The guests policy resolves this as a raw entity bypassing the host
    # submodule (gap G6), so the secretPath/public_key submodule defaults never
    # compute.
    # Retarget agenix at the PARENT's (cortex's) real key so the agenix battery
    # resolves the host pubkey without a readFile throw and rekeys against
    # cortex's identity.
    secretPath = ./. + "/../../../.secrets/hosts/cortex";
    public_key = ./. + "/../../../.secrets/hosts/cortex/ssh_host_ed25519_key.pub";

    # The guest is a raw entity (no host-submodule `facts` default), but fleet
    # users that participate now (e.g. shuo → roles.default → core.system.facter)
    # read host.facts. Point it at the PARENT's facter report — the guest runs on
    # cortex's hardware (GPU passthrough device IDs derive from it).
    facts = ./. + "/../../../hosts/cortex/facter.json";

    networking.interfaces.vm-cuda.ipv4 = [ "10.9.2.2/16" ];

    # B2: passthrough intent on the ENTITY (the host-side GPU overlay reads
    # vm.microvm.passthrough).
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
        # The participating fleet baseline (core.nix.stateVersion) sets the
        # fleet default; this guest pins its own. mkForce to win the merge.
        system.stateVersion = lib.mkForce "25.05";

        # The fleet users participating on this guest drag roles.default →
        # core.network.tailscale in via the user scopes. This headless GPU
        # inference VM is reached via the host on the internal bridge
        # (10.9.2.2), not the tailnet, and the user-scope tailscale age-secret
        # is not collected for a delivered guest. Neutralize it: mkForce the
        # authKeyFile so the absent `age.secrets.tailscale-auth-key` reference
        # is never forced, and disable the daemon. Fleet IDENTITY participation
        # (agenix host key, core.users, collect/quirks) stays intact.
        services.tailscale.enable = lib.mkForce false;
        services.tailscale.authKeyFile = lib.mkForce "/dev/null";

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

        # The fleet users participating here (shuo/sini/will) use the zsh login
        # shell (core.users.shell) but the host-level apps.shell.zsh that backs
        # it lives in roles.default, which this guest doesn't include. Enable it
        # so their shells resolve.
        programs.zsh.enable = true;

        services.openssh = {
          enable = true;
          settings = {
            PasswordAuthentication = false;
            # Guest uses root key login (root authorizedKeys injected host-side);
            # override the fleet baseline's "prohibit-password".
            PermitRootLogin = lib.mkForce "yes";
          };
        };
      };
  };
}
