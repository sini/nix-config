{
  lib,
  self,
  inputs,
  config,
  withSystem,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (lib)
    elem
    head
    filter
    tail
    map
    ;

  flakeSpecialArgs = {
    inherit self inputs config;
  };

  flakeSpecialArgs' =
    system:
    withSystem system (
      ctx@{ inputs', ... }:
      let
        perSystem = {
          inherit (ctx.config) legacyPackages packages;
          inherit inputs';
        };
      in
      flakeSpecialArgs // { inherit perSystem; }
    );

  collectTypedModules =
    type: lib.foldr (v: acc: if v.${type} or null != null then acc ++ [ v.${type} ] else acc) [ ];
  collectNixosModules = collectTypedModules "nixos";
  collectHomeModules = collectTypedModules "home";
  collectNameMatches =
    own: others: own |> (map (v: others.${v.name} or null)) |> filter (v: v != null);
  collectRequires =
    features: roots:
    let
      rootNames = lib.catAttrs "name" roots;
      op =
        visited: toVisit:
        if toVisit == [ ] then
          visited
        else
          let
            cur = head toVisit;
            rest = tail toVisit;
          in
          if elem cur.name (map (v: v.name) visited) then
            op visited rest
          else
            let
              deps = map (name: features.${name}) (cur.requires or [ ]);
            in
            op (op visited deps ++ [ cur ]) rest;
    in
    (op [ ] roots) |> filter (v: !(lib.elem v.name rootNames));

  mkDeferredModuleOpt =
    description:
    mkOption {
      inherit description;
      type = types.deferredModule;
      default = { };
    };

  featureSubmoduleGenericOptions = {
    # TODO: accept actual feature shape
    requires = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of names of features required by this feature";
    };
    nixos = mkDeferredModuleOpt "A NixOS module for this feature";
    home = mkDeferredModuleOpt "A Home-Manager module for this feature";
  };

  mkFeatureNameOpt =
    name:
    mkOption {
      type = types.str;
      default = name;
      readOnly = true;
      internal = true;
    };

  mkFeatureListOpt =
    description:
    mkOption {
      type = types.listOf (
        types.submodule {
          options = featureSubmoduleGenericOptions // {
            # This differs from the `options.features.*.name` option
            # declaration in that it avoids setting a default value
            # inherited from the submodule's `name` argument.  We avoid
            # using `name` in this list context because `name` will not
            # reflect the original value as inherited from the attrset
            # where the feature was originally defined -- the latter
            # `name` is what we want, not the anonymous `name` from the
            # list context.
            #
            # How does this not result in an error, you ask?  Because,
            # given project conventions, we *always* create a feature
            # list from existing attributes where the desired name has
            # already been defined.  `name` is sneakily set to the
            # original value because of this.  If, for some reason, you
            # were to manually define a feature inside of an option
            # declared with this function (don't!), you would indeed run
            # into an error, and you would need to set `name` manually.
            #
            # We can thank Claude(!) for this clever trick.
            name = mkOption {
              type = types.str;
              readOnly = true;
              internal = true;
              description = "Name of the feature";
            };
          };
        }
      );
      default = [ ];
    };

in
{
  flake.lib.modules = {
    inherit
      featureSubmoduleGenericOptions
      collectHomeModules
      collectNameMatches
      collectNixosModules
      collectRequires
      collectTypedModules
      flakeSpecialArgs
      flakeSpecialArgs'
      mkFeatureListOpt
      mkFeatureNameOpt
      mkDeferredModuleOpt
      ;
  };
}
