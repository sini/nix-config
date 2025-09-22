{
  flake.role.kubernetes = {
    nixosModules = [
      "kubernetes"
      "cilium-bgp"
    ];

    homeModules = [ ];
  };
}
