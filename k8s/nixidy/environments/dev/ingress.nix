{
  # Ingress controller and networking applications
  applications.ingress = {
    namespace = "ingress";
    createNamespace = true;

    resources = {
      # NGINX Ingress Controller
      helms.ingress-nginx = {
        chart = {
          name = "ingress-nginx";
          repo = "https://kubernetes.github.io/ingress-nginx";
          version = "4.11.3";
        };
        values = {
          controller = {
            service = {
              type = "LoadBalancer";
              annotations = {
                "io.cilium/lb-ipam-ips" = "10.11.0.100"; # Use Cilium LoadBalancer IP pool
              };
            };
            ingressClassResource = {
              default = true;
            };
            metrics = {
              enabled = true;
              serviceMonitor = {
                enabled = true;
              };
            };
          };
        };
      };

      # Cert-manager for TLS certificates
      helms.cert-manager = {
        chart = {
          name = "cert-manager";
          repo = "https://charts.jetstack.io";
          version = "v1.16.1";
        };
        values = {
          crds = {
            enabled = true;
          };
          prometheus = {
            enabled = true;
            servicemonitor = {
              enabled = true;
            };
          };
        };
      };

      # ClusterIssuer for Let's Encrypt
      customResources.letsencrypt-prod = {
        apiVersion = "cert-manager.io/v1";
        kind = "ClusterIssuer";
        metadata = {
          name = "letsencrypt-prod";
        };
        spec = {
          acme = {
            server = "https://acme-v02.api.letsencrypt.org/directory";
            email = "admin@local"; # TODO: Replace with real email
            privateKeySecretRef = {
              name = "letsencrypt-prod";
            };
            solvers = [
              {
                http01 = {
                  ingress = {
                    class = "nginx";
                  };
                };
              }
            ];
          };
        };
      };
    };
  };
}
