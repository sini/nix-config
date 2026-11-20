# uplink's static sites in Garage website buckets (docs/static-sites-to-garage.md):
# den.json64.dev and gen-status.json64.dev, as subdomain site-domains records that
# storage/garage/sites.nix turns into buckets, keys and routes. Also the 301 from
# homepage.json64.dev (uplink's retired homepage) to the cluster's dash.
#
# gen-status is published by den-ag-design from its own hosts, with a key
# nix-config generates: the two age secrets below go into the cluster (the
# GarageKey imports them) and onto the publishing hosts
# (services/web/gen-status-publisher.nix), so both sides hold the same key.
#
# Each site's `live` setting moves its name here from uplink; before that its
# bucket can be filled while uplink still serves.
{ lib, ... }:
let
  publisherSecret = "site-gen-status-publisher-import";
  sitesOf =
    cluster:
    let
      s = cluster.settings.kubernetes.services.web.static-sites;
    in
    {
      den = {
        domain = cluster.domainFor "den-docs-mirror";
        live = s.den.live;
      };
      gen-status = {
        domain = cluster.domainFor "gen-status";
        live = s.gen-status.live;
      };
    };
in
{
  den.aspects.kubernetes.services.web.static-sites = {
    settings = {
      den.live = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Serve den.<domain> from its Garage bucket (uplink stops serving it).";
      };
      gen-status.live = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Serve gen-status.<domain> from its Garage bucket (uplink stops serving it).";
      };
      homepageRedirect = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "301 homepage.<domain> to dash.<domain> (set when uplink's homepage retires).";
      };
    };

    site-domains =
      { cluster, ... }:
      let
        sites = sitesOf cluster;
      in
      [
        {
          inherit (sites.den) domain live;
          apex = false;
        }
        {
          inherit (sites.gen-status) domain live;
          apex = false;
          publisher.secretName = publisherSecret;
          # As uplink's nginx: the data files revalidate after a minute.
          headers = [
            {
              prefix = "/data/";
              set."Cache-Control" = "public, max-age=60, must-revalidate";
            }
          ];
        }
      ];

    served-domains =
      { cluster, ... }:
      let
        s = cluster.settings.kubernetes.services.web.static-sites;
      in
      lib.optional (s.den.live || s.gen-status.live || s.homepageRedirect) (
        cluster.servedDomains {
          services =
            lib.optional s.den.live "den-docs-mirror"
            ++ lib.optional s.gen-status.live "gen-status"
            ++ lib.optional s.homepageRedirect "homepage";
        }
      );

    age-secrets =
      { environment, ... }:
      {
        age.secrets = {
          gen-status-publisher-key-id = {
            rekeyFile = environment.secretPath + "/gen-status-publisher/key-id.age";
            generator.script = "garage-key-id";
            sopsOutput = {
              file = "gen-status-publisher";
              key = "access-key-id";
            };
          };
          gen-status-publisher-secret-key = {
            rekeyFile = environment.secretPath + "/gen-status-publisher/secret-key.age";
            generator.script = "garage-secret-key";
            sopsOutput = {
              file = "gen-status-publisher";
              key = "secret-access-key";
            };
          };
        };
      };

    k8s-manifests =
      { config, cluster, ... }:
      let
        s = cluster.settings.kubernetes.services.web.static-sites;
        homepage = cluster.domainFor "homepage";
      in
      {
        # The publisher key the GarageKey imports (its default key names).
        applications.sites.resources = {
          secrets.${publisherSecret}.stringData = {
            access-key-id = config.age.secrets.gen-status-publisher-key-id.sopsRef;
            secret-access-key = config.age.secrets.gen-status-publisher-secret-key.sopsRef;
          };

          httpRoutes = lib.optionalAttrs s.homepageRedirect {
            homepage-to-dash.spec = {
              hostnames = [ homepage ];
              parentRefs = [
                {
                  name = "default-gateway";
                  namespace = "gateways";
                  sectionName = "${cluster.resourceForDomain homepage}-https";
                }
              ];
              rules = [
                {
                  name = "to-dash";
                  filters = [
                    {
                      type = "RequestRedirect";
                      requestRedirect = {
                        hostname = cluster.domainFor "dash";
                        scheme = "https";
                        statusCode = 301;
                      };
                    }
                  ];
                }
              ];
            };
          };
        };
      };
  };
}
