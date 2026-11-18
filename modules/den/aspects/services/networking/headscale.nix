{ den, lib, ... }:
let
  serviceDomains = [ "headscale" ];
  # DERP's STUN listener and tailscaled's WireGuard port.
  udpPorts = [
    3478
    41641
  ];
  portList = lib.concatMapStringsSep "," toString udpPorts;
  hs = import ./_headscale-settings.nix { inherit lib; };
in
{
  den.aspects.services.networking.headscale = {
    includes = [ den.aspects.services.networking.nginx ];

    nixos =
      {
        config,
        dns-resolvers,
        exit-nodes,
        environment,
        host,
        pkgs,
        ...
      }:
      let
        domain = environment.getDomainFor "headscale";
        kanidmDomain = environment.getDomainFor "kanidm";
      in
      {
        services = {
          headscale = {
            enable = true;
            address = "0.0.0.0";
            port = 8085;

            settings = {
              metrics_listen_addr = "127.0.0.1:8090";
            }
            // hs.settings {
              inherit environment dns-resolvers;
              regionCode = config.networking.hostName;
              oidcSecretPath = config.age.secrets.headscale-oidc-secret.path;
              policyPath = pkgs.writeText "policy.json" (builtins.toJSON (hs.policy exit-nodes));
            };
          };

          nginx.virtualHosts."${domain}" = {
            forceSSL = true;
            useACMEHost = environment.domain;
            locations = {
              "/" = {
                proxyPass = "http://localhost:${toString config.services.headscale.port}";
                proxyWebsockets = true;
              };
              "/metrics" = {
                proxyPass = "http://${config.services.headscale.settings.metrics_listen_addr}/metrics";
              };
            };
          };
        };

        # only_start_if_oidc_is_available: when kanidm runs here and a switch
        # restarts both, start only once kanidm reports ready (Type=notify).
        systemd.services.headscale.after = lib.optional config.services.kanidm.server.enable "kanidm.service";

        environment.systemPackages = [
          config.services.headscale.package
        ];
      };

    age-secrets =
      { environment, host, ... }:
      {
        age.secrets.headscale-oidc-secret = {
          rekeyFile = environment.secretPath + "/oidc/headscale-oidc-client-secret.age";
          generator = {
            tags = [ "oidc" ];
            script = "rfc3986-secret";
          };
          mode = "440";
          owner = "headscale";
          group = "headscale";
        };
      };

    firewall = {
      networking.firewall.allowedUDPPorts = udpPorts;
    };

    port-forwards =
      { environment, host, ... }:
      {
        environment = environment.name;
        name = "headscale-to-${host.name}";
        protocol = "udp";
        wanPort = portList;
        forward = {
          ip = environment.addressOn "default" host;
          port = portList;
        };
        allWans = true;
      };

    served-domains = { environment, host, ... }: environment.servedDomains host serviceDomains;

    persist = {
      directories = [
        "/var/lib/headscale"
      ];
    };

    prometheus-targets =
      { environment, host, ... }:
      {
        hostname = host.name;
        ip = builtins.head host.ipv4;
        inherit environment;
        exporters = [
          {
            job = "headscale";
            port = 8090;
          }
        ];
      };
  };
}
