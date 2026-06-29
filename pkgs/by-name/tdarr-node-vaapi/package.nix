# Custom tdarr_node OCI image: stock haveagitgat/tdarr_node base + nixpkgs
# ffmpeg-full (av1_vaapi) + mesa, so the axon AMD Radeon 780M (VCN 4.0) APUs can
# hardware-encode AV1 via VAAPI.
#
# WHY: the stock tdarr_node image ships Ubuntu-jammy Mesa (~22.x), which predates
# VCN4 AV1 VAAPI encode support (needs Mesa >= 24.1). We layer nixpkgs mesa (26.x)
# + ffmpeg-full on top and point tdarr at it via the `ffmpegPath` env. The nixpkgs
# ffmpeg closure carries its own glibc, so there is no ABI clash with the Ubuntu base.
#
# Rebuild / ship flow:
#   1. nix build .#tdarr-node-vaapi        # produces a docker-archive tarball
#   2. push the loaded image to the cluster registry
#   3. pin the pushed digest in the tdarr media aspect (later task)
#
# GOTCHA: dockerTools.buildLayeredImage with `fromImage` merges ONLY `Env` from the
# base. It does NOT inherit Entrypoint/Cmd/WorkingDir/User. Those are restated below
# from `skopeo inspect --config docker://ghcr.io/haveagitgat/tdarr_node:latest`:
#   Entrypoint = ["/init"];  Cmd = null;  WorkingDir = "/";  User = null;
{
  dockerTools,
  ffmpeg-full,
  mesa,
}:
let
  # Base image resolved via `nix-prefetch-docker --image-name
  # ghcr.io/haveagitgat/tdarr_node --image-tag latest --arch amd64 --os linux`.
  # Pinned by digest for reproducibility (tag `latest` at resolution time).
  base = dockerTools.pullImage {
    imageName = "ghcr.io/haveagitgat/tdarr_node";
    imageDigest = "sha256:a0f47ec35dae7bfec7674a4d5749efe91c3a06ceb15ea038ff0dd83132f8568e";
    sha256 = "sha256-/9eIz08OuwdT5x2HTq8ZnjEDuQz10kbutBy8AofTonA=";
    finalImageName = "tdarr_node";
    finalImageTag = "base";
  };
in
dockerTools.buildLayeredImage {
  name = "tdarr-node-vaapi";
  tag = "av1";
  fromImage = base;
  contents = [
    ffmpeg-full
    mesa
  ];
  config = {
    # Merged with the base image Env; our entries take precedence for duplicate keys.
    Env = [
      "ffmpegPath=${ffmpeg-full}/bin/ffmpeg"
      "LIBVA_DRIVERS_PATH=${mesa}/lib/dri"
      "LIBVA_DRIVER_NAME=radeonsi"
    ];
    # NOT inherited from fromImage by buildLayeredImage — restate from the skopeo
    # inspect of the base (see header). The base is a linuxserver-style s6 image:
    # `/init` boots s6-overlay, which drops to PUID/PGID; there is no Cmd.
    Entrypoint = [ "/init" ];
    WorkingDir = "/";
    # Base Cmd and User are both null (root; s6 handles the privilege drop), so we
    # intentionally do not set Cmd/User here.
  };
}
