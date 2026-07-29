{
  den.aspects.applications.dev.editor.codium.vscode = {
    homeManager =
      {
        codium-settings,
        codium-extensions,
        lib,
        ...
      }:
      {
        programs.vscode = {
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
        ".config/VSCodium"
        ".config/Code"
        ".vscode"
        ".vscode-oss"
        ".vscode-shared"
      ];
    };
  };
}
