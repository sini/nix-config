{
  flake.roles.kubernetes = {
    features = [
      "kubernetes"
      "cilium-bgp"
    ];
  };
}
