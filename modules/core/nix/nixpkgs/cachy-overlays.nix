{
  flake.features.nixpkgs.nixos =
    { inputs, ... }:
    {
      nixpkgs.overlays = [
        inputs.nix-cachyos-kernel.overlays.default
        inputs.proton-cachyos.overlays.default
      ];
    };
}
