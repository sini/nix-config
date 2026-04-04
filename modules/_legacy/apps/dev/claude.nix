{ moduleWithSystem, ... }:
{
  features.claude = {
    home = moduleWithSystem (
      { inputs' }:
      {
        home.packages = with inputs'.nix-ai-tools.packages; [
          claude-code
          crush
        ];
      }
    );

    provides.impermanence = {
      home = {
        home.persistence."/persist".directories = [
          ".claude/"
        ];
      };
    };
  };
}
