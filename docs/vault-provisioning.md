# Vault Provisioning Guide

This guide covers how to provision a new HashiCorp Vault cluster in your NixOS homelab environment.

## Overview

Vault is configured as a highly-available Raft cluster with:

- Environment-based isolation (prod/dev)
- Automatic TLS certificate management
- Automatic unsealing with encrypted keys
- Raft storage backend for HA

## Prerequisites

1. Hosts with the `vault` role assigned
1. Each host must have network connectivity to other vault nodes
1. agenix-rekey configured for secret management

## Step 1: Configure Hosts

Add the `vault` role to hosts in your desired environment:

```nix
# modules/hosts/[hostname]/host.nix
{
  flake.hosts.[hostname] = {
    roles = [ "vault" "other-roles" ];
    environment = "prod"; # or "dev"
    # ... other config
  };
}
```

Ensure hosts are properly configured in `flake.nix` with correct IP addresses and domains.

## Step 2: Generate Certificates

Use the certificate generation script to create TLS certificates for your vault cluster:

```bash
# Generate certificates for a specific environment
./scripts/generate-vault-certs.sh dev

# Or generate for all environments with vault hosts
./scripts/generate-vault-certs.sh
```

This script will:

- Automatically discover vault hosts from your flake configuration
- Generate environment-specific CA certificates
- Create individual host certificates with proper SANs
- Organize certificates by environment

## Step 3: Configure Secrets

Create the environment-specific secrets directory and add certificates:

```bash
# Create secrets directory structure
mkdir -p .secrets/services/vault/dev
mkdir -p .secrets/services/vault/prod

# Copy generated certificates (example for dev environment)
cp /tmp/tmp.xxxxx/dev/* .secrets/services/vault/dev/
```

Encrypt the certificates with agenix-rekey:

```bash
# For each certificate file
agenix-rekey edit .secrets/services/vault/dev/vault-ca.age
agenix-rekey edit .secrets/services/vault/dev/vault-ca-key.age
agenix-rekey edit .secrets/services/vault/dev/vault-[hostname].age
agenix-rekey edit .secrets/services/vault/dev/vault-[hostname]-key.age
```

## Step 4: Generate Unseal Keys

After the initial deployment, you'll need to initialize vault and configure unseal keys:

```bash
# Initialize vault on one of the nodes
export VAULT_ADDR="https://[first-vault-host]:8200"
export VAULT_SKIP_VERIFY=true

# Initialize vault (this generates unseal keys and root token)
vault operator init -key-shares=5 -key-threshold=3

# Save the unseal keys to environment-specific secrets
agenix-rekey edit .secrets/services/vault/dev/vault-unseal-key-1.age
agenix-rekey edit .secrets/services/vault/dev/vault-unseal-key-2.age
agenix-rekey edit .secrets/services/vault/dev/vault-unseal-key-3.age
```

Store the root token securely (outside of git) for initial configuration.

## Step 5: Deploy Configuration

Deploy the vault configuration to your hosts:

```bash
# Deploy to all vault hosts
colmena apply --on @vault

# Or deploy to specific environment
colmena apply --on @vault --on @dev
```

## Step 6: Join Raft Cluster

After deployment, join additional nodes to the Raft cluster:

```bash
# On second and subsequent nodes
export VAULT_ADDR="https://[node-hostname]:8200"
export VAULT_SKIP_VERIFY=true

# Join the raft cluster
vault operator raft join "https://[first-node]:8200"
```

## Step 7: Verify Deployment

Check that the cluster is healthy:

```bash
# Check vault status on each node
vault status

# Check raft cluster peers
vault operator raft list-peers

# Verify auto-unseal is working
systemctl status vault-auto-unseal
journalctl -u vault-auto-unseal -f
```

## Configuration Details

### File Structure

```
.secrets/services/vault/
├── dev/
│   ├── vault-ca.age                    # CA certificate
│   ├── vault-ca-key.age               # CA private key
│   ├── vault-[hostname].age           # Node certificate
│   ├── vault-[hostname]-key.age       # Node private key
│   ├── vault-unseal-key-1.age         # Unseal key 1
│   ├── vault-unseal-key-2.age         # Unseal key 2
│   └── vault-unseal-key-3.age         # Unseal key 3
└── prod/
    └── ... (same structure)
```

### Auto-Unseal Service

The `vault-auto-unseal` systemd service automatically unseals vault when it starts:

- Waits for vault to be responsive
- Applies stored unseal keys sequentially
- Runs every time vault service starts/restarts
- Logs status to journald

### Network Configuration

Vault uses the following ports:

- **8200**: API/UI (HTTPS)
- **8201**: Cluster communication (HTTPS)

Firewall rules are automatically configured for vault hosts.

## Troubleshooting

### Vault Won't Unseal

1. Check unseal key files exist: `ls /run/agenix/vault-unseal-key-*`
1. Verify auto-unseal service: `systemctl status vault-auto-unseal`
1. Check logs: `journalctl -u vault-auto-unseal -f`

### Certificate Issues

1. Verify certificate paths in logs
1. Check certificate validity: `openssl x509 -in /path/to/cert -text -noout`
1. Ensure SANs include correct hostnames and IPs

### Raft Cluster Issues

1. Check network connectivity between nodes
1. Verify all nodes have same CA certificate
1. Check raft logs: `journalctl -u vault -f`

### Auto-Unseal Not Working

1. Check TLS skip verify is enabled in service
1. Verify unseal keys are valid
1. Ensure minimum threshold keys are available

## Security Notes

- Unseal keys are encrypted at rest using agenix
- Root token should be stored securely outside of git
- Each environment has its own CA for isolation
- TLS is required for all vault communication
- Regular rotation of certificates is recommended

## Adding New Environments

To add vault to a new environment:

1. Create hosts with `vault` role in the new environment
1. Run certificate generation script for the environment
1. Create secrets directory structure
1. Follow deployment steps above

The configuration automatically adapts to new environments based on host roles and environment settings.
