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

  # Extract function argument names from a module value.
  # Returns [] for plain attrsets (no function args = no context needed).
  extractModuleArgs =
    module:
    if builtins.isFunction module then
      builtins.attrNames (builtins.functionArgs module)
    else
      [ ];

  # Standard HM module args that don't require external context from our flake.
  # `inputs` is included because we pass it via extraSpecialArgs in the wrapper.
  # `osConfig` is NOT standard — it requires a real NixOS system evaluation.
  standardHomeArgs = [
    "config"
    "lib"
    "pkgs"
    "options"
    "modulesPath"
    "inputs"
  ];

  # Non-standard args that require context beyond an isolated HM evaluation.
  # Used to classify features by what context they need for wrapping.
  contextArgTiers = {
    osConfig = "osConfig"; # needs NixOS system configuration
    user = "user"; # needs user identity
    environment = "environment"; # needs environment config
    host = "host"; # needs host topology
    settings = "settings"; # needs system-level settings
    users = "users"; # needs all resolved users
    cluster = "cluster"; # needs cluster config
    flakeLib = "flakeLib"; # internal: flake library functions
  };

  featureSubmodule =
    {
      name,
      config,
      options,
      ...
    }:
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
            System-level option declarations for per-feature configuration.
            Available at settings.<featureName> in all feature modules.
            Settable at environment and host level.
          '';
        };

        # Per-user typed settings for home-manager modules
        user-settings = mkOption {
          type = types.lazyAttrsOf types.raw;
          default = { };
          description = ''
            User-level option declarations for per-feature configuration.
            Available at user.settings.<featureName> in home modules.
            Settable per-user at canonical, environment, and host level.
          '';
        };

        # Whether the home module requires system modules to function.
        # Defaults to true when system/linux/darwin modules are defined.
        # Set to false for features where system modules are optional
        # (e.g., spicetify firewall ports aren't needed for the app to work).
        homeRequiresSystem = mkOption {
          type = types.bool;
          default = true;
          description = "Whether the home module depends on the system modules to function.";
        };

        # Computed: argument names of the .home module function.
        # Introspected from raw definitions before deferredModule coercion.
        # Empty list for plain attrsets or features with no home module.
        homeArgs = mkOption {
          type = types.listOf types.str;
          readOnly = true;
          internal = true;
          description = "Function argument names of the home module (introspected).";
        };

        # Computed: whether this feature defines system-level modules (system/linux/darwin).
        hasSystemModules = mkOption {
          type = types.bool;
          readOnly = true;
          internal = true;
          description = "Whether this feature defines NixOS/Darwin system modules.";
        };

        # Computed: whether this feature can be wrapped as a standalone package.
        wrappable = mkOption {
          type = types.bool;
          readOnly = true;
          internal = true;
          description = "Whether this feature can be wrapped as a standalone package (home-only, no external context).";
        };

        # Computed: which custom context args this feature's .home module requires.
        # Empty list = Tier 1 (wrappable). Non-empty = lists the specific context needed.
        # e.g., ["user" "environment"] for git, ["host"] for gpg.
        contextRequirements = mkOption {
          type = types.listOf types.str;
          readOnly = true;
          internal = true;
          description = "Custom flake context args required by this feature's home module.";
        };

        name = mkOption {
          type = types.str;
          default = name;
          readOnly = true;
          internal = true;
        };
      };

      config = {
        homeArgs =
          let
            defs = options.home.definitionsWithLocations;
            rawModules = map (d: d.value) defs;
          in
          lib.unique (lib.concatMap extractModuleArgs rawModules);

        hasSystemModules =
          let
            hasDefs = opt: builtins.any (d: d.value != { }) opt.definitionsWithLocations;
          in
          hasDefs options.system || hasDefs options.linux || hasDefs options.darwin;

        wrappable =
          let
            homeDefs = options.home.definitionsWithLocations;
            hasHome = builtins.any (d: d.value != { }) homeDefs;
            systemBlocks = config.hasSystemModules && config.homeRequiresSystem;
          in
          hasHome && config.contextRequirements == [ ] && !systemBlocks;

        contextRequirements =
          let
            knownContextArgs = builtins.attrNames contextArgTiers;
          in
          builtins.filter (a: builtins.elem a knownContextArgs) config.homeArgs;
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

  # Generate a typed settings option from features.
  # settingsKey selects which field to read from features ("settings" or "user-settings").
  mkSettingsOpt =
    settingsKey: featuresConfig: description:
    let
      relevant = lib.filterAttrs (_: f: f.${settingsKey} or { } != { }) featuresConfig;
    in
    mkOption {
      type = types.submodule {
        options = lib.mapAttrs (
          name: feature:
          mkOption {
            type = types.submodule { options = feature.${settingsKey}; };
            default = { };
            description = "Settings for the ${name} feature";
          }
        ) relevant;
      };
      default = { };
      inherit description;
    };

  # System-level settings (hosts/environments)
  mkFeatureSettingsOpt = mkSettingsOpt "settings";

  # User-level settings (per-user on canonical/env/host users)
  mkFeatureUserSettingsOpt = mkSettingsOpt "user-settings";

  # Resolve feature settings by merging layers via evalModules.
  # settingsKey selects "settings" or "user-settings" from features.
  # Priority (lowest to highest): feature defaults → envSettings (mkDefault) → hostSettings → userSettings
  resolveFeatureSettings =
    {
      settingsKey ? "settings",
      activeFeatureNames,
      featuresConfig,
      layers ? [ ],
    }:
    let
      relevantFeatures = lib.filterAttrs (
        name: f: lib.elem name activeFeatureNames && f.${settingsKey} or { } != { }
      ) featuresConfig;

      settingsOptions = lib.mapAttrs (
        _name: feature:
        mkOption {
          type = types.submodule { options = feature.${settingsKey}; };
          default = { };
        }
      ) relevantFeatures;

      # Filter each layer's config to only include relevant features
      filteredLayers = map (
        layer: args:
        let
          result = if lib.isFunction layer then layer args else layer;
          filteredConfig = lib.intersectAttrs relevantFeatures (result.config or { });
        in
        result // { config = filteredConfig; }
      ) layers;

      evaluated = lib.evalModules {
        modules = [
          { options = settingsOptions; }
        ]
        ++ filteredLayers;
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
      mkSettingsOpt
      mkFeatureSettingsOpt
      mkFeatureUserSettingsOpt
      resolveFeatureSettings
      ;
  };
}
