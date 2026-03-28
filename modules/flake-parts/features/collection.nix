{ lib, ... }:
let
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
  # Includes: os + system (both forward to current platform) + platform-specific (linux/darwin)
  # Collects from both features and their active providers
  # When dispatchableArgs is non-empty, filters features by per-slot required context args
  collectPlatformSystemModulesNew =
    {
      features,
      activeProviders ? [ ],
      system,
      dispatchableArgs ? [ ],
      availableContext ? { },
    }:
    let
      isDarwin = lib.hasSuffix "-darwin" system;
      isLinux = lib.hasSuffix "-linux" system;

      # Filter features/providers whose slot modules require unavailable context
      filterBySlotContext =
        slot: sources:
        if dispatchableArgs == [ ] then
          sources
        else
          let
            filtered = lib.filter (
              src:
              let
                requiredArgs = src._requiredContextArgs.${slot} or [ ];
              in
              lib.all (name: availableContext ? ${name}) requiredArgs
            ) sources;
            removed = lib.filter (
              src:
              let
                requiredArgs = src._requiredContextArgs.${slot} or [ ];
              in
              !(lib.all (name: availableContext ? ${name}) requiredArgs)
            ) sources;
            _ =
              if removed != [ ] then
                lib.warn "Parametric dispatch filtered ${toString (lib.length removed)} features from ${slot}: ${lib.concatMapStringsSep ", " (s: s.name or "unknown") removed}" null
              else
                null;
          in
          builtins.seq _ filtered;

      collectFromSources =
        sources:
        let
          osModules = collectTypedModules "os" (filterBySlotContext "os" sources);
          systemModules = collectTypedModules "system" (filterBySlotContext "system" sources);
          platformModules =
            if isLinux then
              collectTypedModules "linux" (filterBySlotContext "linux" sources)
            else if isDarwin then
              collectTypedModules "darwin" (filterBySlotContext "darwin" sources)
            else
              throw "Unsupported system architecture: ${system}";
        in
        osModules ++ systemModules ++ platformModules;
    in
    collectFromSources features ++ collectFromSources activeProviders;

  # Backward-compatible wrapper: old (features, system) signature
  collectPlatformSystemModules =
    features: system: collectPlatformSystemModulesNew { inherit features system; };

  # Collect all applicable home modules for a given platform
  collectPlatformHomeModules =
    {
      features,
      activeProviders ? [ ],
      system,
      dispatchableArgs ? [ ],
      availableContext ? { },
    }:
    let
      isDarwin = lib.hasSuffix "-darwin" system;
      isLinux = lib.hasSuffix "-linux" system;

      filterBySlotContext =
        slot: sources:
        if dispatchableArgs == [ ] then
          sources
        else
          let
            filtered = lib.filter (
              src:
              let
                requiredArgs = src._requiredContextArgs.${slot} or [ ];
              in
              lib.all (name: availableContext ? ${name}) requiredArgs
            ) sources;
            removed = lib.filter (
              src:
              let
                requiredArgs = src._requiredContextArgs.${slot} or [ ];
              in
              !(lib.all (name: availableContext ? ${name}) requiredArgs)
            ) sources;
            _ =
              if removed != [ ] then
                lib.warn "Parametric dispatch filtered ${toString (lib.length removed)} home features from ${slot}: ${lib.concatMapStringsSep ", " (s: s.name or "unknown") removed}" null
              else
                null;
          in
          builtins.seq _ filtered;

      collectFromSources =
        sources:
        let
          homeModules = collectTypedModules "home" (filterBySlotContext "home" sources);
          platformHome =
            if isLinux then
              collectTypedModules "homeLinux" (filterBySlotContext "homeLinux" sources)
            else if isDarwin then
              collectTypedModules "homeDarwin" (filterBySlotContext "homeDarwin" sources)
            else
              [ ];
        in
        homeModules ++ platformHome;
    in
    collectFromSources features ++ collectFromSources activeProviders;
in
{
  config.flake.lib.features.collection = {
    inherit
      collectTypedModules
      collectSystemModules
      collectLinuxModules
      collectDarwinModules
      collectHomeModules
      collectPlatformSystemModulesNew
      collectPlatformSystemModules
      collectPlatformHomeModules
      ;
  };
}
