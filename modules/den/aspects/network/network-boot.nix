# Network boot: initrd with systemd-networkd, SSH, clevis/tang for ZFS unlock.
# Auto-detects network driver kernel modules from facter hardware report.
{
  den,
  self,
  config,
  lib,
  rootPath,
  ...
}:
let
  inherit (self.lib.users) resolveUsers getSshKeysForGroup;
  canonicalUsers = config.users or { };
  groupDefs = config.groups or { };
in
{
  den.aspects.network-boot = {
    includes = [
      den.aspects.initrd-bootstrap-keys
    ]
    ++ lib.attrValues den.aspects.network-boot._;

    _ = {
      config = den.lib.perHost (
        { host }:
        let
          hostOptions = {
            hostname = host.name;
            system-access-groups = host.system-access-groups or [ ];
            users = host.users or { };
          };
          resolvedUsers = resolveUsers lib canonicalUsers host.environment hostOptions groupDefs;
          secretPath = rootPath + "/.secrets/hosts/${host.name}";
          jweTokenPath = secretPath + "/zroot-key.jwe";
          hasJweToken = builtins.pathExists jweTokenPath;
          jweToken = builtins.path {
            path = jweTokenPath;
            name = "zroot-key.jwe";
          };
        in
        {
          nixos =
            {
              config,
              lib,
              ...
            }:
            let
              zfsEnabled = config.boot.supportedFilesystems.zfs or false;

              # Automatically collect all network driver modules from facter hardware report
              baseNetworkDriverModules = lib.unique (
                lib.flatten (
                  lib.filter (x: x != null) (
                    map (iface: iface.driver_modules or null) (config.facter.report.hardware.network_interface or [ ])
                  )
                )
              );

              # Map of kernel modules to their required dependencies
              moduleDependencies = {
                "mlx4_core" = [ "mlx4_en" ];
                "iwlwifi" = [ "iwlmvm" ];
              };

              # Expand modules to include their dependencies
              additionalDriverModules = lib.unique (
                lib.flatten (map (mod: moduleDependencies.${mod} or [ ]) baseNetworkDriverModules)
              );

              networkDriverModules = lib.unique (baseNetworkDriverModules ++ additionalDriverModules);
            in
            {
              boot.initrd = {
                availableKernelModules = [
                  # Network utilities
                  "bridge"
                  "bonding"
                  "8021q"
                  # TPM support
                  "tpm_crb"
                  "tpm_tis"
                ]
                ++ networkDriverModules;

                clevis = lib.mkIf (zfsEnabled && hasJweToken) {
                  enable = true;
                  useTang = true;
                  devices.zroot.secretFile = jweToken;
                };

                systemd = {
                  inherit (config.systemd) network;

                  # Wait for clevis to do its thing...
                  services.zfs-import-zroot.preStart = lib.mkIf zfsEnabled ''
                    /bin/sleep 10
                    ${lib.getExe config.boot.zfs.package} load-key -a
                  '';
                };

                network = {
                  enable = true;
                  ssh = {
                    enable = true;
                    port = 22;
                    authorizedKeys = getSshKeysForGroup resolvedUsers "wheel";
                    hostKeys = [
                      config.age.secrets.initrd_host_ed25519_key.path
                    ];
                  };
                };
              };
            };
        }
      );
    };
  };
}
