{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
  options.text = mkOption {
    default = { };
    type = types.lazyAttrsOf (
      types.oneOf [
        (types.separatedString "")
        (types.submodule {
          options = {
            parts = mkOption {
              type = types.lazyAttrsOf types.str;
            };
            order = mkOption {
              type = types.listOf types.str;
            };
          };
        })
      ]
    );
    apply = lib.mapAttrs (
      _name: text:
      if lib.isAttrs text then
        lib.pipe text.order [
          (map (lib.flip lib.getAttr text.parts))
          lib.concatStrings
        ]
      else
        text
    );
  };
}
