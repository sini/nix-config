{ den, inputs, ... }:
{
  den.aspects.applications.dev.editor.codium.antigravity = {
    includes = [
      (den.batteries.unfree [ "antigravity-ide" ])
    ];

    homeManagerModules = [
      (
        { ... }:
        {
          disabledModules = [ "programs/antigravity.nix" ];

          imports = [
            (import (inputs.home-manager.outPath + "/modules/programs/vscode/mkVscodeModule.nix") {
              modulePath = [
                "programs"
                "antigravity"
              ];
              name = "Antigravity IDE";
              packageName = "antigravity-ide";
              nameShort = "Antigravity IDE";
              dataFolderName = ".antigravity-ide";
              skipVersionCheck = true;
            })
          ];
        }
      )
    ];

    homeManager =
      {
        codium-settings,
        codium-extensions,
        lib,
        ...
      }:
      {
        programs.antigravity = {
          enable = true;
          mutableExtensionsDir = false;
          profiles.default = {
            userSettings = lib.mkMerge codium-settings;
            extensions = lib.unique (lib.flatten codium-extensions);
          };
        };
      };

    persistHome = {
      directories = [
        ".antigravity-ide"
        ".config/Antigravity IDE"
      ];
    };
  };
}
