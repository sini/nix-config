# Kubernetes Configuration

This directory contains the Kubernetes configuration for the homelab cluster using a GitOps architecture.

## Architecture Overview

### Bootstrap Layer (k3s native)

- **Cilium CNI**: Network plugin with BGP control plane and VXLAN tunneling
- **ArgoCD**: GitOps controller for managing application deployments
- Deployed via k3s `autoDeployCharts` and `manifests` options

### Application Layer (nixidy + ArgoCD)

- **nixidy**: Generates Kubernetes manifests from Nix expressions
- **ArgoCD Applications**: Consume nixidy-generated manifests for GitOps workflow
- Applications: monitoring, ingress, storage, and custom workloads

## Directory Structure

```
k8s/
├── README.md                    # This file
├── nixidy/                      # nixidy configuration
│   ├── flake.nix               # Main nixidy flake
│   ├── environments/dev/       # Dev cluster configuration
│   │   ├── default.nix         # Environment configuration
│   │   ├── monitoring.nix      # Prometheus, Grafana stack
│   │   ├── ingress.nix         # NGINX ingress, cert-manager
│   │   ├── storage.nix         # Longhorn distributed storage
│   │   └── dashboards/         # Grafana dashboards
│   ├── argocd-apps/           # ArgoCD Application definitions
│   └── manifests/dev/         # Generated manifests (auto-rendered)
└── dev/                       # Legacy manual configs (reference)
    └── cilium/                # Original Cilium configuration
```

## Usage

### Prerequisites

1. **k3s Cluster**: Bootstrap layer must be deployed first via NixOS configuration
1. **Development Environment**: Use the main flake's development shell

```bash
# Enter development environment
nix develop

# Or with direnv
direnv allow
```

### Rendering Manifests

Generate Kubernetes manifests from nixidy configuration:

```bash
render-nixidy
```

This will:

1. Build the nixidy environment package
1. Copy rendered manifests to `k8s/nixidy/manifests/dev/`
1. Display instructions for Git workflow

### Deploying Changes

1. **Modify nixidy configuration** in `k8s/nixidy/environments/dev/`
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

**Monitoring** (`environments/dev/monitoring.nix`):

- Prometheus operator and stack
- Grafana with persistent storage
- Alertmanager for notifications
- Custom dashboards via ConfigMaps

**Ingress** (`environments/dev/ingress.nix`):

- NGINX ingress controller with Cilium LoadBalancer
- cert-manager for automatic TLS certificates
- Let's Encrypt ClusterIssuer configuration

**Storage** (`environments/dev/storage.nix`):

- Longhorn distributed storage system
- Default storage class with 2 replicas
- Web UI with basic authentication

## Development Workflow

### Adding New Applications

1. Create a new file in `environments/dev/` (e.g., `my-app.nix`)
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
1. Import the file in `environments/dev/default.nix`
1. Render and deploy as described above

### Helm Charts

Use the `helms` resource type for Helm chart deployments:

```nix
helms.my-chart = {
  chart = {
    name = "chart-name";
    repo = "https://charts.example.com";
    version = "1.0.0";
  };
  values = {
    # Helm values here
  };
};
```

### Custom Resources

Define raw Kubernetes resources using `customResources`:

```nix
customResources.my-resource = {
  apiVersion = "v1";
  kind = "ConfigMap";
  metadata = {
    name = "my-config";
  };
  data = {
    key = "value";
  };
};
```

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
   cd k8s/nixidy
   nix flake check
   ```

1. Build individual components:

   ```bash
   nix build .#dev.environmentPackage
   ```

### k3s Bootstrap Issues

1. Check k3s service status:

   ```bash
   systemctl status k3s
   journalctl -u k3s -f
   ```

1. Verify Helm chart downloads and installations

## Migration Notes

This configuration replaces the previous `modules/services/k3s/bootstrap.nix` approach with:

- Native k3s `autoDeployCharts` for Helm deployments
- Native k3s `manifests` for raw YAML resources
- nixidy for application-layer GitOps workflow

The original manual configurations in `k8s/dev/` are preserved for reference but should be considered deprecated.
