{
  den,
  ...
}:
{
  den.aspects.apps.dev.editor.antigravity = {
    includes = [
      (den.batteries.unfree [ "antigravity" ])
    ];

    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          antigravity-fhs
        ];
      };
  };
}
