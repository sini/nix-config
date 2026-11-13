# Garage operator: admission webhooks back on, then Garage v2.4.1

Status: **draft v0.2** (2026-11-13), for the owner's review. Nothing is built.

## 1. Problem (measured 2026-11-13)

The Garage operator (rajsinghtech/garage-operator v0.8.3, chart 0.8.3) cannot
reconcile the storage nodes. All three GarageNodes are `ReconcileFailed`:

> managed persistent volume claims require enabled admission webhooks to protect
> exact PVC identity reservations

The source is `internal/controller/garagenode_controller.go:1620`. The flag is
set in `cmd/main.go:353` as
`ManagedPVCAdmissionDisabled: len(webhookCertPath) == 0`, so it is on whenever
the operator runs without webhook certificates. The same gate blocks "PVC-backed
storage rollout and recovery" (`storage_rollout.go:181`). The chart's own values
say disabling webhooks is supported only for installs that do not use
"controller-managed persistent claims, or PVC-backed rollout/recovery". Ours
uses both.

So the operator can change nothing on the storage nodes: no image, config or
affinity change rolls out. It went unnoticed because the running pods keep
running.

**Second problem:** the GarageCluster has `spec.image: dxflrs/garage:v2.3.0`.
That value is not in our code; it was defaulted when the object was created. The
operator's `DiscoveryCompatible` condition says v2.3.0 "panics at start when
Consul or Kubernetes discovery is configured, so pods restarted with the
discovery configuration will crash-loop. Set spec.image to v2.4.1 or newer (or
disable spec.discovery) before the next restart". Our cluster enables Kubernetes
discovery. The pods did restart cleanly at axon-03's reboot (07:09 PST), so the
trigger is narrower than the message says. But a rollout of the current config
is exactly what it warns about. v0.8.3's default image is
`dxflrs/garage:v2.4.1@sha256:9c96caa2…`.

## 2. Why the webhooks are off

`garage-operator.nix`'s header: the CRD bridge ran `helm template` without
`--namespace`, so an enabled extraction would bake the conversion webhook's
`clientConfig` and its `cert-manager.io/inject-ca-from` annotation at namespace
`default`. The webhooks were turned off on both the CRD extraction and the
release to avoid that.

That limit may no longer hold. The bridge now takes `extraOpts`, passed to
`helm template` (envoy-gateway's and loki's quirks use it), so
`--namespace garage` can reach the extraction. cert-manager is installed (the
`certificates.cert-manager.io` CRD, ClusterIssuers `global-issuer`,
`json64-dev-issuer`, `xmsg-cluster-ca`); the chart creates its own self-signed
Issuer when `issuerName` is empty.

## 3. Proposal

1. **CRDs:** the bridge renders with `extraOpts = [ "--namespace" "garage" ]`
   and `webhooks.enabled = true`, so each conversion stanza points at
   `garage-operator-webhook.garage`, and the CA is injected by cert-manager.
2. **Release:** `webhooks.enabled = true` (chart default), cert-manager
   self-signed Issuer in `garage`, `failurePolicy: Fail` (chart default; the
   managed-PVC webhook is always Fail).
3. **Image, under the usual updater:** `oci-image-updater init` the Garage image
   into `images/dxflrs/garage/default.nix`, and set `spec.image` in
   `garage-cluster.nix` from it (the repo's image pattern), at v2.4.1 or newer
   by digest. Today `spec.image` is in no file: v2.3.0 was defaulted onto the
   live object at creation, so neither oci-image-updater nor Argo ever moves it.
   After this, Garage bumps arrive with the normal image updates. Done only
   after step 2 is live, as its own rollout: the operator then restarts the
   storage nodes one at a time (`StorageRolloutReady`, OnDelete StatefulSets).
4. **Then the spread:** the anti-affinity from
   `docs/longhorn-single-locality.md` §2.2 (reverted in 6b7e4d61) goes back in,
   rolled out by the same mechanism.

Each step is its own commit and Argo sync, with the GarageCluster conditions
read between them: `Ready`, `StorageRolloutReady`, `QuorumAtRisk=False`, every
GarageNode Ready.

## 4. Risks

- **A failing webhook blocks Garage CR edits.** With `failurePolicy: Fail`, if
  the webhook Service or its certificate is broken, every Garage* write is
  refused until it is fixed. Existing pods keep serving.
- **Conversion webhook on the CRDs:** a broken conversion webhook makes reads of
  the non-storage version fail. Everything we write is v1beta2 (the storage
  version), so reads of what we use stay up.
- **The image rollout** restarts Garage's three storage pods. One at a time
  keeps quorum (RF=3, `minNodesHealthy = 2`).

## 5. Validation

- Render: the extracted CRDs carry
  `conversion.webhook.clientConfig.service.namespace: garage` and the
  CA-injection annotation for a Certificate in `garage`.
- Live after step 2: GarageNodes leave `ReconcileFailed`; the GarageCluster
  reaches `Ready=True`; `StorageRolloutReady=True`.
- Live after step 3: three pods on v2.4.1, `DiscoveryCompatible=True`, the sites
  return 200, and S3 answers.

## 6. Open questions

1. Does the operator need the conversion webhook at all? Our objects are v1beta2
   only. The admission (PVC identity) webhooks are the ones its controller
   requires. If the chart can enable admission without conversion, that is the
   smaller change.
2. Upgrade to operator v0.9.0 (2026-11-05) in the same window? Its changes since
   v0.8.3 are E2E fixes, dependency bumps, Service `ipFamilyPolicy`, and an
   Auto-layout follower fix. Recommended: no, to keep one variable per step;
   later, on its own.
