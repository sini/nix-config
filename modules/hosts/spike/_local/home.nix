{
  inputs,
  ...
}:
{
  config = {

    nixpkgs.overlays = [
      inputs.nix-vscode-extensions.overlays.default
    ];
  };
}
