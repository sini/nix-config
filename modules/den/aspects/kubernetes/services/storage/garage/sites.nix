# Static sites served from Garage website buckets.
#
# Each web.landing domain (the site-domains quirk, modules/den/domains) gets a
# GarageBucket named after it (globalAlias = domain) with website mode on;
# Garage's web endpoint (:3902) picks the bucket from the Host header. The apex
# is routed to Garage on the domain's apex listener (web.landing includes
# web.apex); www.<domain> 301s to the apex at the gateway.
#
# Content lives in nix-config/sites/<domain>/ and is published with the
# `publish-sites` devshell command, using the `sites-publisher` key (write on
# the site buckets only; its credentials Secret stays in the garage namespace).
{ lib, ... }:
let
  namespace = "garage";

  # k8s object names cannot contain dots.
  slug = lib.replaceStrings [ "." ] [ "-" ];

  clusterRef.name = "garage";
in
{
  den.aspects.kubernetes.services.storage.garage.sites = {
    k8s-manifests =
      { cluster, site-domains, ... }:
      let
        domains = map (s: s.domain) site-domains;
      in
      {
        applications.sites = {
          inherit namespace;

          objects =
            map (domain: {
              apiVersion = "garage.rajsingh.info/v1beta1";
              kind = "GarageBucket";
              metadata = {
                name = "site-${slug domain}";
                inherit namespace;
              };
              spec = {
                inherit clusterRef;
                globalAlias = domain;
                website = {
                  enabled = true;
                  indexDocument = "index.html";
                  errorDocument = "404.html";
                };
              };
            }) domains
            ++ [
              {
                apiVersion = "garage.rajsingh.info/v1beta1";
                kind = "GarageKey";
                metadata = {
                  name = "sites-publisher";
                  inherit namespace;
                };
                spec = {
                  inherit clusterRef;
                  neverExpires = true;
                  bucketPermissions = map (domain: {
                    bucketRef.name = "site-${slug domain}";
                    read = true;
                    write = true;
                  }) domains;
                  secretTemplate.name = "sites-publisher-credentials";
                };
              }
            ];

          resources.httpRoutes = lib.listToAttrs (
            lib.concatMap (
              domain:
              let
                section = cluster.resourceForDomain domain;
              in
              [
                (lib.nameValuePair "site-${slug domain}" {
                  spec = {
                    hostnames = [ domain ];
                    parentRefs = [
                      {
                        name = "default-gateway";
                        namespace = "gateways";
                        sectionName = "${section}-apex-https";
                      }
                    ];
                    rules = [
                      {
                        name = "site";
                        backendRefs = [
                          {
                            name = "garage";
                            port = 3902;
                          }
                        ];
                      }
                    ];
                  };
                })
                (lib.nameValuePair "site-${slug domain}-www" {
                  spec = {
                    hostnames = [ "www.${domain}" ];
                    parentRefs = [
                      {
                        name = "default-gateway";
                        namespace = "gateways";
                        sectionName = "${section}-https";
                      }
                    ];
                    rules = [
                      {
                        name = "to-apex";
                        filters = [
                          {
                            type = "RequestRedirect";
                            requestRedirect = {
                              hostname = domain;
                              scheme = "https";
                              statusCode = 301;
                            };
                          }
                        ];
                      }
                    ];
                  };
                })
              ]
            ) domains
          );
        };
      };
  };
}
