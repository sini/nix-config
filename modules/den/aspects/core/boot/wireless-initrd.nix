# Wireless initrd unlock — wpa_supplicant layer over core.boot.network-initrd
# for remote LUKS/ZFS unlock over WiFi.
#
# Opt in by including this aspect (it pulls in core.boot.network-initrd). The
# wireless interface is auto-detected from the facter hardware report, so the
# boot config is a no-op on hosts without a wireless NIC.
#
# Ported from main:modules/features/network-boot/wireless-initrd.nix.
{
  den,
  lib,
  ...
}:
{
  den.aspects.core.boot.wireless-initrd = {
    includes = [
      den.aspects.core.boot.network-initrd
    ];

    nixos =
      {
        config,
        pkgs,
        ...
      }:
      let
        # Auto-detect the wireless interface (wl*) from the facter report.
        wirelessInterface = lib.findFirst (
          iface:
          iface ? unix_device_name && lib.hasPrefix "wl" iface.unix_device_name && iface ? driver_modules
        ) null config.facter.report.hardware.network_interface;

        hasWireless = wirelessInterface != null;
        interface = if hasWireless then wirelessInterface.unix_device_name else "";

        inherit (config.age) secrets;
      in
      {
        boot.initrd = lib.mkIf hasWireless {
          # WPA crypto modules (network drivers come from core.boot.network-initrd).
          #
          # ccm/ctr/cmac are only the crypto *templates*. mac80211 asks the
          # crypto API for the composed algorithm "ccm(aes)", and the cipher it
          # composes over is resolved separately at runtime — no module link
          # records that dependency, so the initrd closure never pulls it in.
          # Without an AES implementation present, allocating ccm(aes) fails and
          # the association dies right after the 4-way handshake with "kernel
          # reports: key addition failed" / "Failed to set PTK to the driver",
          # which looks like a wifi problem but is a missing-cipher problem.
          # "aes" is the generic implementation and is what makes it work at
          # all; aesni_intel is the accelerated path.
          availableKernelModules = [
            "ccm"
            "ctr"
            "cmac"
            "aes"
            "aesni_intel"
          ];

          compressor = "zstd";
          compressorArgs = [ "-12" ];
          extraFirmwarePaths = [ "iwlwifi-so-a0-gf-a0-89.ucode.zst" ];

          systemd = {
            packages = [ pkgs.wpa_supplicant ];
            # The initrd's own systemd (boot.initrd.systemd.package) is already
            # in the bin env; listing pkgs.systemd here duplicated it. It was
            # harmless only while both resolved to a byte-identical derivation —
            # once the channels' systemd patch sets diverged the two distinct
            # store paths collided in buildEnv on bin/udevadm. Don't re-add it.
            initrdBin = [
              pkgs.wpa_supplicant
              pkgs.coreutils
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

          secrets."/etc/wpa_supplicant/wpa_supplicant-${interface}.conf" = secrets.wpa-supplicant-initrd.path;
        };

        # Wire generator dependency for wpa-supplicant-initrd (needs NixOS config context)
        age.secrets.wpa-supplicant-initrd.generator.dependencies = [
          config.age.secrets.wpa-supplicant-keys-for-initrd
        ];

        system.activationScripts = {
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
            "agenixEnsureInitrdWpaSupplicantConfig"
          ];
        };
      };

    age-secrets =
      { environment, ... }:
      let
        inherit ((environment.networks.default or { })) wireless;
      in
      {
        age.secrets = {
          wpa-supplicant-keys-for-initrd = {
            intermediary = true;
            rekeyFile = environment.wirelessSecretsFile;
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
