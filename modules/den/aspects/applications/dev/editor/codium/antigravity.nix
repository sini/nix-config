{ den, ... }:
{
  den.aspects.applications.dev.editor.codium.antigravity = {
    includes = [
      (den.batteries.unfree [ "antigravity" ])
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
          profiles.default = {
            userSettings = lib.mkMerge codium-settings;
            extensions = lib.unique (lib.flatten codium-extensions);
          };
        };
      };

    persistHome = {
      directories = [
        ".antigravity"
        ".config/Antigravity"
      ];
    };
  };
}
