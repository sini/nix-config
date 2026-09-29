# javascript/typescript: Node.js runtime and developer tooling.
{
  den.aspects.applications.dev.lang.javascript = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.nodejs_22
        ];
      };
  };
}
