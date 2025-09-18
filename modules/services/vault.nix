{
  flake.modules.nixos.vault =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      raftPeers = builtins.filter (peer: peer != config.networking.hostName) [
        "axon-01"
        "axon-02"
        "axon-03"
      ];
      vaultServiceHostname = "vault.${config.networking.domain}";
      acmeCertPath = "/var/lib/acme/${vaultServiceHostname}";

      mkRaftPeer = hostname: ''
        retry_join {
          leader_tls_servername = "${vaultServiceHostname}"
          leader_api_addr = "https://${vaultServiceHostname}:8200"
          leader_ca_cert_file = "${acmeCertPath}/fullchain.pem"
          leader_client_cert_file = "${acmeCertPath}/fullchain.pem"
          leader_client_key_file = "${acmeCertPath}/key.pem"
        }
      '';
    in
    {
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
        tlsCertFile = "${acmeCertPath}/fullchain.pem";
        tlsKeyFile = "${acmeCertPath}/key.pem";
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

          api_addr = "https://${vaultServiceHostname}"
          cluster_addr = "https://${config.networking.fqdn}:8201"

          # Swap is encrypted, so this is okay
          disable_mlock = false

          log_level = "Debug"
          log_format = "json"

          # tls_client_ca_file = "/etc/ssl/certs/vault-ca.pem"
        '';
      };

      # Open firewall for Vault API
      networking.firewall.allowedTCPPorts = [
        8200
        8201
      ];

      # Add vault user to keys group for secret access
      security.acme.certs.${vaultServiceHostname} = {
        group = "vault";
      };

      users.users.vault.extraGroups = [ "acme" ];
    };
}
