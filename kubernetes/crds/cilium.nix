{
  inputs,
  pkgs,
  system,
  lib,
  ...
}:
let
  inherit (inputs.nixidy.packages.${system}.generators) fromCRD;
in
fromCRD {
  name = "cilium";
  # nix run nixpkgs#nix-prefetch-github -- cilium cilium --rev v1.18.6

  # NOTE: Remember to keep pkgs/by-name/cni-plugin-cilium in sync
  src = pkgs.fetchFromGitHub {
    owner = "cilium";
    repo = "cilium";
    rev = "v1.18.6";
    hash = "sha256-V4CbizefPn8VnZnnSxgQP2eq72wNVD0niuEmAlr28Xs=";
  };
  crds =
    (map (crd: "pkg/k8s/apis/cilium.io/client/crds/v2/${lib.toLower crd}.yaml") [
      "CiliumBGPPeerConfigs"
      "CiliumBGPClusterConfigs"
      "CiliumBGPAdvertisements"
      "CiliumBGPNodeConfigOverrides"
      "CiliumNetworkPolicies"
      "CiliumLoadBalancerIPPools"
      "CiliumClusterWideNetworkPolicies"
    ])
    ++ (map (crd: "pkg/k8s/apis/cilium.io/client/crds/v2alpha1/${lib.toLower crd}.yaml") [
      "CiliumL2AnnouncementPolicies"
    ]);
}
