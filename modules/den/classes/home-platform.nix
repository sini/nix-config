{ den, lib, ... }:
let
  home-platforms-class =
    # deadnix: skip
    { class, aspect-chain }:
    den._.forward {
      each = [
        "Linux"
        "Darwin"
        "Aarch64"
        "64bit"
      ];
      fromClass = platform: "home${platform}";
      intoClass = _: "homeManager";
      intoPath = _: [ ];
      fromAspect = _: lib.head aspect-chain;
      guard = { pkgs, ... }: platform: lib.mkIf pkgs.stdenv."is${platform}";
      adaptArgs =
        { config, ... }:
        {
          osConfig = config;
        };
    };
in
{
  den.ctx.default.includes = [
    home-platforms-class
  ];
}
