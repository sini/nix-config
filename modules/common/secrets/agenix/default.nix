{
  config,
  inputs,
  lib,
  ...
}:
{
  config = {
    # Define local repo secrets
    repo.secretFiles =
      let
        local = config.node.secretsDir + "/local.nix.age";
      in
      lib.optionalAttrs (lib.pathExists local) { inherit local; };

    age = {
      identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

      # Setup secret rekeying parameters
      rekey = {
        inherit (inputs.self.secretsConfig)
          masterIdentities
          extraEncryptionPubkeys
          ;

        hostPubkey = config.node.rootPath + "/ssh_host_ed25519_key.pub";
        storageMode = "local";
        generatedSecretsDir = ../../../.. + "/secrets/generated/${config.node.hostname}";
        localStorageDir = ../../../.. + "/secrets/rekeyed/${config.node.hostname}";
      };

      # Custom generator for ssh-ed25519 since upstream doesn't seem to work
      # Reported issue here: https://github.com/oddlama/agenix-rekey/issues/104
      generators.ssh-ed25519-tmpdir =
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

      generators.ssh-ed25519-python =
        {
          pkgs,
          ...
        }:
        let
          # Python script to generate a key in memory and print to stdout
          keygenScript = pkgs.writeText "ssh-ed25519-keygen.py" ''
            import sys
            from cryptography.hazmat.primitives import serialization as crypto_serialization
            from cryptography.hazmat.primitives.asymmetric import ed25519

            private_key = ed25519.Ed25519PrivateKey.generate()

            # Correctly serialize the key to the OpenSSH format,
            # wrapped in PEM encoding.
            ssh_private_key = private_key.private_bytes(
                encoding=crypto_serialization.Encoding.PEM,
                format=crypto_serialization.PrivateFormat.OpenSSH,
                encryption_algorithm=crypto_serialization.NoEncryption()
            )

            # Write the key directly to standard output
            sys.stdout.buffer.write(ssh_private_key)
          '';

          # A minimal Python environment with the required library
          pythonWithCrypto = pkgs.python3.withPackages (ps: [ ps.cryptography ]);
        in
        # The final shell command to be executed by agenix
        ''
          ${pythonWithCrypto}/bin/python ${keygenScript}
        '';
    };

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
