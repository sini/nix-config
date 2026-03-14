{
  flake.features.nixpkgs.system = {
    nixpkgs.config.allowDeprecatedx86_64Darwin = true;
  };
}
