{
  den.aspects.apps.dev.editor.vscode = {
    homeManager =
      {
        inputs',
        ...
      }:
      {
        nixpkgs.overlays = [
          inputs'.nix-vscode-extensions.overlays.default
        ];
      };
  };
}
