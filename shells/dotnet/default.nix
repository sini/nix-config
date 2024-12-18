{ mkShell, pkgs, ... }:
mkShell {
  packages = with pkgs; [
    pkgs.logos.avrogen
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
    pkgs.logos.upgrade-assistant
  ];

  shellHook = ''

    export NUGET_PLUGIN_PATHS=${pkgs.logos.artifacts-credprovider}/bin/netcore/CredentialProvider.Microsoft/CredentialProvider.Microsoft.dll

    echo 🔨 Dotnet DevShell


  '';
}
