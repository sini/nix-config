# Generate a wpa_supplicant.conf for initrd from networking.wireless.networks config
{
  features.agenix-generators.system =
    { lib, ... }:
    {
      age.generators.wpa-supplicant-config =
        {
          decrypt,
          deps,
          pkgs,
          secret,
          ...
        }:
        let
          # Get networks from settings
          networks = secret.settings.networks or { };

          # Generate shell commands for a single SSID
          generateNetworkBlock =
            ssid: networkConfig: secretFile:
            let
              # Extract the pskRaw reference (e.g., "ext:psk_arcade" -> "psk_arcade")
              pskKey =
                if lib.hasPrefix "ext:" networkConfig.pskRaw then
                  lib.removePrefix "ext:" networkConfig.pskRaw
                else
                  throw "pskRaw must be in format 'ext:keyname'";

              priority = toString (networkConfig.priority or 1);
            in
            ''
              psk_value=$(${decrypt} ${lib.escapeShellArg secretFile} | ${pkgs.gnugrep}/bin/grep -E "^${lib.escapeShellArg pskKey}=" | ${pkgs.coreutils}/bin/cut -d= -f2-)
              printf 'network={\n  ssid=%s\n  key_mgmt=WPA-PSK WPA-EAP SAE FT-PSK FT-EAP FT-SAE\n  psk="%s"\n  priority=%s\n}\n\n' ${lib.escapeShellArg ssid} "$psk_value" ${lib.escapeShellArg priority}
            '';

          # The secret file should be the first (and only) dependency
          secretFile = (builtins.head deps).file;

          # Generate all network blocks
          networkBlocks = lib.concatStringsSep "\n" (
            lib.mapAttrsToList (ssid: cfg: generateNetworkBlock ssid cfg secretFile) networks
          );
        in
        ''
          ${networkBlocks}
          printf 'pmf=1\nbgscan="simple:30:-70:3600"\n'
        '';
    };
}
