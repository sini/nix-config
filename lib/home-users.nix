{ lib, ... }:
let
  inherit (builtins) elem;
  inherit (lib.custom) listDirectories;

  # Example usage:
  # Suppose listDirectories "hosts" returns [ "sini" "sini@patch" "shuo" ]
  #
  # For:
  #   user = "sini", hostname = "uplink
  # The function returns "sini" (since "sini@uplink" is not present).
  #
  # For:
  #   user = "sini", hostname = "patch"
  # The function returns "sini@patch" (since it is present).
  userHostMatch =
    user: hostname:
    let
      homes = listDirectories "homes";
      specific = "${user}@${hostname}";
    in
    if elem specific homes then
      specific
    else if elem user homes then
      user
    else
      throw "No matching home entry found for " + user + " on " + hostname;

in
rec {
  inherit
    userHostMatch
    ;
}
