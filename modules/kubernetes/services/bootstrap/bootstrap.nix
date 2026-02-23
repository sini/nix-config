# Bootstrap Application
#
# This module creates a special "bootstrap" ArgoCD application that deploys
# cluster prerequisites before other applications. It runs first (sync-wave -3)
# to ensure CRDs and namespaces exist before dependent applications deploy.
#
# Components deployed:
# - CustomResourceDefinitions (CRDs) from all public applications
# - Namespaces required by applications and their resources
# - CRDs extracted from application objects
{
  flake.kubernetes.services.bootstrap = {

    nixidy =
      {
        config,
        crdFiles,
        lib,
        ...
      }:
      let
        # Collect all unique namespaces declared by applications
        appNamespaces = lib.unique (map (app: app.namespace) (builtins.attrValues config.applications));

        # Get all public apps except bootstrap itself to avoid circular dependency
        publicApps = lib.filter (app: app != "bootstrap") config.nixidy.publicApps;

        # Gather all Kubernetes objects from applications (excluding bootstrap)
        globalObjects =
          builtins.attrValues config.applications
          |> lib.filter (app: app.name or "" != "bootstrap")
          |> map (app: app.objects)
          |> lib.flatten;

        # Extract namespaces referenced in resource metadata
        resourceNamespaces =
          globalObjects
          |> map (object: (object.metadata or { }).namespace or null)
          |> lib.filter (elem: elem != null)
          |> lib.unique;

        # Combine all namespace sources into a single unique list
        namespaces = appNamespaces ++ resourceNamespaces |> lib.unique;

        # Find all CRD objects that need to be deployed
        objectCrds = globalObjects |> lib.filter (object: object.kind == "CustomResourceDefinition");
      in
      {
        applications.bootstrap = {
          namespace = "kube-system";
          # Deploy early (wave -3) so CRDs and namespaces exist before other apps
          annotations."argocd.argoproj.io/sync-wave" = "-3";
          # Load CRD YAML files from each public application
          yamls = publicApps |> map (app: crdFiles.${app} or [ ]) |> lib.flatten |> map builtins.readFile;
          # Include CRD objects found in application definitions
          objects = objectCrds;
          # Create all required namespaces (except system ones)
          # Set Prune=false to prevent accidental namespace deletion
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
  };
}
