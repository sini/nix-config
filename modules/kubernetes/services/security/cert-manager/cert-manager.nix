# { lib, ... }:
# let
#   inherit (lib) mkOption types;
# in
{
  flake.kubernetes.services.cert-manager = {
    # options = {
    #   provider = mkOption {
    #     description = "Configuration for specific providers";
    #     type = types.attrTag {
    #       google = mkOption {
    #         description = "Google cert-manager configuration";
    #         type = types.submodule {
    #           options.project = mkOption {
    #             type = types.nullOr types.str;
    #             default = null;
    #             description = "Google project with DNS service enabled";
    #           };
    #           options.credentials = mkOption {
    #             type = types.nullOr types.str;
    #             default = null;
    #             description = "Contents of service account credentials (supports vals)";
    #           };
    #         };
    #       };
    #       cloudflare = mkOption {
    #         description = "Cloudflare cert-manager configuration";
    #         type = types.submodule {
    #           options.token = mkOption {
    #             type = types.nullOr types.str;
    #             default = null;
    #             description = "Secret personal API token (supports vals)";
    #           };
    #         };
    #       };
    #     };
    #   };
    # };

    nixidy =
      {
        config,
        environment,
        charts,
        lib,
        ...
      }:
      let
        namespaceList = lib.unique (map (app: app.namespace) (builtins.attrValues config.applications));
        certificatesResources = map (namespace: {
          name = "${namespace}-wildcard-certificate";
          value = {
            metadata = {
              name = "wildcard-certificate";
              namespace = namespace;
              annotations = {
                "cert-manager.io/issue-temporary-certificate" = "true";
              };
            };
            spec = {
              secretName = "wildcard-tls";
              issuerRef = {
                name = "cloudflare-issuer";
                kind = "ClusterIssuer";
              };
              dnsNames = [
                "${environment.domain}"
                "*.${environment.domain}"
              ];
            };
          };
        }) namespaceList;
      in
      {
        applications.cert-manager = {
          namespace = "cert-manager";
          createNamespace = true;

          helm.releases.cert-manager = {
            chart = charts.jetstack.cert-manager;
            includeCRDs = true;

            values = {
              crds.enabled = true;
              global.leaderElection.namespace = "cert-manager";
              extraArgs = [
                "--dns01-recursive-nameservers=1.1.1.1:53,8.8.8.8:53"
                "--dns01-recursive-nameservers-only"
              ];
              # dns01RecursiveNameservers = concatStringsSep "," [
              #   "https://1.1.1.1:443/dns-query"
              #   "https://1.0.0.1:443/dns-query"
              # ];
              # dns01RecursiveNameserversOnly = true;

              prometheus.enabled = false; # TODO: monitoring...
              prometheus.servicemonitor.enabled = false;
            };
          };

          resources = {
            clusterIssuers."cloudflare-issuer" = {
              metadata = {
                name = "cloudflare-issuer";
                namespace = "cert-manager";
              };
              spec = {
                acme = {
                  server = "https://acme-v02.api.letsencrypt.org/directory";
                  privateKeySecretRef = {
                    name = "cloudflare-issuer-account-key";
                  };
                  solvers = [
                    {
                      dns01 = {
                        cloudflare = {
                          apiTokenSecretRef = {
                            name = "cloudflare-api-token";
                            key = "cloudflare-api-token";
                          };
                        };
                      };
                    }
                  ];
                };
              };
            };

            certificates = builtins.listToAttrs certificatesResources;
          };
        };
      };

  };
}
