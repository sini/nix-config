{
  den.aspects.apps.dev.mux.herdr = {
    homeManager =
      { inputs', pkgs, ... }:
      {
        home.packages = [ inputs'.nix-ai-tools.packages.herdr ];
      };
  };
}
