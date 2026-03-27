{
  features.nixpkgs.system =
    { inputs, ... }:
    {
      nixpkgs.overlays = [
        inputs.proton-cachyos.overlays.default
      ];
    };
}
