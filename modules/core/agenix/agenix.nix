{ inputs, ... }:
{
  flake.modules.nixos.agenix =
    { config, lib, ... }:
    {
      imports = [
        inputs.agenix.nixosModules.default
        inputs.agenix-rekey.nixosModules.default
      ];

      age.rekey = {
        inherit (inputs.self.secretsConfig) masterIdentities;
        storageMode = "local";
        hostPubkey = config.node.rootPath + "/ssh_host_ed25519_key.pub";
        generatedSecretsDir = ../../../secrets/generated/${config.node.hostname};
        localStorageDir = ../../../secrets/rekeyed/${config.node.hostname};
      };

      # Custom generator for ssh-ed25519 since upstream doesn't seem to work
      # Reported issue here: https://github.com/oddlama/agenix-rekey/issues/104
      age.generators.ssh-ed25519-tmpdir =
        {
          lib,
          name,
          pkgs,
          ...
        }:
        ''
          (
            tmpdir=$(mktemp -d)
            trap 'rm -rf "$tmpdir"' EXIT
            ${pkgs.openssh}/bin/ssh-keygen -q -t ed25519 -N "" \
              -C ${lib.escapeShellArg "${config.networking.hostName}:${name}"} \
              -f "$tmpdir/key"
            cat "$tmpdir/key" >&3
          ) 3>&1 >/dev/null 2>&1
        '';

      # Just before switching, remove the agenix directory if it exists.
      # This can happen when a secret is used in the initrd because it will
      # then be copied to the initramfs under the same path. This materializes
      # /run/agenix as a directory which will cause issues when the actual system tries
      # to create a link called /run/agenix. Agenix should probably fail in this case,
      # but doesn't and instead puts the generation link into the existing directory.
      # TODO See https://github.com/ryantm/agenix/pull/187.
      system.activationScripts = lib.mkIf (config.age.secrets != { }) {
        removeAgenixLink.text = "[[ ! -L /run/agenix ]] && [[ -d /run/agenix ]] && rm -rf /run/agenix";
        agenixNewGeneration.deps = [ "removeAgenixLink" ];
      };
    };
}
