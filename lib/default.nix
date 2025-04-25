# Notes:
# We borrow some general lib patterns from the following advanced configs:
# - https://github.com/JManch/nixos/blob/main/lib/default.nix
# - https://github.com/NotAShelf/nyx/blob/main/parts/lib/default.nix
lib: namespace:
let
  inherit (lib.attrsets) mergeAttrsList;

  libs = [
    (import ./attrs.nix { inherit lib; })
    (import ./modules.nix { inherit lib; })
    (import ./options.nix { inherit lib; })
    (import ./hosts.nix {
      inherit lib;
      inherit namespace;
    })
    (import ./home-users.nix {
      inherit lib;
      inherit namespace;
    })

  ];
in
rec {
  inherit namespace;
  ${namespace} = mergeAttrsList libs;
}
