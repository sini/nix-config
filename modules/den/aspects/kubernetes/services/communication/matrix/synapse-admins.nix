# synapse-admins — keeps Synapse's server-admin flag equal to kanidm's `admins`
# group. Synapse OIDC cannot map claims to admin (nor can MAS map upstream
# claims), so the flag is reconciled from the identities kanidm provisions,
# routed here as `idm-users` (kanidm.nix → cluster-collect-idm-users).
#
# Localpart = kanidm short name (synapse.nix maps preferred_username, and the
# kanidm client sets preferShortUsername). An account exists only after its first
# login, so a new admin is promoted on the first run after they log in.
#
# Fail-safe: with no admins derived the job does nothing, rather than demoting
# everyone.
{ lib, ... }:
let
  namespace = "matrix";
  name = "synapse-admins";
  adminGroup = "admins";
in
{
  den.aspects.kubernetes.services.communication.matrix.synapse-admins = {
    k8s-manifests =
      {
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
        # kanidm names are [a-z0-9_.-]; refuse anything else rather than quote it.
        safe = lib.all (a: builtins.match "@[a-z0-9_.=-]+:[a-z0-9.-]+" a != null) admins;
        sqlList = lib.concatMapStringsSep ", " (a: "'${a}'") admins;
        script = ''
          set -eu
          psql -v ON_ERROR_STOP=1 <<'SQL'
          UPDATE users SET admin = 1 WHERE name IN (${sqlList}) AND admin IS DISTINCT FROM 1;
          UPDATE users SET admin = 0 WHERE name NOT IN (${sqlList}) AND admin IS DISTINCT FROM 0;
          SELECT name FROM users WHERE admin = 1 ORDER BY name;
          SQL
        '';
      in
      assert lib.assertMsg safe "synapse-admins: unexpected characters in a derived admin id";
      {
        applications.${name} = {
          inherit namespace;

          resources = lib.optionalAttrs (admins != [ ]) {
            configMaps."${name}-script".data."reconcile.sh" = script;

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
                      runAsUser = 70; # the postgres image's postgres user
                      runAsGroup = 70;
                    };
                    containers = [
                      {
                        inherit name;
                        image = "${images."library/postgres".repository}@${images."library/postgres".digest}";
                        command = [
                          "sh"
                          "/script/reconcile.sh"
                        ];
                        env = [
                          {
                            name = "PGHOST";
                            value = "matrix-pg-rw.${namespace}.svc.cluster.local";
                          }
                          {
                            name = "PGDATABASE";
                            value = "synapse";
                          }
                          {
                            name = "PGSSLMODE";
                            value = "require";
                          }
                          {
                            name = "PGUSER";
                            valueFrom.secretKeyRef = {
                              name = "matrix-pg-synapse-password";
                              key = "username";
                            };
                          }
                          {
                            name = "PGPASSWORD";
                            valueFrom.secretKeyRef = {
                              name = "matrix-pg-synapse-password";
                              key = "password";
                            };
                          }
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
          };
        };
      };
  };
}
