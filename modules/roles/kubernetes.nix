{
  flake.role.kubernetes = {
    aspects = [
      "kubernetes"
      "cilium-bgp"
    ];
  };
}
