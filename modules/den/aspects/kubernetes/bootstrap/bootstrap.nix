# Bootstrap Application — deploys CRDs and namespaces before other apps.
#
# Ported from main:modules/kubernetes/bootstrap/bootstrap.nix
{
  den.aspects.kubernetes.bootstrap = {
    k8s-manifests =
      {
        config,
        cluster,
        crdObjects,
        lib,
        ...
      }:
      let
        appNamespaces = lib.unique (map (app: app.namespace) (builtins.attrValues config.applications));

        globalObjects =
          builtins.attrValues config.applications
          |> lib.filter (app: app.name or "" != "bootstrap")
          |> map (app: app.objects)
          |> lib.flatten;

        resourceNamespaces =
          globalObjects
          |> map (object: (object.metadata or { }).namespace or null)
          |> lib.filter (elem: elem != null)
          |> lib.unique;

        namespaces = appNamespaces ++ resourceNamespaces |> lib.unique;

        serviceCrds = lib.flatten (builtins.attrValues crdObjects);
      in
      {
        applications.bootstrap = {
          namespace = "kube-system";

          syncPolicy = {
            autoSync = {
              enable = true;
              prune = true;
              selfHeal = true;
            };
            syncOptions = {
              serverSideApply = true;
              applyOutOfSyncOnly = true;
              createNamespace = false;
            };
          };

          compareOptions.serverSideDiff = true;

          annotations."argocd.argoproj.io/sync-wave" = "-3";
          objects = serviceCrds;
          resources.namespaces =
            namespaces
            |> lib.filter (name: name != "kube-system" && name != "default")
            |> map (namespace: {
              name = namespace;
              value.metadata.annotations."argocd.argoproj.io/sync-options" = "Prune=false";
            })
            |> builtins.listToAttrs;
        };
      };

    age-secrets =
      { cluster, ... }:
      {
        age.secrets.cluster-sops-age-key = {
          rekeyFile = cluster.secretPath + "/cluster-sops-age-key.age";
          generator.script = "age-identity";
        };
      };
  };
}
