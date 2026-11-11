# The resolver's admin panel (docs/dns-resolver.md §2.6): blocky-ui, a podman
# container on the host network bound to loopback, behind nginx and the shared
# oauth2-proxy (the homepage.nix pattern), gated to one Kanidm group. Blocky's
# API has no authentication, so the panel's server side is its only client here
# and no vhost location proxies to it.
{ den, self, ... }:
let
  serviceDomains = [ "dns" ];
  port = 3010;
  # The Kanidm group the panel admits; its token claim form is set below.
  group = "admins";
in
{
  den.aspects.services.networking.blocky-ui = {
    includes = [
      den.aspects.services.networking.nginx
      den.aspects.services.security.oauth2-proxy
      den.aspects.virtualization.podman
    ];

    nixos =
      {
        config,
        environment,
        host,
        pkgs,
        ...
      }:
      let
        domain = environment.getDomainFor "dns";
        image = self.imagesMetadata.gabeduartem.blocky-ui;
        blockyApi = "http://127.0.0.1:${
          toString (host.settings.services.networking.blocky.httpPort or 4000)
        }";
        uiConfig = (pkgs.formats.yaml { }).generate "blocky-ui.yml" {
          servers.${host.name} = {
            name = host.name;
            url = blockyApi;
          };
          instanceName = "${host.name} DNS";
        };
      in
      {
        virtualisation.oci-containers.containers.blocky-ui = {
          image = "${image.imageName}@${image.imageDigest}";
          # Host network: the container reaches Blocky on loopback and listens
          # only where HOSTNAME says, so no port is published.
          extraOptions = [
            "--network=host"
            "--security-opt=no-new-privileges"
          ];
          capabilities.ALL = false;
          environment = {
            BLOCKY_UI_CONFIG = "/config/blocky-ui.yml";
            HOSTNAME = "127.0.0.1";
            PORT = toString port;
          };
          volumes = [ "${uiConfig}:/config/blocky-ui.yml:ro" ];
        };

        services = {
          # kanidm's built-in groups claim lists each group's SPN (and uuid),
          # <name>@<kanidm domain> (kanidm 1.11.2 idm/oauth2.rs, the `groups` scope).
          oauth2-proxy.nginx.virtualHosts.${domain}.allowed_groups = [
            "${group}@${config.services.kanidm.server.settings.domain}"
          ];

          nginx.virtualHosts.${domain} = {
            forceSSL = true;
            useACMEHost = environment.domain;
            locations."/" = {
              proxyPass = "http://127.0.0.1:${toString port}";
              proxyWebsockets = true;
            };
          };
        };
      };

    served-domains = { environment, host, ... }: environment.servedDomains host serviceDomains;
  };
}
