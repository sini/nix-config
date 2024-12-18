{ mkShell, pkgs, ... }:
mkShell {
  packages = with pkgs; [
    pkgs.pantheon.avrogen
    azure-cli
    bicep
    csharpier
    dotnetbuildhelpers
    dotnetPackages.Nuget
    fsautocomplete
    mono
    msbuild
    netcoredbg
    omnisharp-roslyn
    powershell
    roslyn
    roslyn-ls
    vimPlugins.neotest-dotnet
    vscode-extensions.ms-dotnettools.csharp
    pkgs.pantheon.upgrade-assistant
  ];

  shellHook = ''

    export NUGET_PLUGIN_PATHS=${pkgs.pantheon.artifacts-credprovider}/bin/netcore/CredentialProvider.Microsoft/CredentialProvider.Microsoft.dll

    echo 🔨 Dotnet DevShell


  '';
}
