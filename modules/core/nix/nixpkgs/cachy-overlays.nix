{
  flake.features.nixpkgs.nixos =
    { inputs, ... }:
    {
      nixpkgs.overlays = [
        inputs.nix-cachyos-kernel.overlays.pinned
        inputs.proton-cachyos.overlays.default
      ];
    };
}
