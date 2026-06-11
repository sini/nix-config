# Container registry (docker distribution) on uplink.
#
# Serves custom image pushes from workstations and pulls from the k3s
# fleet. The registry listens on loopback; nginx fronts it on
# registry.json64.dev with HTTP basic auth (htpasswd) and an unbounded
# client_max_body_size for large layer uploads. TLS via the wildcard LE
# cert provisioned by the nginx/acme aspect.
#
# Emits the container-registries quirk (domain + username); the cleartext
# password is a shared-rekeyFile secret consumed by k3s nodes via their
# own age.secrets entry (see k3s.nix). The htpasswd hash on this host is
# derived from that same password via a generator dependency.
{
  den,
  ...
}:
{
  den.aspects.services.web.container-registry = {
    includes = [ den.aspects.services.networking.nginx ];

    nixos =
      {
        config,
        environment,
        ...
      }:
      let
        domain = environment.getDomainFor "registry";
      in
      {
        services.dockerRegistry = {
          enable = true;
          listenAddress = "127.0.0.1";
          port = 5000;
          enableDelete = true;
          enableGarbageCollect = true;
        };

        services.nginx.virtualHosts."${domain}" = {
          forceSSL = true;
          useACMEHost = environment.domain;
          locations."/" = {
            proxyPass = "http://127.0.0.1:5000";
            basicAuthFile = config.age.secrets.registry-htpasswd.path;
            extraConfig = ''
              client_max_body_size 0;
            '';
          };
        };
      };

    # Cleartext password (shared rekeyFile so k3s nodes decrypt the same
    # value for their registries.yaml login) + the htpasswd hash derived
    # from it for the nginx basic-auth file.
    age-secrets =
      {
        environment,
        config,
        ...
      }:
      {
        age.secrets = {
          registry-password = {
            rekeyFile = environment.secretPath + "/registry/registry-password.age";
            generator.script = "rfc3986-secret";
          };

          registry-htpasswd = {
            rekeyFile = environment.secretPath + "/registry/registry-htpasswd.age";
            generator.dependencies = [ config.age.secrets.registry-password ];
            generator.script = "htpasswd";
            settings.username = "builder";
            owner = config.services.nginx.user;
            group = config.services.nginx.group;
          };
        };
      };

    # Publish registry endpoint for k3s nodes to wire into registries.yaml.
    # Password is resolved on the consumer host via its own shared-rekeyFile
    # registry-password secret, never carried in the quirk.
    container-registries =
      { environment, ... }:
      {
        domain = environment.getDomainFor "registry";
        username = "builder";
      };

    persist = {
      directories = [
        {
          directory = "/var/lib/docker-registry";
          user = "docker-registry";
          group = "docker-registry";
          mode = "0750";
        }
      ];
    };
  };
}
