{
  features.initrd-bootstrap-keys = {
    requires = [
      "network-boot"
      "wireless-initrd"
    ];

    linux =
      {
        config,
        environment,
        lib,
        pkgs,
        ...
      }:
      {
        age.secrets = {
          # Ensure there is an initrd host-key
          initrd_host_ed25519_key.generator.script = "ssh-key";

          wpa-supplicant = {
            rekeyFile = environment.wirelessSecretsFile;
            owner = "wpa_supplicant";
          };

          # NOTE: this does expose configured wireless passwords into the unencrypted
          # initrd, but if you have access to the unbooted machine you probably have
          # my wifi password...
          wpa-supplicant-initrd = {
            generator = {
              dependencies = [ config.age.secrets.wpa-supplicant ];
              script = "wpa-supplicant-config";
            };

            owner = "wpa_supplicant";

            settings.networks = lib.mkIf (environment.networks.default.wireless != null) {
              "${environment.networks.default.wireless.ssid}".pskRaw =
                environment.networks.default.wireless.pskRef;
            };
          };
        };

        system.activationScripts = {
          # Make sure that there is always a valid initrd hostkey available that can be installed into
          # the initrd. When bootstrapping a system (or re-installing), agenix cannot succeed in decrypting
          # whatever is given, since the correct hostkey doesn't even exist yet. We still require
          # a valid hostkey to be available so that the initrd can be generated successfully.
          # The correct initrd host-key will be installed with the next update after the host is booted
          # for the first time, and the secrets were rekeyed for the the new host identity.
          agenixEnsureInitrdHostkey = {
            text = ''
              [[ -e ${config.age.secrets.initrd_host_ed25519_key.path} ]] \
                || ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f ${config.age.secrets.initrd_host_ed25519_key.path}
            '';
            deps = [
              "agenixInstall"
              "users"
            ];
          };

          agenixEnsureInitrdWpaSupplicantConfig = {
            text = ''
              if [[ ! -e ${config.age.secrets.wpa-supplicant-initrd.path} ]]; then
                # Create a minimal valid wpa_supplicant.conf as placeholder
                cat > ${config.age.secrets.wpa-supplicant-initrd.path} <<'EOF'
              # Placeholder wpa_supplicant config for initial deployment
              # This will be replaced with the real config after agenix rekey
              ctrl_interface=/var/run/wpa_supplicant
              update_config=1
              EOF
                chmod 600 ${config.age.secrets.wpa-supplicant-initrd.path}
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
      };
  };
}
