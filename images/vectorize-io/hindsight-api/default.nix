# Hindsight API — the dataplane image the upstream helm chart deploys (NOT the
# all-in-one `hindsight` image, which additionally bundles an embedded postgres
# and the Next.js control plane).
#
# Version-pinned rather than tracking a rolling tag: hindsight runs alembic
# migrations against the bank on startup, so an unattended digest bump would
# apply a schema migration nobody reviewed. Bump the tag deliberately and
# re-run `nix run nixpkgs#nix-prefetch-docker -- --image-name ... --json`.
{
  imageName = "ghcr.io/vectorize-io/hindsight-api";
  imageTag = "0.9.2";
  imageDigest = "sha256:7b14a1f4062252992d0176758753615e0a2071d9a269995be007be223ab01812";
  imageHash = "sha256-Y+QdUrynF5q8nVo9DbKL6W2H0ZSu78eRGzcicy9Piiw=";
  arch = "amd64";
  os = "linux";
  pinned = true;
}
