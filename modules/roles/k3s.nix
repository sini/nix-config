{
  flake.roles.k3s = {
    features = [
      "k3s"
      "cilium-bgp"
    ];
  };
}
