# Static sites served from Garage website buckets.
#
# Each site-domains record gets a GarageBucket named after its domain
# (globalAlias = domain) with website mode on; Garage's web endpoint (:3902)
# picks the bucket from the Host header. A record is { domain; apex ? true;
# live ? true; publisher ? null; headers ? [ ]; }.
#
# - Apex sites (a domain's web.landing, modules/den/domains) route on the
#   domain's apex listener, and www.<domain> 301s to the apex. Their content
#   lives in nix-config/sites/<domain>/ and is published with the
#   `publish-sites` devshell command, using the shared `sites-publisher` key
#   (write on the apex buckets only; its Secret stays in the garage namespace).
# - Subdomain sites (apex = false, emitted by cluster aspects such as
#   web/static-sites.nix) route on their parent's wildcard listener and each
#   get a key of their own, write on that bucket only: minted by the operator,
#   or imported from the Secret `publisher.secretName` (keys nix-config
#   generates and shares with an off-cluster publisher).
# - `live = false` keeps the bucket and key but no route, for filling a bucket
#   before its name moves here. `headers` sets response headers by path
#   prefix ([ { prefix; set = { <name> = <value>; }; } ]).
#
# Responses are compressed at the gateway (gzip and brotli).
{ lib, ... }:
let
  namespace = "garage";

  # k8s object names cannot contain dots.
  slug = lib.replaceStrings [ "." ] [ "-" ];

  clusterRef.name = "garage";

  garageBackend = {
    name = "garage";
    port = 3902;
  };
in
{
  den.aspects.kubernetes.services.storage.garage.sites = {
    k8s-manifests =
      { cluster, site-domains, ... }:
      let
        sites = map (
          s:
          {
            apex = true;
            live = true;
            publisher = null;
            headers = [ ];
          }
          // s
        ) site-domains;
        apexSites = lib.filter (s: s.apex) sites;
        subSites = lib.filter (s: !s.apex) sites;
        liveSites = lib.filter (s: s.live) sites;
        bucketName = s: "site-${slug s.domain}";

        bucket = s: {
          apiVersion = "garage.rajsingh.info/v1beta1";
          kind = "GarageBucket";
          metadata = {
            name = bucketName s;
            inherit namespace;
          };
          spec = {
            inherit clusterRef;
            globalAlias = s.domain;
            website = {
              enabled = true;
              indexDocument = "index.html";
              errorDocument = "404.html";
            };
          };
        };

        writeOn = s: {
          bucketRef.name = bucketName s;
          read = true;
          write = true;
        };

        subPublisher = s: {
          apiVersion = "garage.rajsingh.info/v1beta1";
          kind = "GarageKey";
          metadata = {
            name = "${bucketName s}-publisher";
            inherit namespace;
          };
          spec = {
            inherit clusterRef;
            neverExpires = true;
            bucketPermissions = [ (writeOn s) ];
          }
          // (
            if s.publisher != null then
              { importKey.secretRef.name = s.publisher.secretName; }
            else
              { secretTemplate.name = "${bucketName s}-publisher-credentials"; }
          );
        };

        headerRules =
          s:
          map (h: {
            name = "headers-${slug (lib.replaceStrings [ "/" ] [ "-" ] (lib.removePrefix "/" h.prefix))}";
            matches = [
              {
                path = {
                  type = "PathPrefix";
                  value = h.prefix;
                };
              }
            ];
            filters = [
              {
                type = "ResponseHeaderModifier";
                responseHeaderModifier.set = lib.mapAttrsToList (name: value: { inherit name value; }) h.set;
              }
            ];
            backendRefs = [ garageBackend ];
          }) s.headers;

        siteRoute =
          s:
          let
            section = cluster.resourceForDomain s.domain;
          in
          lib.nameValuePair (bucketName s) {
            spec = {
              hostnames = [ s.domain ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = if s.apex then "${section}-apex-https" else "${section}-https";
                }
              ];
              rules = headerRules s ++ [
                {
                  name = "site";
                  backendRefs = [ garageBackend ];
                }
              ];
            };
          };

        wwwRoute =
          s:
          lib.nameValuePair "${bucketName s}-www" {
            spec = {
              hostnames = [ "www.${s.domain}" ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.resourceForDomain s.domain}-https";
                }
              ];
              rules = [
                {
                  name = "to-apex";
                  filters = [
                    {
                      type = "RequestRedirect";
                      requestRedirect = {
                        hostname = s.domain;
                        scheme = "https";
                        statusCode = 301;
                      };
                    }
                  ];
                }
              ];
            };
          };
      in
      {
        applications.sites = {
          inherit namespace;

          objects =
            map bucket sites
            ++ lib.optional (apexSites != [ ]) {
              apiVersion = "garage.rajsingh.info/v1beta1";
              kind = "GarageKey";
              metadata = {
                name = "sites-publisher";
                inherit namespace;
              };
              spec = {
                inherit clusterRef;
                neverExpires = true;
                bucketPermissions = map writeOn apexSites;
                secretTemplate.name = "sites-publisher-credentials";
              };
            }
            ++ map subPublisher subSites;

          resources = {
            httpRoutes = lib.listToAttrs (
              map siteRoute liveSites ++ map wwwRoute (lib.filter (s: s.apex) liveSites)
            );

            backendTrafficPolicies = lib.optionalAttrs (liveSites != [ ]) {
              sites-compression.spec = {
                targetRefs = map (s: {
                  group = "gateway.networking.k8s.io";
                  kind = "HTTPRoute";
                  name = bucketName s;
                }) liveSites;
                compressor = [
                  { type = "Brotli"; }
                  { type = "Gzip"; }
                ];
              };
            };
          };
        };
      };
  };
}
