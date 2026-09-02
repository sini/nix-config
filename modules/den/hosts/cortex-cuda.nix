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

    # llama-cpp is the resident engine: this host serves gpt-oss-20b under the
    # cluster's own model alias, so it augments the in-cluster llama-cpp pool
    # instead of being a second, separately-addressed engine. Pool membership is
    # worth more here than single-stream speed.
    #
    # It does cost speed. NInfer measured 96.2 tok/s decode at the default int8
    # KV against llama-cpp's 45.5 on identical prompts (2.1x), for a 1.26x
    # prefill cost, and it keeps the shared 145,408-token pool described below.
    # Swapping back is `systemctl start ninfer` on the guest — the Conflicts=
    # evicts llama-cpp — made permanent by flipping autoStart here.
    settings.services.ai.ninfer = {
      autoStart = false;
      # Subagent fan-out: the KV pool is SHARED, not divided, so four admitted
      # requests draw from the same 145,408 tokens elastically. What N
      # multiplies is the per-sequence LinearAttentionStatePool slot (recurrent
      # state for the 48 linear-attention layers) plus draft/graph buffers —
      # paid out of the ~1 GiB the int8 profile freed.
      #
      # What 4 actually buys, measured here: DECODE batches (four 200-token
      # replies finish together in 9.7s against 2.9s for one, so ~83 tok/s
      # aggregate against ~68 single-stream, at ~21 tok/s per agent), while
      # PREFILL stays serialized — four 30K-token prompts finished 72s apart
      # even at 83% pool occupancy. So N agents with large prompts pay N x
      # prefill (~1050 tok/s) before the last one decodes. The engine never
      # over-admits and never truncates: prompt_tokens came back exact at 40K,
      # 100K and 137K, including a pair summing to 135% of the pool.
      maxConcurrency = 4;

      # Measured on this guest, not inherited: each admitted slot costs 390 MiB
      # of Engine runtime reservation, and the pool costs 35,904 bytes/token. At
      # the aspect default of 150912 a fourth slot is REJECTED by 142 MiB
      # (needs 7246216448, has 7096712192). 145408 is the largest 64-token page
      # boundary that fits all four: it starts and serves with 356 MiB free
      # after startup — better tolerance than the single-agent profile this
      # replaced — for 3.6% less context.
      maxContext = 145408; # 2272 pages x 64 tokens
      kvCapacity = "145408";
    };
  };

  den.aspects.cortex-cuda = {
    includes = with den.aspects; [
      roles.inference
      hardware.gpu.nvidia
    ];

    # M2: CUDA-enable the guest's package set at the microvm submodule level.
    microvm.pkgs = import inputs.nixpkgs-master {
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
          # 64 GB: headroom for llama-cpp's host PROMPT cache (--cache-ram 49152,
          # saved slot state for prompt reuse). Not KV spillover — stock
          # llama.cpp keeps active KV on the card.
          mem = 65536;

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
            {
              source = "/cache/var/lib/private/llama-cpp";
              mountPoint = "/cache/var/lib/private/llama-cpp";
              tag = "llama-cpp";
              proto = "virtiofs";
            }
            {
              source = "/cache/var/lib/private/ninfer";
              mountPoint = "/cache/var/lib/private/ninfer";
              tag = "ninfer";
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
        systemd.services.llama-cpp.after = [ "nvidia-gpu-config.service" ];
        systemd.services.ninfer.after = [ "nvidia-gpu-config.service" ];

        # One 24 GB card holds one engine, and ninfer.service already declares
        # Conflicts= against llama-cpp. Both being wantedBy multi-user.target
        # would race at boot and let systemd pick the winner, so exactly one may
        # autostart: llama-cpp keeps the aspect default and ninfer is held back
        # by autoStart = false above. The llama-cpp ASPECT stays untouched —
        # which engine is resident is a property of this host, not of llama-cpp.

        networking.firewall.allowedTCPPorts = [ 22 ];

        systemd.network = {
          enable = true;
          networks."20-lan" = {
            matchConfig.MACAddress = "02:00:00:01:01:01";
            networkConfig = {
              Address = [
                "10.9.2.2/16"
                "fe80::ff:fe01:101/64"
              ];
              Gateway = "10.9.2.1";
              DNS = [
                "1.1.1.1"
                "8.8.8.8"
              ];
              IPv6AcceptRA = true;
              DHCP = "no";
            };
            linkConfig = {
              MTUBytes = "9000";
            };
          };
        };

        boot.kernel.sysctl = {
          "net.core.default_qdisc" = "fq";
          "net.ipv4.tcp_congestion_control" = "bbr";
          "net.core.rmem_max" = 16777216;
          "net.core.wmem_max" = 16777216;
          "net.ipv4.tcp_rmem" = "4096 87380 16777216";
          "net.ipv4.tcp_wmem" = "4096 65536 16777216";
          "net.ipv4.tcp_fastopen" = 3;
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
