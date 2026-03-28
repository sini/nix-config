{
  features.initrd-bootstrap-keys = {
    linux =
      {
        config,
        secrets,
        environment,
        pkgs,
        ...
      }:
      {
        age.secrets = {
          # Ensure there is an initrd host-key
          initrd_host_ed25519_key.generator.script = "ssh-key";

          wpa-supplicant-keys-for-initrd = {
            intermediary = true;
            rekeyFile = environment.wirelessSecretsFile;
          };

          # NOTE: this does expose configured wireless passwords into the unencrypted
          # initrd, but if you have access to the unbooted machine you probably have
          # my wifi password...
          wpa-supplicant-initrd = {
            generator = {
              dependencies = [ secrets.wpa-supplicant-keys-for-initrd ];
              script = "wpa-supplicant-config";
            };

            settings.networks =
              if environment.networks.default.wireless != null then
                {
                  "${environment.networks.default.wireless.ssid}".pskRaw =
                    environment.networks.default.wireless.pskRef;
                }
              else
                { };
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
              [[ -e ${secrets.initrd_host_ed25519_key} ]] \
                || ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f ${secrets.initrd_host_ed25519_key}
            '';
            deps = [
              "agenixInstall"
              "users"
            ];
          };

          agenixEnsureInitrdWpaSupplicantConfig = {
            text = ''
              if [[ ! -e ${secrets.wpa-supplicant-initrd} ]]; then
                # Create a minimal valid wpa_supplicant.conf as placeholder
                cat > ${secrets.wpa-supplicant-initrd} <<'EOF'
              # Placeholder wpa_supplicant config for initial deployment
              # This will be replaced with the real config after agenix rekey
              ctrl_interface=/var/run/wpa_supplicant
              update_config=1
              EOF
                chmod 600 ${secrets.wpa-supplicant-initrd}
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
