# Network boot — Clevis+Tang LUKS/ZFS unlock, initrd SSH, wireless initrd.
#
# Ported from main:modules/features/network-boot/ (network-boot.nix + initrd-bootstrap-keys.nix).
{
  lib,
  config,
  ...
}:
let
  environments = config.den.environments;
  allUsers = config.den.users.registry or { };

  # Collect SSH keys from users in the "wheel" or "admins" groups
  wheelSshKeys = lib.concatMap (
    u:
    lib.optionals (builtins.any (g: g == "admins" || g == "wheel") (u.groups or [ ])) (
      map (k: k.key) (u.identity.sshKeys or [ ])
    )
  ) (lib.attrValues allUsers);
in
{
  den.aspects.network.network-boot = {
    nixos =
      {
        config,
        pkgs,
        host,
        ...
      }:
      let

        jweToken = builtins.path {
          path = host.secretPath + "/zroot-key.jwe";
          name = "zroot-key.jwe";
        };

        # Collect network driver modules from facter hardware report
        baseNetworkDriverModules = lib.unique (
          lib.flatten (
            lib.filter (x: x != null) (
              map (iface: iface.driver_modules or null) config.facter.report.hardware.network_interface
            )
          )
        );

        moduleDependencies = {
          "mlx4_core" = [ "mlx4_en" ];
          "iwlwifi" = [ "iwlmvm" ];
        };

        additionalDriverModules = lib.unique (
          lib.flatten (map (mod: moduleDependencies.${mod} or [ ]) baseNetworkDriverModules)
        );

        networkDriverModules = lib.unique (baseNetworkDriverModules ++ additionalDriverModules);

        # Wireless initrd support
        wirelessInterface = lib.findFirst (
          iface:
          iface ? unix_device_name && lib.hasPrefix "wl" iface.unix_device_name && iface ? driver_modules
        ) null config.facter.report.hardware.network_interface;

        hasWireless = host.settings.network.wireless-initrd or false;
        interface = if hasWireless then wirelessInterface.unix_device_name else "";

        inherit (config.age) secrets;
      in
      lib.mkMerge [
        {
          boot.initrd = {
            availableKernelModules = [
              "bridge"
              "bonding"
              "8021q"
              "tpm_crb"
              "tpm_tis"
            ]
            ++ networkDriverModules
            ++ lib.optionals hasWireless [
              "ccm"
              "ctr"
              "cmac"
            ];

            clevis = lib.mkIf (config.boot.supportedFilesystems.zfs or false) {
              enable = true;
              useTang = true;
              devices.zroot.secretFile = jweToken;
            };

            systemd = {
              inherit (config.systemd) network;
            };

            network = {
              enable = true;
              ssh = {
                enable = true;
                port = 22;
                authorizedKeys = wheelSshKeys;
                hostKeys = [
                  secrets.initrd_host_ed25519_key.path
                ];
              };
            };
          }
          // lib.optionalAttrs hasWireless {
            systemd = {
              packages = [ pkgs.wpa_supplicant ];
              initrdBin = [
                pkgs.wpa_supplicant
                pkgs.coreutils
                pkgs.systemd
                pkgs.iproute2
              ];

              targets.initrd.wants = [
                "wpa_supplicant@${interface}.service"
                "systemd-resolved.service"
              ];
              services = {
                "wpa_supplicant@" = {
                  unitConfig.DefaultDependencies = false;
                  after = lib.mkForce [ "sys-subsystem-net-devices-%i.device" ];
                  requires = lib.mkForce [ "sys-subsystem-net-devices-%i.device" ];
                };

                systemd-networkd.after = [ "wpa_supplicant@${interface}.service" ];

                sshd = {
                  after = lib.mkForce [ "network.target" ];
                  wants = lib.mkForce [ ];
                  requires = lib.mkForce [ ];
                };

                resolved.enable = true;
              };
            };

            compressor = "zstd";
            compressorArgs = [ "-12" ];
            extraFirmwarePaths = [ "iwlwifi-so-a0-gf-a0-89.ucode.zst" ];
            secrets."/etc/wpa_supplicant/wpa_supplicant-${interface}.conf" = secrets.wpa-supplicant-initrd.path;
          };

          # Wire generator dependency for wpa-supplicant-initrd (needs NixOS config context)
          age.secrets.wpa-supplicant-initrd.generator.dependencies = [
            config.age.secrets.wpa-supplicant-keys-for-initrd
          ];

          # Ensure valid initrd host key exists even on first boot
          system.activationScripts = {
            agenixEnsureInitrdHostkey = {
              text = ''
                [[ -e ${secrets.initrd_host_ed25519_key.path} ]] \
                  || ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f ${secrets.initrd_host_ed25519_key.path}
              '';
              deps = [
                "agenixInstall"
                "users"
              ];
            };

            agenixEnsureInitrdWpaSupplicantConfig = {
              text = ''
                if [[ ! -e ${secrets.wpa-supplicant-initrd.path} ]]; then
                  cat > ${secrets.wpa-supplicant-initrd.path} <<'EOF'
                ctrl_interface=/var/run/wpa_supplicant
                update_config=1
                EOF
                  chmod 600 ${secrets.wpa-supplicant-initrd.path}
                fi
              '';
              deps = [
                "agenixInstall"
              ];
            };

            agenixChown.deps = [
              "agenixEnsureInitrdHostkey"
              "agenixEnsureInitrdWpaSupplicantConfig"
            ];
          };
        }
        # Separate mkMerge entry: boot.initrd.systemd.services can't coexist
        # with boot.initrd = { systemd = { inherit network; }; } in the same
        # attrset — the inherit clobbers sibling keys.
        {
          boot.initrd.systemd.services.zfs-import-zroot.preStart = ''
            /bin/sleep 10
            ${lib.getExe config.boot.zfs.package} load-key -a
          '';
        }
      ];

    persist = {
      files = [
        "/etc/ssh/initrd_host_ed25519_key"
        "/etc/ssh/initrd_host_ed25519_key.pub"
      ];
    };

    age-secrets =
      { host, ... }:
      let
        env = environments.${host.environment};
        inherit ((env.networks.default or { })) wireless;
      in
      {
        age.secrets = {
          initrd_host_ed25519_key.generator.script = "ssh-key";

          wpa-supplicant-keys-for-initrd = {
            intermediary = true;
            rekeyFile = env.wirelessSecretsFile;
          };

          wpa-supplicant-initrd = {
            generator.script = "wpa-supplicant-config";
            settings.networks =
              if wireless != null then { "${wireless.ssid}".pskRaw = wireless.pskRef; } else { };
          };
        };
      };
  };
}
