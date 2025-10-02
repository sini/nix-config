{
  flake.role.kubernetes = {
    features = [
      "kubernetes"
      "cilium-bgp"
    ];
  };
}
