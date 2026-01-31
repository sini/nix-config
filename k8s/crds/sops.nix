{ inputs, system, ... }:
let
  inherit (inputs.nixidy.packages.${system}.generators) fromCRD;
  inherit (inputs.nixhelm.chartsDerivations.${system}.isindir)
    sops-secrets-operator
    ;
in
fromCRD {
  name = "sops";
  src = sops-secrets-operator;
  crds = [ "crds/isindir.github.com_sopssecrets.yaml" ];
}
