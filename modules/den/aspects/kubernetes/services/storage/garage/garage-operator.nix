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
# Webhooks (admission + multi-version conversion) are DISABLED on both the CRD
# extraction and the release. The chart's conversion webhooks rewire each CRD's
# conversion.clientConfig at `$.Release.Namespace` and stamp a
# `cert-manager.io/inject-ca-from` annotation — but the crds bridge runs
# `helm template` with no `--namespace` (Release.Namespace = "default") and the
# bridge spec can't thread the real `garage` namespace, so an enabled extraction
# would bake a conversion config pointing at the wrong namespace + a cert-manager
# Certificate that lives elsewhere. Disabling webhooks makes the chart drop the
# conversion stanza and mark non-storage CRD versions served=false, yielding
# clean, namespace-independent CRDs with the storage version served. Keeping the
# release's webhooks off too avoids an orphaned webhook Service / cert-manager
# Certificate whose CA wouldn't line up with the conversion-stripped CRDs.
# (See render-time verify note: re-enabling conversion webhooks for HA across
# multiple Garage* API versions needs the bridge to template at the `garage`
# namespace — out of scope here.)
{
  den.aspects.kubernetes.services.storage.garage.garage-operator = {
    # CRD scope has no `charts` arg — reach the local chart via inputs/system
    # like longhorn/cnpg. No kindFilter: register all six Garage* CRDs. The
    # chart emits them from templates/crds.yaml (gated on crds.install, default
    # true) reading crd-bases/*.yaml, so `helm template` extracts them with no
    # extraOpts — the bridge filters the rendered output to the CRD objects.
    crds =
      { inputs, system, ... }:
      {
        name = "garage-operator";
        chart = inputs.self.chartsDerivations.${system}.rajsinghtech.garage-operator;
        # Conversion webhooks off (see header): self-contained CRDs, no
        # cert-manager / namespace coupling baked into the definitions.
        values.webhooks.enabled = false;
      };

    k8s-manifests =
      { charts, ... }:
      {
        applications.garage-operator = {
          namespace = "garage";

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

              # Webhooks off — consistent with the conversion-stripped CRDs above;
              # avoids a hard cert-manager dependency for the operator itself.
              webhooks.enabled = false;
            };
          };
        };
      };
  };
}
