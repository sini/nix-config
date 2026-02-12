{
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  inherit (lib)
    elem
    head
    filter
    tail
    ;

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
      # Collect initial exclusions from root features
      initialExclusions = lib.unique (lib.flatten (lib.catAttrs "excludes" roots));
      op =
        visited: toVisit: exclusions:
        if toVisit == [ ] then
          visited
        else
          let
            cur = head toVisit;
            rest = tail toVisit;
          in
          # Skip if current feature is excluded
          if elem cur.name exclusions then
            op visited rest exclusions
          else if elem cur.name (map (v: v.name) visited) then
            op visited rest exclusions
          else
            let
              # Add current feature's exclusions to the accumulated set
              newExclusions = lib.unique (exclusions ++ (cur.excludes or [ ]));
              # Filter out excluded features from requires
              deps = map (name: features.${name}) (
                filter (name: !(elem name newExclusions)) (cur.requires or [ ])
              );
            in
            op (op visited deps newExclusions ++ [ cur ]) rest newExclusions;

      # Get initial result (may include features that are later excluded)
      resultWithRoots = op [ ] roots initialExclusions;

      # Collect ALL exclusions from the entire dependency tree (roots + dependencies)
      allExclusions = lib.unique (lib.flatten (lib.catAttrs "excludes" (roots ++ resultWithRoots)));

      # Filter out features that are excluded anywhere in the tree, and remove roots
      finalResult = filter (v: !(elem v.name allExclusions) && !(elem v.name rootNames)) resultWithRoots;
    in
    finalResult;

  mkDeferredModuleOpt =
    description:
    mkOption {
      inherit description;
      type = types.deferredModule;
      default = { };
    };

  featureSubmoduleGenericOptions = {
    requires = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of names of features required by this feature";
    };
    excludes = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "List of names of features to exclude from this feature (prevents the feature and its requires from being added)";
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

  mkUsersWithFeaturesOpt =
    description:
    mkOption {
      type = types.lazyAttrsOf (
        types.submodule {
          options = {
            features = mkOption {
              type = types.listOf types.str;
              default = [ ];
              description = ''
                List of features specific to the user.

                While a feature may specify NixOS modules in addition to home
                modules, only home modules will affect configuration.  For this
                reason, users should be encouraged to avoid pointlessly specifying
                their own NixOS modules.
              '';
            };
            configuration = mkDeferredModuleOpt "User-specific home configuration";
          };
        }
      );
      default = { };
      inherit description;
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
      mkFeatureListOpt
      mkFeatureNameOpt
      mkDeferredModuleOpt
      mkUsersWithFeaturesOpt
      ;
  };
}
