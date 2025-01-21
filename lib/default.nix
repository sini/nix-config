lib: namespace:
let
  inherit (lib.attrsets) mergeAttrsList;

  libs = [
    (import ./attrs.nix { inherit lib; })
    (import ./modules.nix { inherit lib; })
    (import ./options.nix { inherit lib; })
  ];
in
{
  inherit namespace;
  ${namespace} = mergeAttrsList libs;
}
