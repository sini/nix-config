{ den, lib, ... }:
let
  # System-level secrets class → age (secrets, rekey, etc.)
  secrets-class = den.lib.perHost (
    # deadnix: skip
    { class, aspect-chain }:
    den._.forward {
      each = lib.optional (class == "nixos") true;
      fromClass = _: "secrets";
      intoClass = _: "nixos";
      intoPath = _: [ "age" ];
      fromAspect = _: lib.head aspect-chain;
      guard = { options, ... }: _: lib.mkIf (options ? age && (options.age ? secrets));
    }
  );
in
{
  den.ctx.default.includes = [
    secrets-class
  ];
}
