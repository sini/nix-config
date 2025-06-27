{
  flake.modules.nixos.nix = {
    nixpkgs.config.allowUnfree = true;
  };
}
