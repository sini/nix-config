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
  name = "cert-manager";
  src = pkgs.fetchFromGitHub {
    owner = "cert-manager";
    repo = "cert-manager";
    rev = "v1.19.1";
    hash = "sha256-OK6U9QIRYolLBjcNBhzFmZZqfBFoJzY8aUHew2F0MAQ=";
  };
  crds = [
    "deploy/crds/cert-manager.io_certificaterequests.yaml"
    "deploy/crds/cert-manager.io_certificates.yaml"
    "deploy/crds/cert-manager.io_clusterissuers.yaml"
    "deploy/crds/cert-manager.io_issuers.yaml"
    "deploy/crds/acme.cert-manager.io_challenges.yaml"
    "deploy/crds/acme.cert-manager.io_orders.yaml"
  ];
}
