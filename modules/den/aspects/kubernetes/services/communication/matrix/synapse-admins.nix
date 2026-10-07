# synapse-admins — keeps Synapse's server-admin flag equal to kanidm's `admins`
# group. Synapse OIDC cannot map claims to admin (nor can MAS map upstream
# claims), so the flag is reconciled from the identities kanidm provisions,
# routed here as `idm-users` (kanidm.nix → cluster-collect-idm-users).
#
# The job goes through Synapse's admin API, never the database: Synapse caches
# is_server_admin, so a SQL write stays invisible until a restart.
#
# It acts as the non-human admin @synapse-admins, created on the first run with
# registration_shared_secret (admin: true) and thereafter logged in by a
# short-lived JWT signed with the jwt_config secret (synapse.nix); password login
# is disabled server-wide. It is never demoted, and logs its session out at exit.
#
# Localpart = kanidm short name (synapse.nix maps preferred_username, and the
# kanidm client sets preferShortUsername). An account exists only after its first
# login, so a new admin is skipped until then and promoted on the next run.
#
# Fail-safe: with no admins derived the job does nothing, rather than demoting
# everyone.
{ lib, ... }:
let
  namespace = "matrix";
  name = "synapse-admins";
  adminGroup = "admins";
  synapsePort = 8008;
  uid = 991; # the matrixdotorg/synapse image's synapse user

  tcp = p: {
    port = toString p;
    protocol = "TCP";
  };
in
{
  den.aspects.kubernetes.services.communication.matrix.synapse-admins = {
    k8s-manifests =
      {
        config,
        cluster,
        environment,
        idm-users,
        images,
        ...
      }:
      let
        serverName = environment.domain;
        admins = lib.sort lib.lessThan (
          map (u: "@${u.name}:${serverName}") (
            lib.filter (u: u.environment == cluster.environment && lib.elem adminGroup u.groups) idm-users
          )
        );
        secretEnv = envName: key: {
          name = envName;
          valueFrom.secretKeyRef = {
            inherit name key;
          };
        };
      in
      {
        applications.${name} = {
          inherit namespace;

          resources = lib.optionalAttrs (admins != [ ]) {
            configMaps."${name}-script".data."reconcile.py" = builtins.readFile ./synapse-admins.py;

            secrets.${name} = {
              type = "Opaque";
              stringData = {
                registration-shared-secret = config.age.secrets.matrix-synapse-registration-shared-secret.sopsRef;
                jwt-secret = config.age.secrets.matrix-synapse-jwt-secret.sopsRef;
              };
            };

            cronJobs.${name}.spec = {
              schedule = "*/10 * * * *";
              concurrencyPolicy = "Forbid";
              successfulJobsHistoryLimit = 1;
              failedJobsHistoryLimit = 3;
              jobTemplate.spec = {
                backoffLimit = 2;
                template = {
                  metadata.labels."app.kubernetes.io/name" = name;
                  spec = {
                    restartPolicy = "OnFailure";
                    securityContext = {
                      runAsNonRoot = true;
                      runAsUser = uid;
                      runAsGroup = uid;
                    };
                    containers = [
                      {
                        inherit name;
                        image = "${images."matrixdotorg/synapse".repository}@${images."matrixdotorg/synapse".digest}";
                        command = [
                          "python"
                          "/script/reconcile.py"
                        ];
                        env = [
                          {
                            name = "SYNAPSE_URL";
                            value = "http://synapse.${namespace}.svc.cluster.local:${toString synapsePort}";
                          }
                          {
                            name = "SERVER_NAME";
                            value = serverName;
                          }
                          {
                            name = "SERVICE_LOCALPART";
                            value = name;
                          }
                          {
                            name = "JWT_ISSUER";
                            value = name;
                          }
                          {
                            name = "ADMINS";
                            value = builtins.toJSON admins;
                          }
                          (secretEnv "REGISTRATION_SHARED_SECRET" "registration-shared-secret")
                          (secretEnv "JWT_SECRET" "jwt-secret")
                        ];
                        volumeMounts = [
                          {
                            name = "script";
                            mountPath = "/script";
                            readOnly = true;
                          }
                        ];
                      }
                    ];
                    volumes = [
                      {
                        name = "script";
                        configMap.name = "${name}-script";
                      }
                    ];
                  };
                };
              };
            };

            ciliumNetworkPolicies = {
              # Synapse's gateway policy puts it in ingress default-deny.
              allow-synapse-admins-ingress-synapse.spec = {
                description = "Allow the synapse-admins job to reach the Synapse admin API.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = "synapse";
                ingress = [
                  {
                    fromEndpoints = [ { matchLabels."app.kubernetes.io/name" = name; } ];
                    toPorts = [ { ports = [ (tcp synapsePort) ]; } ];
                  }
                ];
              };
              allow-synapse-admins-egress.spec = {
                description = "Allow the synapse-admins job DNS and Synapse, nothing else.";
                endpointSelector.matchLabels."app.kubernetes.io/name" = name;
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
                          {
                            port = "53";
                            protocol = "UDP";
                          }
                          (tcp 53)
                        ];
                      }
                    ];
                  }
                  {
                    toEndpoints = [ { matchLabels."app.kubernetes.io/name" = "synapse"; } ];
                    toPorts = [ { ports = [ (tcp synapsePort) ]; } ];
                  }
                ];
              };
            };
          };
        };
      };
  };
}
