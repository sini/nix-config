{
  den.aspects.apps.dev.lang.c = {
    codium-extensions =
      { pkgs, lib, ... }:
      let
        inherit (pkgs.stdenv) isLinux;
      in
      [
        pkgs.vscode-marketplace.ms-vscode.cmake-tools
        pkgs.vscode-marketplace.ms-vscode.hexeditor
        pkgs.vscode-marketplace.prince781.vala
        pkgs.vscode-marketplace.slevesque.shader
        pkgs.vscode-marketplace.twxs.cmake
      ]
      ++ lib.optionals isLinux [
        pkgs.vscode-extensions.ms-vscode.cpptools-extension-pack
        pkgs.vscode-extensions.vadimcn.vscode-lldb
      ];
  };
}
