{ lib, ... }:
let
  inherit (lib) mkOption types;

  mkDeferredModuleOpt =
    description:
    mkOption {
      inherit description;
      type = types.deferredModule;
      default = { };
    };

  # Wraps a deferred module with metadata for better debugging
  wrapModuleWithMetadata =
    featureName: modulePath: module:
    if module == { } then
      module
    else
      {
        _file = "flake.nix#features.${featureName}.${modulePath}";
        imports = [ module ];
      };

  # Create a deferred module option with metadata wrapping
  mkDeferredModuleOptWithMetadata =
    featureName: modulePath: description:
    mkOption {
      inherit description;
      type = types.deferredModule;
      default = { };
      apply = wrapModuleWithMetadata featureName modulePath;
    };

  featureSubmodule =
    { name, ... }:
    {
      options = {
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

        # Cross-platform system module (included on both NixOS and Darwin)
        system =
          mkDeferredModuleOptWithMetadata name "system"
            "A cross-platform system module for this feature (NixOS and Darwin)";

        # Platform-specific system modules (for config that only applies to one platform)
        linux =
          mkDeferredModuleOptWithMetadata name "linux"
            "A Linux-specific system module for this feature (NixOS only)";
        darwin =
          mkDeferredModuleOptWithMetadata name "darwin"
            "A Darwin-specific system module for this feature (macOS only)";

        # Home-manager module (works on all platforms)
        home = mkDeferredModuleOptWithMetadata name "home" "A Home-Manager module for this feature";

        # Per-feature typed settings (option declarations only, not values)
        settings = mkOption {
          type = types.lazyAttrsOf types.raw;
          default = { };
          description = ''
            Option declarations for per-feature configuration.
            These options will be available at settings.<featureName> in feature modules.
            Should contain ONLY option declarations (mkOption), no config assignments.
          '';
        };

        name = mkOption {
          type = types.str;
          default = name;
          readOnly = true;
          internal = true;
        };
      };
    };

  # ============================================================================
  # Module Collection Utilities
  # ============================================================================
  # These functions extract typed modules (nixos/home) from feature definitions

  # Generic collector for modules of a specific type from feature list
  # Skips features where the type key is missing or set to the default empty module
  collectTypedModules =
    type: lib.foldr (v: acc: if v.${type} or null != null then acc ++ [ v.${type} ] else acc) [ ];

  # Cross-platform system modules
  collectSystemModules = collectTypedModules "system";

  # Platform-specific system modules
  collectLinuxModules = collectTypedModules "linux";
  collectDarwinModules = collectTypedModules "darwin";

  # Home-manager modules (all platforms)
  collectHomeModules = collectTypedModules "home";

  # Collect all applicable system modules for a given platform
  # Includes: cross-platform (system) + platform-specific (linux/darwin)
  collectPlatformSystemModules =
    features: system:
    let
      isDarwin = lib.hasSuffix "-darwin" system;
      isLinux = lib.hasSuffix "-linux" system;

      # Cross-platform modules (always included)
      sharedModules = collectSystemModules features;

      # Platform-specific modules
      platformModules =
        if isLinux then
          collectLinuxModules features
        else if isDarwin then
          collectDarwinModules features
        else
          throw "Unsupported system architecture: ${system}";
    in
    sharedModules ++ platformModules;

  # ============================================================================
  # Feature Resolution Functions
  # ============================================================================
  # These functions resolve feature dependencies and compute active features

  # Collect transitive dependencies for a set of root features
  # Returns only the dependencies (not the roots themselves)
  # Exclusions are propagated through the dependency tree
  collectRequires =
    features: roots:
    let
      inherit (lib)
        elem
        filter
        head
        tail
        ;

      rootNames = lib.catAttrs "name" roots;
      initialExclusions = lib.unique (lib.flatten (lib.catAttrs "excludes" roots));

      # Depth-first traversal of dependency tree
      traverseDependencies =
        visited: toVisit: exclusions:
        if toVisit == [ ] then
          visited
        else
          let
            current = head toVisit;
            remaining = tail toVisit;
            isExcluded = elem current.name exclusions;
            isVisited = elem current.name (map (v: v.name) visited);
          in
          if isExcluded || isVisited then
            traverseDependencies visited remaining exclusions
          else
            let
              updatedExclusions = lib.unique (exclusions ++ (current.excludes or [ ]));
              dependencyNames = filter (name: !(elem name updatedExclusions)) (current.requires or [ ]);
              dependencies = map (name: features.${name}) dependencyNames;
              visitedWithCurrent = visited ++ [ current ];
              visitedWithDeps = traverseDependencies visitedWithCurrent dependencies updatedExclusions;
            in
            traverseDependencies visitedWithDeps remaining updatedExclusions;

      resultWithRoots = traverseDependencies [ ] roots initialExclusions;
      allExclusions = lib.unique (lib.flatten (lib.catAttrs "excludes" (roots ++ resultWithRoots)));
      dependenciesOnly = filter (
        v: !(elem v.name allExclusions) && !(elem v.name rootNames)
      ) resultWithRoots;
    in
    dependenciesOnly;

  # Core features that are always enabled for every host
  # This includes the "default" composite feature which bundles essential system features
  coreFeatures = [
    "default"
  ];

  # Resolve complete feature set for a host (core + direct features + dependencies)
  # Returns feature modules with all dependencies resolved and exclusions applied
  # Takes: features config and host options
  getModulesForFeatures =
    {
      featuresConfig,
      hostFeatures ? [ ],
      hostExclusions ? [ ],
    }:
    let
      allFeatureNames = lib.unique (coreFeatures ++ hostFeatures);
      allFeatures = map (name: featuresConfig.${name}) allFeatureNames;
      featureExclusions = lib.flatten (lib.catAttrs "excludes" allFeatures);
      allExclusions = lib.unique (featureExclusions ++ hostExclusions);
      filteredFeatures = lib.filter (f: !(lib.elem f.name allExclusions)) allFeatures;
      featureDeps = collectRequires featuresConfig filteredFeatures;
      allFeaturesWithDeps = filteredFeatures ++ featureDeps;
    in
    allFeaturesWithDeps;

  # Compute active feature names for a host
  # This is a convenience wrapper around getModulesForFeatures
  # Returns: list of feature names (strings)
  computeActiveFeatures =
    {
      featuresConfig,
      hostFeatures ? [ ],
      hostExclusions ? [ ],
    }:
    let
      allHostFeatures = getModulesForFeatures {
        inherit
          featuresConfig
          hostFeatures
          hostExclusions
          ;
      };
    in
    lib.unique (map (f: f.name) allHostFeatures);

  # ============================================================================
  # Feature Settings
  # ============================================================================
  # Typed, per-feature settings with multi-layer merging via evalModules.
  # Analogous to serviceOptions in kubernetes/service-helpers.nix.

  # Generate a feature-settings option type from all features that declare settings.
  # Used by environments and hosts to provide typed configuration for features.
  mkFeatureSettingsOpt =
    featuresConfig: description:
    let
      featuresWithSettings = lib.filterAttrs (_: f: f.settings or { } != { }) featuresConfig;
    in
    mkOption {
      type = types.submodule {
        options = lib.mapAttrs (
          name: feature:
          mkOption {
            type = types.submodule { options = feature.settings; };
            default = { };
            description = "Settings for the ${name} feature";
          }
        ) featuresWithSettings;
      };
      default = { };
      inherit description;
    };

  # Resolve feature settings by merging layers via evalModules.
  # Priority order (lowest to highest):
  #   1. Feature defaults (from mkOption default values)
  #   2. Environment feature-settings (wrapped in mkDefault)
  #   3. Host feature-settings (plain values)
  #   4. User feature-settings (plain values, home modules only)
  resolveFeatureSettings =
    {
      activeFeatureNames,
      featuresConfig,
      envSettings ? { },
      hostSettings ? { },
      userSettings ? { },
    }:
    let
      relevantFeatures = lib.filterAttrs (
        name: f: lib.elem name activeFeatureNames && f.settings or { } != { }
      ) featuresConfig;

      settingsOptions = lib.mapAttrs (
        _name: feature:
        mkOption {
          type = types.submodule { options = feature.settings; };
          default = { };
        }
      ) relevantFeatures;

      envModule =
        { lib, ... }:
        {
          config = lib.mapAttrs (_: value: lib.mapAttrs (_: lib.mkDefault) value) (
            lib.intersectAttrs relevantFeatures envSettings
          );
        };

      hostModule =
        _:
        {
          config = lib.intersectAttrs relevantFeatures hostSettings;
        };

      userModule =
        _:
        {
          config = lib.intersectAttrs relevantFeatures userSettings;
        };

      evaluated = lib.evalModules {
        modules = [
          { options = settingsOptions; }
          envModule
          hostModule
          userModule
        ];
      };
    in
    evaluated.config;
in
{
  options.features = mkOption {
    type = types.lazyAttrsOf (types.submodule featureSubmodule);
    default = { };
    description = "Feature definitions with NixOS and Home-Manager modules.";
  };

  config.flake.lib.modules = {
    inherit
      mkDeferredModuleOpt
      collectTypedModules
      collectSystemModules
      collectLinuxModules
      collectDarwinModules
      collectHomeModules
      collectPlatformSystemModules
      collectRequires
      coreFeatures
      getModulesForFeatures
      computeActiveFeatures
      mkFeatureSettingsOpt
      resolveFeatureSettings
      ;
  };
}
