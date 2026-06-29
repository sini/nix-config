{
  imageName = "registry.json64.dev/tdarr-node";
  imageTag = "av1";
  imageDigest = "sha256:9283db46056f42f7efca590cf91d9dc89fad1f73310c2fda37107822236f38b6";
  # Unused for this image: imageRefs (what the aspect consumes) reads only
  # imageName+imageDigest; the k3s node pulls it at runtime via registries.yaml.
  # Only `images`/`imagesDerivations` (dockerTools.pullImage) read imageHash, and
  # neither is built for a private-registry entry. Placeholder avoids an authed
  # prefetch. Rebuild flow: nix build .#tdarr-node-vaapi --option sandbox true →
  # nix copy to uplink → skopeo copy docker-archive:… docker://localhost:5000/… →
  # update imageDigest here.
  imageHash = "sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=";
  arch = "amd64";
  os = "linux";
  pinned = true;
}
