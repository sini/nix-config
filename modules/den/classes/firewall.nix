{ den, lib, ... }:
let
  # System-level firewall class → networking.firewall
  firewall-class = den.lib.perHost (
    # deadnix: skip
    { class, aspect-chain }:
    den._.forward {
      each = lib.optional (class == "nixos") true;
      fromClass = _: "firewall";
      intoClass = _: "nixos";
      intoPath = _: [
        "networking"
        "firewall"
      ];
      fromAspect = _: lib.head aspect-chain;
      guard = { options, ... }: _: lib.mkIf (options ? networking && (options.networking ? firewall));
    }
  );
in
{
  den.ctx.default.includes = [
    firewall-class
  ];
}
