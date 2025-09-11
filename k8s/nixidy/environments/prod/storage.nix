{
  # Storage application with Longhorn
  applications.storage = {
    namespace = "longhorn-system";
    createNamespace = true;

    resources = {
      # Longhorn distributed storage
      helms.longhorn = {
        chart = {
          name = "longhorn";
          repo = "https://charts.longhorn.io";
          version = "1.7.2";
        };
        values = {
          persistence = {
            defaultClass = true;
            defaultClassReplicaCount = 2;
            reclaimPolicy = "Retain";
          };
          defaultSettings = {
            backupstorePollInterval = 300;
            createDefaultDiskLabeledNodes = true;
            defaultDataPath = "/var/lib/longhorn";
            replicaSoftAntiAffinity = false;
            storageOverProvisioningPercentage = 100;
            storageMinimalAvailablePercentage = 25;
            upgradeChecker = false;
          };
          ingress = {
            enabled = true;
            ingressClassName = "nginx";
            host = "longhorn.dev.local";
            annotations = {
              "nginx.ingress.kubernetes.io/auth-type" = "basic";
              "nginx.ingress.kubernetes.io/auth-secret" = "longhorn-auth";
              "nginx.ingress.kubernetes.io/auth-realm" = "Authentication Required";
            };
          };
        };
      };

      # Basic auth secret for Longhorn UI
      secrets.longhorn-auth = {
        type = "Opaque";
        data = {
          # admin:admin (base64 encoded htpasswd)
          auth = "YWRtaW46JGFwcjEkSDY1dnBoNGckbDNOenhtZXM1SzV1Wi9vLkxrVkNIMC4=";
        };
      };
    };
  };
}
