{ moduleWithSystem, ... }:
{
  flake.features.claude.home = moduleWithSystem (
    { inputs' }:
    {
      home.packages = with inputs'.nix-ai-tools.packages; [
        claude-code
        crush
      ];
    }
  );
}
