{ lib, ... }:
{
  flake.lib.kubernetes-utils = {

    # Extract CRDs from a Helm chart
    # This is a general utility function for working with Helm charts and CRDs
    # All environment-specific functions have been moved to environment-options.nix
    extractCRDsFromChart =
      {
        name,
        klib,
        chartAttrs ? { },
        chart ? null,
        values ? { },
        crds ? [ ],
        extraOpts ? [ ],
      }:
      let
        _chart = if chart != null then chart else klib.downloadHelmChart chartAttrs;

        objects = klib.fromHelm {
          inherit name values extraOpts;
          includeCRDs = true;
          chart = _chart;
        };

        isWanted =
          obj:
          obj ? kind
          && obj.kind == "CustomResourceDefinition"
          && (crds == [ ] || (lib.any (x: obj.spec.names.kind == x) crds));

        resourceObjects = lib.filter isWanted objects;
      in
      resourceObjects;
  };
}
