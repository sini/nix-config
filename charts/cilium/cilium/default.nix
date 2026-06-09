# Source of truth for the cilium version across the repo:
#   - chartHash: the helm chart tarball (this release)
#   - srcHash:   the cilium GitHub source at v${version}, reused by the CRD
#                aspect (modules/.../cilium/cilium.nix) and the cni binary
#                (pkgs/by-name/cni-plugin-cilium), so all three stay in lockstep.
#
# `nix run nixhelm#helmupdater -- update-all` bumps version + chartHash, but it
# does NOT know about srcHash — when version changes, update srcHash too (the
# build fails loudly with the expected hash if it is stale).
{
  repo = "https://helm.cilium.io/";
  chart = "cilium";
  version = "1.20.0-pre.3";
  chartHash = "sha256-ygsg9YD/anjYpd+KFIW5qeJuZucdhAaDz6kj39AY4Eo=";
  srcHash = "sha256-btHPdHHSFtKkfXrd9vVKlrOjWiCUM0dw9a5RbfJlyPg=";
}
