# _media-app.nix — shared builder for media-stack apps.
#
# NOT a flake-parts module (underscore prefix; not auto-imported). Imported by
# the per-app aspect files (prowlarr.nix, flaresolverr.nix, …) which call
# `mkMediaApp` and assign the result to their aspect:
#
#   den.aspects.kubernetes.services.media.<name> = mkMediaApp { … };
#
# mkMediaApp returns an *aspect section set* — `{ k8s-manifests; age-secrets;
# service-domains; }` — exactly the shape longhorn.nix / hubble-ui.nix declare
# inline. The caller passes `environments` (config.den.environments) in because
# this file has no flake-parts `config` of its own.
#
# Each app produces, in namespace `media`:
#   - applications.<name> with a bjw-s app-template (v5) helm release
#     (controller `main`, container `main`), config PVC, data/scratch mounts,
#     a Service, and baseline CiliumNetworkPolicies (gateway ingress, DNS
#     egress, optional postgres / internet egress);
#   - an HTTPRoute on the cluster default-gateway (route = true);
#   - a Kanidm OIDC SecurityPolicy + client-secret Secret (oidc = true), with a
#     matching age-secrets entry so `agenix generate` produces the .age file.
#
# app-template schema notes (common 5.0.1):
#   controllers.<c>.containers.<n>.{image.{repository,tag},env (map form),
#     envFrom, ports, probes}
#   env map form supports `<NAME> = "v"` and `<NAME>.valueFrom.secretKeyRef`
#   service.<s>.{controller,ports.<p>.{port,targetPort}}
#   persistence.<p>.{type,size,accessMode,storageClass,existingClaim,
#     globalMounts=[{path,readOnly?}]}
{ lib }:
let
  inherit (lib)
    concatStringsSep
    splitString
    take
    optionalAttrs
    optionals
    ;

  # Convert domain to the gateway listener section name (last 2 parts,
  # hyphenated): prowlarr.json64.dev -> json64-dev. Matches longhorn/hubble-ui.
  domainToResourceName =
    domain:
    let
      parts = splitString "." domain;
      topDomain = lib.reverseList (take 2 (lib.reverseList parts));
    in
    concatStringsSep "-" topDomain;

  # Namespace the Envoy Gateway data-plane (proxy) pods run in — they originate
  # ingress to the app pods. (envoy-gateway.nix deploys the controller and the
  # managed Envoy deployments in envoy-gateway-system.)
  gatewayNamespace = "envoy-gateway-system";
in
{
  mkMediaApp =
    {
      name, # app + dns name; also helm release / controller / service name
      port, # container web port + service port
      image, # { repository; tag; }
      environments, # config.den.environments (passed by the calling aspect)
      env ? { }, # extra container env (map form: name -> value | { valueFrom… })
      envFromSecrets ? [ ], # k8s Secret names to envFrom
      postgres ? false, # wire <NAME>__POSTGRES__* env + main/log db names
      postgresCnp ? postgres, # add the media-pg egress CiliumNetworkPolicy; defaults to `postgres`. Set true with postgres=false when the app talks to media-pg via a non-Servarr env style (e.g. bazarr's POSTGRES_* vars) so the egress policy is still emitted.
      config-size ? "2Gi", # longhorn config PVC size; null = no config PVC
      mounts ? { }, # { data?; scratch-nfs?; scratch-local?; } (bools)
      route ? true, # HTTPRoute on default-gateway
      oidc ? true, # SecurityPolicy + client secret (requires route)
      internetEgress ? false, # add world egress on 80/443 (flaresolverr et al)
      extraValues ? { }, # deep-merged into the helm release values; deep-merged, leaf collisions favor extraValues
    }:
    let
      dataMount = mounts.data or false;
      scratchNfs = mounts.scratch-nfs or false;
      scratchLocal = mounts.scratch-local or false;

      # ENV-prefix for the Servarr __POSTGRES__ convention (PROWLARR__POSTGRES__…)
      envPrefix = lib.toUpper name;
      pgSecret = "media-pg-${name}-password";

      oidcSecretName = "${name}-oidc-client-secret";
      sectionOf = domain: "${domainToResourceName domain}-https";

      _assertScratch = lib.assertMsg (
        !(scratchNfs && scratchLocal)
      ) "media-app ${name}: mounts.scratch-nfs and mounts.scratch-local are mutually exclusive";

      # ---- container env -----------------------------------------------------
      baseEnv = {
        TZ = "America/Los_Angeles";
        PUID = "1027";
        PGID = "65536";
      };

      postgresEnv = optionalAttrs postgres {
        "${envPrefix}__POSTGRES__HOST" = "media-pg-rw";
        "${envPrefix}__POSTGRES__PORT" = "5432";
        "${envPrefix}__POSTGRES__MAINDB" = "${name}-main";
        "${envPrefix}__POSTGRES__LOGDB" = "${name}-log";
        "${envPrefix}__POSTGRES__USER".valueFrom.secretKeyRef = {
          name = pgSecret;
          key = "username";
        };
        "${envPrefix}__POSTGRES__PASSWORD".valueFrom.secretKeyRef = {
          name = pgSecret;
          key = "password";
        };
      };

      containerEnv = baseEnv // postgresEnv // env;

      # ---- persistence -------------------------------------------------------
      persistence =
        optionalAttrs (config-size != null) {
          config = {
            type = "persistentVolumeClaim";
            accessMode = "ReadWriteOnce";
            size = config-size;
            storageClass = "longhorn";
            globalMounts = [ { path = "/config"; } ];
          };
        }
        // optionalAttrs dataMount {
          data = {
            type = "persistentVolumeClaim";
            existingClaim = "media-data-nfs";
            globalMounts = [ { path = "/data"; } ];
          };
        }
        // optionalAttrs scratchNfs {
          scratch = {
            type = "persistentVolumeClaim";
            existingClaim = "media-scratch-nfs";
            globalMounts = [ { path = "/scratch"; } ];
          };
        }
        // optionalAttrs scratchLocal {
          scratch = {
            type = "persistentVolumeClaim";
            existingClaim = "media-scratch-local";
            globalMounts = [ { path = "/scratch"; } ];
          };
        };

      # ---- helm values -------------------------------------------------------
      helmValues = {
        controllers.main = {
          type = "deployment";
          containers.main = {
            image = {
              inherit (image) repository tag;
            };
            env = containerEnv;
            envFrom = map (s: { secret = s; }) envFromSecrets;
          };
        };

        service.main = {
          controller = "main";
          ports.http = {
            inherit port;
          };
        };
      }
      // optionalAttrs (persistence != { }) { inherit persistence; };

      finalValues = lib.recursiveUpdate helmValues extraValues;

      # ---- baseline CiliumNetworkPolicies ------------------------------------
      podSelector.matchLabels."app.kubernetes.io/name" = name;

      # Route-less apps get no ingress policy here; ingress isolation lands with the policy-matrix aspect.
      gatewayIngressCnp = optionalAttrs route {
        "allow-gateway-ingress-${name}".spec = {
          description = "Allow Envoy Gateway proxies to reach ${name}.";
          endpointSelector = podSelector;
          ingress = [
            {
              fromEndpoints = [
                { matchLabels."k8s:io.kubernetes.pod.namespace" = gatewayNamespace; }
              ];
              toPorts = [
                { ports = [ { port = toString port; protocol = "TCP"; } ]; }
              ];
            }
          ];
        };
      };

      dnsEgressCnp = {
        "allow-dns-egress-${name}".spec = {
          description = "Allow ${name} to resolve via kube-dns.";
          endpointSelector = podSelector;
          egress = [
            {
              toEndpoints = [
                {
                  matchLabels = {
                    "k8s:io.kubernetes.pod.namespace" = "kube-system";
                    "k8s-app" = "kube-dns";
                  };
                }
              ];
              toPorts = [
                {
                  ports = [
                    { port = "53"; protocol = "UDP"; }
                    { port = "53"; protocol = "TCP"; }
                  ];
                }
              ];
            }
          ];
        };
      };

      postgresEgressCnp = optionalAttrs postgresCnp {
        "allow-postgres-egress-${name}".spec = {
          description = "Allow ${name} to reach the media-pg CNPG cluster.";
          endpointSelector = podSelector;
          egress = [
            {
              toEndpoints = [
                { matchLabels."cnpg.io/cluster" = "media-pg"; }
              ];
              toPorts = [
                { ports = [ { port = "5432"; protocol = "TCP"; } ]; }
              ];
            }
          ];
        };
      };

      internetEgressCnp = optionalAttrs internetEgress {
        "allow-internet-egress-${name}".spec = {
          description = "Allow ${name} to reach the public internet.";
          endpointSelector = podSelector;
          egress = [
            {
              toEntities = [ "world" ];
              toPorts = [
                {
                  ports = [
                    { port = "80"; protocol = "TCP"; }
                    { port = "443"; protocol = "TCP"; }
                  ];
                }
              ];
            }
          ];
        };
      };

      cnps = gatewayIngressCnp // dnsEgressCnp // postgresEgressCnp // internetEgressCnp;
    in
    assert _assertScratch;
    {
      # service-domains: declared only when this app is routed (drives DNS /
      # certificate listeners elsewhere). Empty list for route-less apps.
      service-domains = optionals route [ name ];

      # age-secrets: the OIDC client secret (shares its rekeyFile + generator
      # with the Kanidm OAuth2 client landed in a later task, so both resolve to
      # the same value). Only emitted when oidc is enabled.
      age-secrets =
        { cluster, ... }:
        let
          environment = environments.${cluster.environment};
        in
        optionalAttrs (oidc && route) {
          age.secrets.${oidcSecretName} = {
            rekeyFile = environment.secretPath + "/oidc/${oidcSecretName}.age";
            generator = {
              tags = [ "oidc" ];
              script = "rfc3986-secret";
            };
            sopsOutput = {
              file = "oidc";
              key = name;
            };
          };
        };

      k8s-manifests =
        {
          config,
          cluster,
          charts,
          ...
        }:
        let
          environment = environments.${cluster.environment};
          domain = environment.getDomainFor name;
        in
        {
          applications.${name} = {
            namespace = "media";

            helm.releases.${name} = {
              chart = charts.bjw-s-labs.app-template;
              values = finalValues;
            };

            resources =
              { ciliumNetworkPolicies = cnps; }
              // optionalAttrs route {
                httpRoutes.${name}.spec = {
                  hostnames = [ domain ];
                  parentRefs = [
                    {
                      name = "default-gateway";
                      namespace = "gateways";
                      sectionName = sectionOf domain;
                    }
                  ];
                  rules = [
                    {
                      backendRefs = [
                        {
                          inherit name;
                          inherit port;
                        }
                      ];
                    }
                  ];
                };
              }
              // optionalAttrs (oidc && route) {
                securityPolicies."${name}-oidc".spec = {
                  targetRefs = [
                    {
                      group = "gateway.networking.k8s.io";
                      kind = "HTTPRoute";
                      inherit name;
                    }
                  ];
                  oidc = {
                    provider.issuer = cluster.secrets.oidcIssuerFor name;
                    clientID = name;
                    clientSecret.name = oidcSecretName;
                    scopes = [
                      "email"
                      "openid"
                      "profile"
                    ];
                    forwardAccessToken = true;
                  };
                };

                secrets.${oidcSecretName} = {
                  type = "Opaque";
                  stringData.client-secret = config.age.secrets.${oidcSecretName}.sopsRef;
                };
              };
          };
        };
    };
}
