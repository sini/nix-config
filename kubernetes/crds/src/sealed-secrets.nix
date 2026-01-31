{
  inputs,
  pkgs,
  system,
  ...
}:
let
  inherit (inputs.nixidy.packages.${system}.generators) fromCRD;
in
fromCRD {
  name = "sealed-secrets";

  # nix run nixpkgs#nix-prefetch-github -- bitnami-labs sealed-secrets --rev release/v0.34.0

  src = pkgs.fetchFromGitHub {
    owner = "bitnami-labs";
    repo = "sealed-secrets";
    rev = "release/v0.34.0";
    hash = "sha256-Yu0fjVgYiZ+MTF8aJXjoQ8VZuD0tr6znFgYkTqIaZDU=";
  };
  crds = [ "helm/sealed-secrets/crds/bitnami.com_sealedsecrets.yaml" ];
}
