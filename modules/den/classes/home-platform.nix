{ den, lib, ... }:
let
  # Forward homeLinux -> homeManager, only on nixos hosts
  homeLinux-class =
    { class, aspect-chain }:
    den._.forward {
      each = lib.optional (class == "nixos") true;
      fromClass = _: "homeLinux";
      intoClass = _: "homeManager";
      intoPath = _: [ ];
      fromAspect = _: lib.head aspect-chain;
    };

  # Forward homeDarwin -> homeManager, only on darwin hosts
  homeDarwin-class =
    { class, aspect-chain }:
    den._.forward {
      each = lib.optional (class == "darwin") true;
      fromClass = _: "homeDarwin";
      intoClass = _: "homeManager";
      intoPath = _: [ ];
      fromAspect = _: lib.head aspect-chain;
    };
in
{
  # Include in den.ctx.default so they apply everywhere (matching os-class pattern)
  den.ctx.default.includes = [
    homeLinux-class
    homeDarwin-class
  ];
}
