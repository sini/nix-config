# Garage operator (rajsinghtech) — owns the GarageCluster StatefulSet/Services/
# garage.toml/PDB reconciliation and the six Garage* CRDs (GarageCluster,
# GarageNode, GarageBucket, GarageKey, GarageAdminToken, GarageReferenceGrant).
#
# CRDs are registered through the crds bridge (early sync-wave -1), and the
# controller chart's own CRD install is disabled so the bridge is the sole CRD
# owner — the cnpg precedent (cloudnative-pg.nix). The local chart is built in
# pkgs/charts (charts.rajsinghtech.garage-operator); the crds quirk has no
# `charts` arg, so it reaches the chart via inputs.self.chartsDerivations.
#
# Webhooks (admission + multi-version conversion) are ON, the chart default. The
# operator refuses to reconcile GarageNodes without them: managed PVCs need the
# admission webhook to protect their identity reservations, and PVC-backed storage
# rollout is gated on it too (docs/garage-operator-webhooks.md). With them off every
# GarageNode sat in ReconcileFailed from 2026-08-27, so no image, config or volume
# change could roll out. The CRD extraction renders at the release namespace, so its
# conversion clientConfig and cert-manager CA-injection annotation point at the
# webhook Service there. cert-manager issues the webhook certificate from the chart's
# own self-signed Issuer.
let
  namespace = "garage";
in
{
  den.aspects.kubernetes.services.storage.garage.garage-operator = {
    # CRD scope has no `charts` arg — reach the local chart via inputs/system
    # like longhorn/cnpg. No kindFilter: register all six Garage* CRDs. The
    # chart emits them from templates/crds.yaml (gated on crds.install, default
    # true) reading crd-bases/*.yaml; the bridge filters the rendered output to
    # the CRD objects. --namespace sets Release.Namespace, which the conversion
    # stanzas name as the webhook Service's namespace.
    crds =
      { inputs, system, ... }:
      {
        name = "garage-operator";
        chart = inputs.self.chartsDerivations.${system}.rajsinghtech.garage-operator;
        extraOpts = [
          "--namespace"
          namespace
        ];
      };

    k8s-manifests =
      { charts, ... }:
      {
        applications.garage-operator = {
          inherit namespace;

          # Operator + CRDs before any Garage* CR (the GarageCluster lives in the
          # `garage` app at the default wave 0).
          annotations."argocd.argoproj.io/sync-wave" = "-1";

          helm.releases.garage-operator = {
            chart = charts.rajsinghtech.garage-operator;
            values = {
              # CRDs are deployed via the bootstrap app (crds bridge), not the
              # operator chart, to keep them out of the helm release lifecycle.
              crds.install = false;

              # Single active reconciler. Leader election stays on (chart default)
              # so rolling updates hand off cleanly; >1 replica would only add
              # standbys, so 1 avoids needless duplicate pods racing the layout/
              # key admin APIs on lease churn.
              replicaCount = 1;
            };
          };
        };
      };
  };
}
