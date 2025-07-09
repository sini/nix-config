{ inputs, ... }:
{
  flake.modules.nixos.deploy-rs = {
    imports = [
      inputs.deploy-rs.nixosModules.deploy-rs
    ];
  };
}
