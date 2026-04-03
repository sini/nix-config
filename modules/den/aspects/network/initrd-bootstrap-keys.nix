# Bootstrap SSH host keys and wireless credentials for early boot (initrd).
# Secrets are defined directly in nixos module (not via secrets class) because
# wpa-supplicant-initrd has a generator dependency on wpa-supplicant-keys-for-initrd
# which requires config.age.secrets to be in scope.
{
  den,
  lib,
  ...
}:
{
  den.aspects.initrd-bootstrap-keys = {
    includes = lib.attrValues den.aspects.initrd-bootstrap-keys._;

    _ = {
      config = den.lib.perHost (
        { host }:
        let
          hasWireless = (host.environment.networks.default.wireless or null) != null;
          wirelessSecretsFile = host.environment.wirelessSecretsFile or null;
        in
        {
          nixos =
            {
              config,
              pkgs,
              lib,
              ...
            }:
            {
              age.secrets = {
                initrd_host_ed25519_key.generator.script = "ssh-key";
              }
              // lib.optionalAttrs (wirelessSecretsFile != null) {
                wpa-supplicant-keys-for-initrd = {
                  intermediary = true;
                  rekeyFile = wirelessSecretsFile;
                };
              }
              // lib.optionalAttrs hasWireless {
                wpa-supplicant-initrd = {
                  generator = {
                    dependencies = lib.optional (
                      config.age.secrets ? wpa-supplicant-keys-for-initrd
                    ) config.age.secrets.wpa-supplicant-keys-for-initrd;
                    script = "wpa-supplicant-config";
                  };
                  settings.networks = {
                    "${host.environment.networks.default.wireless.ssid}".pskRaw =
                      host.environment.networks.default.wireless.pskRef;
                  };
                };
              };

              system.activationScripts = {
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

                agenixEnsureInitrdWpaSupplicantConfig = lib.mkIf hasWireless {
                  text = ''
                    if [[ ! -e ${config.age.secrets.wpa-supplicant-initrd.path} ]]; then
                      cat > ${config.age.secrets.wpa-supplicant-initrd.path} <<'WPAEOF'
                    ctrl_interface=/var/run/wpa_supplicant
                    update_config=1
                    WPAEOF
                      chmod 600 ${config.age.secrets.wpa-supplicant-initrd.path}
                    fi
                  '';
                  deps = [ "agenixInstall" ];
                };

                agenixChown.deps = [
                  "agenixEnsureInitrdHostkey"
                ]
                ++ lib.optional hasWireless "agenixEnsureInitrdWpaSupplicantConfig";
              };
            };
        }
      );
    };
  };
}
