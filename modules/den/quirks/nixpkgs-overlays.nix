# nixpkgs overlays as a quirk: aspects contribute overlays under the generic
# `nixpkgs-overlays` key; the os and home-manager consumers in
# core/nix/nixpkgs.nix collect them per scope. The routing policy lives beside
# the declaration it serves rather than in defaults.
{ den, lib, ... }:
let
  inherit (den.lib.policy) pipe;
in
{
  den.quirks.nixpkgs-overlays.description = "nixpkgs overlays collected from aspects";

  # When a host shares its nixpkgs (home-manager.useGlobalPkgs), each user's
  # overlays project up to the host so the shared set includes them (the os
  # consumer lib.unique's the union). In the default per-home-pkgs mode this
  # policy is empty and each home collects its own overlays as usual.
  #
  # FOLLOW-UP: under useGlobalPkgs the home consumer in core/nix/nixpkgs.nix must
  # also be prevented from defining nixpkgs.* (home-manager asserts otherwise);
  # excluding the whole aspect cascades, so that gating is deferred.
  den.policies.project-user-overlays =
    { user, host, ... }:
    lib.optionals host.settings.core.users.home-manager.useGlobalPkgs [
      (pipe.from "nixpkgs-overlays" [ pipe.expose ])
    ];

  den.schema.user.includes = [ den.policies.project-user-overlays ];
}
