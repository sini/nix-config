{
  inputs,
  config,
  lib,
  ...
}:
let
  mkImages =
    { pkgs }:
    let
      # Load image metadata and convert to dockerTools.pullImage calls
      loadImage =
        attrs:
        pkgs.dockerTools.pullImage {
          inherit (attrs) imageName;
          inherit (attrs) imageDigest;
          sha256 = attrs.imageHash;
          finalImageName = attrs.imageName;
          finalImageTag = attrs.imageTag;
          # Note: dockerTools.pullImage doesn't directly support arch/os,
          # but these are captured in the digest which is platform-specific
        };
    in
    inputs.haumea.lib.load {
      src = ../../images;
      loader = _: p: loadImage (import p);
      transformer = inputs.haumea.lib.transformers.liftDefault;
    };
in
{
  flake = {
    imagesMetadata = inputs.haumea.lib.load {
      src = ../../images;
      transformer = inputs.haumea.lib.transformers.liftDefault;
    };

    images = mkImages;

    # Flattened "<ns>/<name>" -> { repository; digest; } accessor for use as a
    # nixidy module arg (`images`), so k8s-manifests aspects can reference a
    # pinned image by its registry+digest without restating the version.
    imageRefs = lib.genAttrs config.systems (
      _system:
      lib.foldlAttrs (
        acc: ns: names:
        acc
        // lib.mapAttrs' (
          name: meta:
          lib.nameValuePair "${ns}/${name}" {
            repository = meta.imageName;
            digest = meta.imageDigest;
          }
        ) names
      ) { } config.flake.imagesMetadata
    );

    imagesDerivations = lib.genAttrs config.systems (
      system: mkImages { pkgs = inputs.nixpkgs-unstable.legacyPackages.${system}; }
    );
  };

  perSystem = _: {
  };

}
