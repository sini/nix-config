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

    # Cross-platform system module (included on both NixOS and Darwin)
    system = mkDeferredModuleOpt "A cross-platform system module for this feature (NixOS and Darwin)";

    # Platform-specific system modules (for config that only applies to one platform)
    linux = mkDeferredModuleOpt "A Linux-specific system module for this feature (NixOS only)";
    darwin = mkDeferredModuleOpt "A Darwin-specific system module for this feature (macOS only)";

    # Home-manager module (works on all platforms)
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

  mkUsersWithFeaturesOpt =
    description:
    mkOption {
      type = types.lazyAttrsOf (
        types.submodule (
          { name, ... }:
          {
            options = {
              # Home Manager / system user options
              features = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = ''
                  List of features specific to the user.

                  While a feature may specify NixOS modules in addition to home
                  modules, only home modules will affect configuration. For this
                  reason, users should be encouraged to avoid pointlessly specifying
                  their own NixOS modules.
                '';
              };
              configuration = mkDeferredModuleOpt "User-specific home configuration";

              baseline = mkOption {
                type = types.submodule {
                  options = {
                    features = mkOption {
                      type = types.listOf types.str;
                      default = [ ];
                      description = ''
                        List of baseline features shared by all of this user's configurations.
                      '';
                    };
                    inheritHostFeatures = mkOption {
                      type = types.bool;
                      default = false;
                      description = ''
                        Whether to inherit all home-manager features from the host configuration.

                        When true, this user will receive all home-manager modules from the host's
                        enabled features. When false, only user-specific features and baseline features
                        will be included.
                      '';
                    };
                  };
                };
                description = "Baseline features and configurations shared by all of this user's configurations";
                default = { };
              };

              enableUnixAccount = mkOption {
                type = types.bool;
                default = false;
                description = ''
                  Whether to create a Unix user account on hosts.
                  If false, this is an identity-only user (e.g., for Kanidm).
                '';
              };

              # Unix account options
              uid = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "User ID for the Unix account";
              };

              gid = mkOption {
                type = types.nullOr types.int;
                default = null;
                description = "Group ID for the Unix account (defaults to uid if not set)";
              };

              linger = mkOption {
                type = types.bool;
                default = false;
                description = "Enable lingering for the user (systemd user services start without login)";
              };

              systemGroups = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = ''
                  System groups (extraGroups) for the user.
                  Example: ["wheel", "networkmanager", "podman"]
                '';
              };

              # Identity options (used by Kanidm, Forgejo, etc.)
              displayName = mkOption {
                type = types.str;
                default = name;
                description = "Display name for the user (defaults to username)";
              };

              email = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = ''
                  Email address for the user.
                  If null, defaults to username@domain.
                  If set, used as the full email address.
                '';
              };

              groups = mkOption {
                type = types.listOf types.str;
                default = [ "users" ];
                description = "List of identity groups the user belongs to (defaults to ['users'])";
              };

              sshKeys = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = ''
                  SSH public keys for the user.
                  Can be used by system user configuration, Forgejo, etc.
                '';
              };

              gpgKey = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = ''
                  GPG key ID for the user (parent key ID).
                  Used for git commit signing, sops encryption, etc.
                '';
              };
            };
          }
        )
      );
      default = { };
      inherit description;
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
              visitedWithDeps = traverseDependencies visited dependencies updatedExclusions;
            in
            traverseDependencies (visitedWithDeps ++ [ current ]) remaining updatedExclusions;

      resultWithRoots = traverseDependencies [ ] roots initialExclusions;
      allExclusions = lib.unique (lib.flatten (lib.catAttrs "excludes" (roots ++ resultWithRoots)));
      dependenciesOnly = filter (
        v: !(elem v.name allExclusions) && !(elem v.name rootNames)
      ) resultWithRoots;
    in
    dependenciesOnly;

  # Get feature names from roles
  # Takes: roles config, host roles list
  # Returns: list of feature names
  getFeaturesForRoles =
    rolesConfig: hostRoles:
    let
      coreFeatures = rolesConfig.core.features;
      additionalFeatures = lib.optionals (hostRoles != null) (
        lib.flatten (
          map (roleName: rolesConfig.${roleName}.features) (
            lib.filter (roleName: lib.hasAttr roleName rolesConfig) hostRoles
          )
        )
      );
      allFeatureNames = lib.unique (coreFeatures ++ additionalFeatures);
    in
    allFeatureNames;

  # Resolve complete feature set for a host (roles + direct features + dependencies)
  # Returns feature modules with all dependencies resolved and exclusions applied
  # Takes: features config, roles config, and host options
  getModulesForFeatures =
    {
      featuresConfig,
      rolesConfig,
      hostRoles,
      hostFeatures ? [ ],
      hostExclusions ? [ ],
    }:
    let
      roleFeatureNames = getFeaturesForRoles rolesConfig hostRoles;
      allFeatureNames = lib.unique (roleFeatureNames ++ hostFeatures);
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
      rolesConfig,
      hostRoles,
      hostFeatures ? [ ],
      hostExclusions ? [ ],
    }:
    let
      allHostFeatures = getModulesForFeatures {
        inherit
          featuresConfig
          rolesConfig
          hostRoles
          hostFeatures
          hostExclusions
          ;
      };
    in
    lib.unique (map (f: f.name) allHostFeatures);
in
{
  flake.lib.modules = {
    inherit
      featureSubmoduleGenericOptions
      mkFeatureNameOpt
      mkDeferredModuleOpt
      mkUsersWithFeaturesOpt
      collectTypedModules
      collectSystemModules
      collectLinuxModules
      collectDarwinModules
      collectHomeModules
      collectPlatformSystemModules
      collectRequires
      getFeaturesForRoles
      getModulesForFeatures
      computeActiveFeatures
      ;
  };
}
