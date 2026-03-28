# Collect typed modules from resolved features with parametric dispatch filtering.
{ lib, ... }:
let
  # Generic collector for modules of a specific type from feature list
  # Skips features where the type key is missing or set to the default empty module
  collectTypedModules =
    type: lib.foldr (v: acc: if v.${type} or null != null then acc ++ [ v.${type} ] else acc) [ ];

  # Filter features/providers whose slot modules require unavailable context
  filterBySlotContext =
    logPrefix: dispatchableArgs: availableContext: slot: sources:
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
            lib.warn "Parametric dispatch filtered ${toString (lib.length removed)} ${logPrefix} features from ${slot}: ${lib.concatMapStringsSep ", " (s: s.name or "unknown") removed}" null
          else
            null;
      in
      builtins.seq _ filtered;

  # Collect all applicable system modules for a given platform
  # Includes: os + system (both forward to current platform) + platform-specific (linux/darwin)
  # Collects from both features and their active providers
  # When dispatchableArgs is non-empty, filters features by per-slot required context args
  collectPlatformSystemModules =
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

      filterSlot = filterBySlotContext "system" dispatchableArgs availableContext;

      collectFromSources =
        sources:
        let
          osModules = collectTypedModules "os" (filterSlot "os" sources);
          systemModules = collectTypedModules "system" (filterSlot "system" sources);
          platformModules =
            if isLinux then
              collectTypedModules "linux" (filterSlot "linux" sources)
            else if isDarwin then
              collectTypedModules "darwin" (filterSlot "darwin" sources)
            else
              throw "Unsupported system architecture: ${system}";
        in
        osModules ++ systemModules ++ platformModules;
    in
    collectFromSources features ++ collectFromSources activeProviders;

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

      filterSlot = filterBySlotContext "home" dispatchableArgs availableContext;

      collectFromSources =
        sources:
        let
          homeModules = collectTypedModules "home" (filterSlot "home" sources);
          platformHome =
            if isLinux then
              collectTypedModules "homeLinux" (filterSlot "homeLinux" sources)
            else if isDarwin then
              collectTypedModules "homeDarwin" (filterSlot "homeDarwin" sources)
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
      collectPlatformSystemModules
      collectPlatformHomeModules
      ;
  };
}
