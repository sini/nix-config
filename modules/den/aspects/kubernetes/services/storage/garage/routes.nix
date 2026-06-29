# Public S3 exposure. Path-style on the shared *.json64.dev listener; vhost-style
# on the dedicated s3-json64-dev listener (T1 + the prod.nix resourceName entry).
# No OIDC SecurityPolicy — SigV4 key-auth is the gate.
#
# DNS (manual, doc-only): s3.json64.dev and *.s3.json64.dev must be created in
# Cloudflare as DNS-only (grey-cloud) records — proxied mode's 100 MB upload cap
# breaks S3 multipart. SP2.4's Cloudflare stack adopts these records later.
{
  den.aspects.kubernetes.services.storage.garage.routes = {
    k8s-manifests =
      { cluster, ... }:
      {
        applications.garage.resources.httpRoutes = {
          # Path-style: s3.json64.dev rides the existing *.json64.dev wildcard
          # listener (domainForResource "garage-s3" = json64-dev).
          garage-s3-path.spec = {
            hostnames = [ (cluster.domainFor "garage-s3") ];
            parentRefs = [
              {
                name = "default-gateway";
                namespace = "gateways";
                sectionName = "${cluster.domainForResource "garage-s3"}-https";
              }
            ];
            rules = [
              {
                backendRefs = [
                  {
                    name = "garage";
                    port = 3900;
                  }
                ];
              }
            ];
          };

          # Vhost-style: *.s3.json64.dev on the dedicated s3-json64-dev listener
          # (needs T1 + the prod.nix resourceName entry). s3Api.rootDomain =
          # ".s3.json64.dev" makes Garage match the bucket from the Host header.
          garage-s3-vhost.spec = {
            hostnames = [ "*.${cluster.domainFor "garage-s3"}" ];
            parentRefs = [
              {
                name = "default-gateway";
                namespace = "gateways";
                sectionName = "s3-json64-dev-https";
              }
            ];
            rules = [
              {
                backendRefs = [
                  {
                    name = "garage";
                    port = 3900;
                  }
                ];
              }
            ];
          };
        };
      };
  };
}
