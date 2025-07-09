{ config, ... }:
{
  flake.modules.nixos.role_workstation.imports = with config.flake.modules.nixos; [
    home-dev
    vscode
  ];
}
