{
  den,
  lib,
  inputs,
  ...
}:
let
  # Channel → home-manager module mapping
  hmModules = {
    nixos-unstable = inputs.home-manager-unstable.nixosModules.home-manager;
    nixpkgs-master = inputs.home-manager-master.nixosModules.home-manager;
    nixos-stable = inputs.home-manager.nixosModules.home-manager;
    nixpkgs-stable-darwin = inputs.home-manager-stable-darwin.nixosModules.home-manager;
  };

  hmDarwinModules = {
    nixos-unstable = inputs.home-manager-unstable.darwinModules.home-manager;
    nixpkgs-master = inputs.home-manager-master.darwinModules.home-manager;
    nixos-stable = inputs.home-manager.darwinModules.home-manager;
    nixpkgs-stable-darwin = inputs.home-manager-stable-darwin.darwinModules.home-manager;
  };

  # Import the HM module matching the host's channel
  hm-module = den.lib.perHost (
    { host }:
    let
      channel = host.channel or "nixos-unstable";
      mod = if host.class == "darwin" then hmDarwinModules.${channel} else hmModules.${channel};
    in
    {
      nixos.imports = [ mod ];
      darwin.imports = [ mod ];
    }
  );
in
{
  den = {
    ctx = {
      # Import HM module on ALL hosts, matching their channel
      host.includes = [ hm-module ];

      # HM config only for hosts/users that actually use HM
      hm-host.includes = [ den.aspects.home-manager._.nixConfig ];
      hm-user.includes = [ den.aspects.home-manager._.hmConfig ];
    };

    aspects.home-manager = {
      _ = {
        nixConfig = den.lib.perHost {
          nixos.home-manager = {
            useUserPackages = lib.mkDefault true;
            useGlobalPkgs = lib.mkDefault true;
            backupFileExtension = lib.mkDefault "hm-backup";
            overwriteBackup = lib.mkDefault true;
          };
        };

        hmConfig = {
          homeManager.home.stateVersion = lib.mkDefault "25.11";
        };
      };
    };
  };
}
