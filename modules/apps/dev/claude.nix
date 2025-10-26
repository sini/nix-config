{ moduleWithSystem, ... }:
{
  flake.features.claude.home = moduleWithSystem (
    { inputs' }:
    {
      home.packages = with inputs'.nix-ai-tools.packages; [
        claude-code
        crush
      ];
      home.persistence."/persist".directories = [
        ".claude/"
      ];
    }
  );
}
