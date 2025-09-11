# Kubernetes Configuration

This directory contains the Kubernetes configuration for the homelab cluster using a GitOps architecture.

## Architecture Overview

### Bootstrap Layer (k3s native)

- **Cilium CNI**: Network plugin with BGP control plane and VXLAN tunneling
- **ArgoCD**: GitOps controller for managing application deployments
- Deployed via k3s `autoDeployCharts` and `manifests` options

### Application Layer (nixidy + ArgoCD)

- **nixidy**: Generates Kubernetes manifests from Nix expressions (integrated into main flake)
- **ArgoCD Applications**: Consume nixidy-generated manifests for GitOps workflow
- Applications: monitoring, ingress, storage, and custom workloads

## Directory Structure

```
k8s/
├── README.md                    # This file
├── nixidy/                      # nixidy configuration
│   ├── environments/prod/      # Production cluster configuration
│   │   ├── default.nix         # Environment configuration
│   │   ├── test.nix            # Simple test application
│   │   ├── monitoring.nix      # Prometheus, Grafana stack (disabled)
│   │   ├── ingress.nix         # NGINX ingress, cert-manager (disabled)
│   │   ├── storage.nix         # Longhorn distributed storage (disabled)
│   │   └── dashboards/         # Grafana dashboards
│   ├── argocd-apps/           # ArgoCD Application definitions
│   └── manifests/prod/        # Generated manifests (auto-rendered)
├── dev/                       # Legacy manual configs (reference)
│   └── cilium/                # Original Cilium configuration
└── helm/                      # Helm-related configurations
```

## Usage

### Prerequisites

1. **k3s Cluster**: Bootstrap layer must be deployed first via NixOS configuration
1. **Development Environment**: Use the main flake's development shell (nixidy CLI included)

```bash
# Enter development environment
nix develop

# Or with direnv
direnv allow

# Verify nixidy is available
nixidy --help
```

### Rendering Manifests

Generate Kubernetes manifests from nixidy configuration:

```bash
render-nixidy
```

This will:

1. Build the nixidy environment package from the main flake
1. Copy rendered manifests to `k8s/nixidy/manifests/prod/`
1. Display instructions for Git workflow

**Note**: The render command uses an inline expression to build nixidy environments from the main flake, ensuring consistency with the overall repository configuration.

### Deploying Changes

1. **Modify nixidy configuration** in `k8s/nixidy/environments/prod/`
1. **Render manifests**: `render-nixidy`
1. **Commit and push changes**:
   ```bash
   git add k8s/nixidy/
   git commit -m "Update cluster configuration"
   git push
   ```
1. **ArgoCD automatically syncs** the changes to the cluster

### Accessing Services

- **ArgoCD UI**: Access via port-forward or through ingress (once configured)
  ```bash
  kubectl port-forward -n argocd svc/argocd-server 8080:80
  ```
- **Grafana**: Available at `http://grafana.dev.local` (through ingress)
- **Longhorn UI**: Available at `http://longhorn.dev.local` (basic auth: admin/admin)

## Configuration Details

### Bootstrap Components

**Cilium Configuration** (`modules/services/k3s/k3s.nix`):

- VXLAN tunnel mode with BGP control plane
- Device management for `dummy0`, `enp2s0`, and network interfaces
- Integration with existing BGP fabric
- Hubble observability enabled

**ArgoCD Configuration**:

- Bootstrap application deployed via k3s manifests
- Configured to consume nixidy-generated manifests
- Automatic sync with prune and self-heal enabled

### Application Stack

**Monitoring** (`environments/prod/monitoring.nix`):

- Prometheus operator and stack
- Grafana with persistent storage
- Alertmanager for notifications
- Custom dashboards via ConfigMaps

**Ingress** (`environments/prod/ingress.nix`):

- NGINX ingress controller with Cilium LoadBalancer
- cert-manager for automatic TLS certificates
- Let's Encrypt ClusterIssuer configuration

**Storage** (`environments/prod/storage.nix`):

- Longhorn distributed storage system
- Default storage class with 2 replicas
- Web UI with basic authentication

## Development Workflow

### Adding New Applications

1. Create a new file in `environments/prod/` (e.g., `my-app.nix`)
1. Define the application using nixidy syntax:
   ```nix
   {
     applications.my-app = {
       namespace = "my-namespace";
       createNamespace = true;
       resources = {
         # Define Kubernetes resources here
       };
     };
   }
   ```
1. Import the file in `environments/prod/default.nix`
1. Render and deploy as described above

### Helm Charts

Use the `helm` resource type for Helm chart deployments:

```nix
# Note: Helm charts currently disabled in environment configs
# Working example structure:
resources = {
  helm.my-chart = {
    chart = {
      name = "chart-name";
      repo = "https://charts.example.com";
      version = "1.0.0";
    };
    values = {
      # Helm values here
    };
  };
};
```

### Standard Kubernetes Resources

Define standard Kubernetes resources by type:

```nix
resources = {
  configMaps.my-config.data = {
    "test.txt" = "Hello from nixidy!";
  };

  deployments.my-app.spec = {
    # Deployment specification
  };

  services.my-service.spec = {
    # Service specification
  };
};
```

**Note**: Custom Resource Definitions (CRDs) and custom resources require investigation of proper nixidy syntax.

## Troubleshooting

### ArgoCD Not Syncing

1. Check ArgoCD Application status:

   ```bash
   kubectl get applications -n argocd
   kubectl describe application dev-cluster -n argocd
   ```

1. Verify repository access and manifest path

### Manifest Rendering Issues

1. Check nixidy configuration syntax:

   ```bash
   # Check the main flake (nixidy is integrated)
   nix flake check
   ```

1. Test render command:

   ```bash
   render-nixidy
   ```

1. Build nixidy environment manually:

   ```bash
   nix build --impure --expr 'let flake = builtins.getFlake (toString ./.); pkgs = import flake.inputs.nixpkgs-unstable { system = "x86_64-linux"; }; nixidyEnvs = flake.inputs.nixidy.lib.mkEnvs { inherit pkgs; envs = { prod = { modules = [ ./k8s/nixidy/environments/prod ]; }; }; }; in nixidyEnvs.prod.environmentPackage'
   ```

### k3s Bootstrap Issues

1. Check k3s service status:

   ```bash
   systemctl status k3s
   journalctl -u k3s -f
   ```

1. Verify Helm chart downloads and installations

## Migration Notes

### nixidy Integration (Current)

nixidy has been integrated into the main flake for consistency:

- **nixidy CLI**: Available in development shell via main flake
- **Environment configuration**: Defined in `k8s/nixidy/environments/prod/`
- **Manifest rendering**: Uses main flake's nixidy integration
- **Target settings**: Configured per-environment in `default.nix`

### Previous Approach

This configuration replaces the previous `modules/services/k3s/bootstrap.nix` approach with:

- Native k3s `autoDeployCharts` for Helm deployments
- Native k3s `manifests` for raw YAML resources
- nixidy for application-layer GitOps workflow

### Legacy References

- `k8s/dev/`: Original manual configurations (deprecated, kept for reference)
- Complex applications (monitoring, ingress, storage) are currently disabled pending nixidy syntax investigation

The original manual configurations in `k8s/dev/` are preserved for reference but should be considered deprecated.
