# Hindsight control plane — the Next.js UI over the dataplane API. Read/curate
# the bank in a browser rather than through the REST API.
#
# Version-pinned in lockstep with vectorize-io/hindsight-api: the CP talks to a
# specific dataplane API shape, so the two should move together deliberately.
{
  imageName = "ghcr.io/vectorize-io/hindsight-control-plane";
  imageTag = "0.9.2";
  imageDigest = "sha256:d9bf57083f7cb0a53ee5011bdfde6aae2490dbf5c360d2d1bff10473b45eb112";
  imageHash = "sha256-eVG46xqdzW/p6vYHOy1kj2ZxSaA0DmR7mj/JHGV3mKM=";
  arch = "amd64";
  os = "linux";
  pinned = true;
}
