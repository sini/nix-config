# Vault — HashiCorp Vault with raft storage, TLS, and auto-unseal.
#
# Emits vault-peers quirk; consumes collected peers for raft join config.
{
  den.aspects.services.security.vault = {
    # Emit peer info for raft cluster formation
    vault-peers =
      { host, ... }:
      {
        hostname = host.name;
      };

    nixos =
      {
        vault-peers,
        config,
        environment,
        host,
        lib,
        pkgs,
        ...
      }:
      let

        # Raft peers (same-environment scoping guaranteed by collect-vault-peers policy)
        raftPeers = map (p: p.hostname) (lib.filter (p: p.hostname != host.name) vault-peers);

        vaultServiceHostname = environment.getDomainFor "vault";

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
        environment = {
          systemPackages = [
            pkgs.vault
            pkgs.openssl
          ];

          sessionVariables = {
            VAULT_ADDR = "https://${config.networking.fqdn}:8200";
          };
        };

        services.vault = {
          enable = true;
          tlsCertFile = config.age.secrets."vault-${config.networking.hostName}".path;
          tlsKeyFile = config.age.secrets."vault-${config.networking.hostName}-key".path;
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

            # Wait for vault to be responsive (vault status returns 2 when sealed)
            max_attempts=30
            attempt=0
            while [ $attempt -lt $max_attempts ]; do
              if vault_output=$(${pkgs.vault}/bin/vault status -tls-skip-verify 2>&1); then
                break
              elif echo "$vault_output" | grep -q "Sealed.*true\|Initialized.*true"; then
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
      };

    age-secrets =
      { environment, host, ... }:
      {
        age.secrets = {
          vault-ca = {
            rekeyFile = environment.secretPath + "/vault/vault-ca.age";
            owner = "vault";
            group = "vault";
          };

          "vault-${host.name}" = {
            rekeyFile = environment.secretPath + "/vault/vault-${host.name}.age";
            owner = "vault";
            group = "vault";
          };

          "vault-${host.name}-key" = {
            rekeyFile = environment.secretPath + "/vault/vault-${host.name}-key.age";
            owner = "vault";
            group = "vault";
            mode = "0400";
          };

          vault-unseal-key-1 = {
            rekeyFile = environment.secretPath + "/vault/vault-unseal-key-1.age";
            owner = "vault";
            group = "vault";
            mode = "0400";
          };

          vault-unseal-key-2 = {
            rekeyFile = environment.secretPath + "/vault/vault-unseal-key-2.age";
            owner = "vault";
            group = "vault";
            mode = "0400";
          };

          vault-unseal-key-3 = {
            rekeyFile = environment.secretPath + "/vault/vault-unseal-key-3.age";
            owner = "vault";
            group = "vault";
            mode = "0400";
          };
        };
      };

    service-domains = [ "vault" ];

    firewall = {
      networking.firewall.allowedTCPPorts = [
        8200
        8201
      ];
    };

    persist = {
      directories = [
        {
          directory = "/var/lib/vault";
          user = "vault";
          group = "vault";
          mode = "0755";
        }
      ];
    };
  };
}
