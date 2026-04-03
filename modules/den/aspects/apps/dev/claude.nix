{ den, moduleWithSystem, ... }:
{
  den.aspects.claude = {
    _ = {
      packages = den.lib.perUser {
        homeManager = moduleWithSystem (
          { inputs' }:
          {
            home.packages = with inputs'.nix-ai-tools.packages; [
              claude-code
              crush
            ];
          }
        );
      };

      persist = den.lib.perUser {
        persistHome.directories = [
          ".claude/"
        ];
      };
    };
  };
}
