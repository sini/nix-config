{
  features.nixpkgs.os =
    { inputs, ... }:
    {
      nixpkgs.overlays = [
        inputs.proton-cachyos.overlays.default
      ];
    };
}
