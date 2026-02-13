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
  # nix run nixpkgs#nix-prefetch-github -- cert-manager cert-manager --rev v1.19.3
  src = pkgs.fetchFromGitHub {
    owner = "cert-manager";
    repo = "cert-manager";
    rev = "v1.19.3";
    hash = "sha256-XsGNcIv23YLLC4tY6MttPRhQDhf7SeaOMub/ZY+p7t0=";
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
