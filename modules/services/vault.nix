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
      # Find all hosts with vault role in the same environment, excluding current host
      vaultHosts = lib.attrsets.filterAttrs (
        hostname: hostConfig:
        builtins.elem "vault" hostConfig.roles
        && hostConfig.environment == hostOptions.environment
        && hostname != config.networking.hostName
      ) flakeHosts;

      raftPeers = lib.attrNames vaultHosts;
      vaultServiceHostname = "vault.${config.networking.domain}";
      # acmeCertPath = "/var/lib/acme/${vaultServiceHostname}";

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
      # Age secrets for vault certificates
      age.secrets.vault-ca = {
        rekeyFile = rootPath + "/.secrets/services/vault/vault-ca.age";
        owner = "vault";
        group = "vault";
      };
      age.secrets."vault-${config.networking.hostName}" = {
        rekeyFile = rootPath + "/.secrets/services/vault/vault-${config.networking.hostName}.age";
        owner = "vault";
        group = "vault";
      };
      age.secrets."vault-${config.networking.hostName}-key" = {
        rekeyFile = rootPath + "/.secrets/services/vault/vault-${config.networking.hostName}-key.age";
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

          # Use internal CA for client certificate validation
          tls_client_ca_file = "${config.age.secrets.vault-ca.path}"
        '';
      };

      # Open firewall for Vault API
      networking.firewall.allowedTCPPorts = [
        8200
        8201
      ];

      # Note: ACME certificates can still be used for a reverse proxy
      # if external access to vault.${domain} is needed, but vault-to-vault
      # communication now uses internal certificates
    };
}
