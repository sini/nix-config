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
      src = ../../../images;
      loader = _: p: loadImage (import p);
      transformer = inputs.haumea.lib.transformers.liftDefault;
    };
in
{
  flake = {
    imagesMetadata = inputs.haumea.lib.load {
      src = ../../../images;
      transformer = inputs.haumea.lib.transformers.liftDefault;
    };

    images = mkImages;

    imagesDerivations = lib.genAttrs config.systems (
      system: mkImages { pkgs = inputs.nixpkgs-unstable.legacyPackages.${system}; }
    );
  };

  perSystem =
    { config, ... }:
    {
      devshells.default.commands = [
        {
          package = config.packages.oci-image-updater;
          name = "oci-image-updater";
          help = "Update OCI container image versions and hashes";
        }
      ];
    };

}
