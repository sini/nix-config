{ config, rootPath, ... }:
let
  flakeHosts = config.flake.hosts;
in
{
  flake.modules.nixos.vault =
    {
      config,
      lib,
      pkgs,
      hostOptions,
      ...
    }:
    let
      # Find all hosts with vault role in the same environment (including ourselves)
      allVaultHosts = lib.attrsets.filterAttrs (
        hostname: hostConfig:
        builtins.elem "vault" hostConfig.roles && hostConfig.environment == hostOptions.environment
      ) flakeHosts;

      # Raft peers excludes current host
      raftPeers = lib.attrNames (
        lib.attrsets.filterAttrs (
          hostname: hostConfig: hostname != config.networking.hostName
        ) allVaultHosts
      );

      vaultServiceHostname = "vault.${config.networking.domain}";

      mkRaftPeer = hostname: ''
        retry_join {
          leader_tls_servername = "${hostname}"
          leader_api_addr = "https://${hostname}:8200"
          leader_ca_cert_file = "${config.age.secrets.vault-ca.path}"
          leader_client_cert_file = "${config.age.secrets."vault-${config.networking.hostName}".path}"
          leader_client_key_file = "${config.age.secrets."vault-${config.networking.hostName}-key".path}"
        }
      '';
    in
    {
      # Age secrets for vault certificates (organized by environment)
      age.secrets.vault-ca = {
        rekeyFile = rootPath + "/.secrets/services/vault/${hostOptions.environment}/vault-ca.age";
        owner = "vault";
        group = "vault";
      };

      age.secrets."vault-${config.networking.hostName}" = {
        rekeyFile =
          rootPath
          + "/.secrets/services/vault/${hostOptions.environment}/vault-${config.networking.hostName}.age";
        owner = "vault";
        group = "vault";
      };

      age.secrets."vault-${config.networking.hostName}-key" = {
        rekeyFile =
          rootPath
          + "/.secrets/services/vault/${hostOptions.environment}/vault-${config.networking.hostName}-key.age";
        owner = "vault";
        group = "vault";
        mode = "0400";
      };

      # Unseal keys for automatic unsealing (shared across all vault nodes in environment)
      age.secrets.vault-unseal-key-1 = {
        rekeyFile = rootPath + "/.secrets/services/vault/${hostOptions.environment}/vault-unseal-key-1.age";
        owner = "vault";
        group = "vault";
        mode = "0400";
      };

      age.secrets.vault-unseal-key-2 = {
        rekeyFile = rootPath + "/.secrets/services/vault/${hostOptions.environment}/vault-unseal-key-2.age";
        owner = "vault";
        group = "vault";
        mode = "0400";
      };

      age.secrets.vault-unseal-key-3 = {
        rekeyFile = rootPath + "/.secrets/services/vault/${hostOptions.environment}/vault-unseal-key-3.age";
        owner = "vault";
        group = "vault";
        mode = "0400";
      };

      environment.systemPackages = with pkgs; [
        vault
        openssl
      ];

      environment.sessionVariables = {
        # Allow the vault CLI to hit the local vault instance, not the active VIP
        VAULT_ADDR = "https://${config.networking.fqdn}:8200";
      };

      services.vault = {
        enable = true;
        # Use internal certificates for vault-to-vault communication
        tlsCertFile = config.age.secrets."vault-${config.networking.hostName}".path;
        tlsKeyFile = config.age.secrets."vault-${config.networking.hostName}-key".path;
        # Use the binary version of vault which contains the vendored
        # dependencies. This is required for the vault UI to work.
        package = pkgs.vault-bin;
        address = "[::]:8200";
        storageBackend = "raft";
        storageConfig = ''
          node_id = "${config.networking.hostName}"
        ''
        + lib.concatStringsSep "\n" (map mkRaftPeer raftPeers);
        extraConfig = ''
          ui = true

          api_addr = "https://${vaultServiceHostname}:8200"
          cluster_addr = "https://${config.networking.fqdn}:8201"

          # Swap is encrypted, so this is okay
          disable_mlock = false

          log_level = "Debug"
          log_format = "json"

        '';
      };

      # Auto-unseal service
      systemd.services.vault-auto-unseal = {
        description = "Vault Auto Unseal";
        after = [ "vault.service" ];
        wants = [ "vault.service" ];
        wantedBy = [ "vault.service" ];

        serviceConfig = {
          Type = "oneshot";
          User = "vault";
          Group = "vault";
          RemainAfterExit = true;
        };

        environment = {
          VAULT_ADDR = "https://${config.networking.fqdn}:8200";
          VAULT_CACERT = config.age.secrets.vault-ca.path;
        };

        script = ''
          set -euo pipefail

          # Wait for vault to be responsive (vault status returns 2 when sealed, which is still responsive)
          max_attempts=30
          attempt=0
          while [ $attempt -lt $max_attempts ]; do
            if vault_output=$(${pkgs.vault}/bin/vault status -tls-skip-verify 2>&1); then
              # Exit code 0 - vault is responsive and unsealed
              break
            elif echo "$vault_output" | grep -q "Sealed.*true\|Initialized.*true"; then
              # Exit code 2 - vault is responsive but sealed (this is what we expect)
              break
            fi
            echo "Waiting for vault to be responsive... (attempt $((attempt + 1))/$max_attempts)"
            sleep 5
            attempt=$((attempt + 1))
          done

          if [ $attempt -eq $max_attempts ]; then
            echo "Vault did not become responsive after $max_attempts attempts"
            exit 1
          fi

          # Check if vault is already unsealed
          if ${pkgs.vault}/bin/vault status -tls-skip-verify | grep -q "Sealed.*false"; then
            echo "Vault is already unsealed"
            exit 0
          fi

          echo "Vault is sealed, attempting to unseal..."

          # Try each unseal key
          for key_file in "${config.age.secrets.vault-unseal-key-1.path}" \
                          "${config.age.secrets.vault-unseal-key-2.path}" \
                          "${config.age.secrets.vault-unseal-key-3.path}"; do
            if [ -f "$key_file" ]; then
              echo "Using unseal key: $key_file"
              if ${pkgs.vault}/bin/vault operator unseal -tls-skip-verify "$(cat "$key_file")"; then
                echo "Successfully applied unseal key"
              else
                echo "Failed to apply unseal key from $key_file"
              fi

              # Check if we're unsealed now
              if ${pkgs.vault}/bin/vault status -tls-skip-verify | grep -q "Sealed.*false"; then
                echo "Vault successfully unsealed!"
                exit 0
              fi
            else
              echo "Unseal key file not found: $key_file"
            fi
          done

          echo "Failed to unseal vault with available keys"
          exit 1
        '';
      };

      # Open firewall for Vault API
      networking.firewall.allowedTCPPorts = [
        8200
        8201
      ];
    };
}
