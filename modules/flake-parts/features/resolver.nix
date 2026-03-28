# Two-phase feature resolver: explicit dependency traversal then provider collection.
{ lib, ... }:
let
  inherit (lib)
    attrNames
    elem
    filter
    hasAttr
    length
    splitString
    unique
    warn
    ;

  # ============================================================================
  # Utility Functions
  # ============================================================================

  # Parse an include path into its type and components.
  # "bat" → { type = "feature"; feature = "bat"; }
  # "bat/alias-as-cat" → { type = "provider"; feature = "bat"; provider = "alias-as-cat"; }
  parseIncludePath =
    path:
    let
      parts = splitString "/" path;
      len = length parts;
    in
    if len == 1 then
      {
        type = "feature";
        feature = builtins.elemAt parts 0;
      }
    else if len == 2 then
      {
        type = "provider";
        feature = builtins.elemAt parts 0;
        provider = builtins.elemAt parts 1;
      }
    else
      throw "Invalid include path '${path}': at most one slash allowed (feature or feature/provider)";

  # Validate a parsed include against the features configuration.
  validateInclude =
    featuresConfig: parsed:
    if !hasAttr parsed.feature featuresConfig then
      throw "Include references unknown feature '${parsed.feature}'"
    else if
      parsed.type == "provider" && !hasAttr parsed.provider featuresConfig.${parsed.feature}.provides
    then
      throw "Include references unknown provider '${parsed.provider}' on feature '${parsed.feature}'"
    else
      parsed;

  # Merge includes and requires for backward compatibility.
  getFeatureIncludes = feature: unique (feature.includes ++ feature.requires);

  # ============================================================================
  # Phase 1 — Explicit Resolution
  # ============================================================================

  # Resolve explicitly included features and providers via depth-first traversal.
  resolveExplicit =
    featuresConfig:
    {
      initialFeatureNames,
      initialExclusions ? [ ],
    }:
    let
      # Build initial state then process the queue
      initialState = {
        features = { };
        providers = { };
        exclusions = initialExclusions;
      };

      # Process a list of include path strings with cycle detection.
      # chain: list of path strings representing the current DFS path (for cycle detection)
      # state: { features, providers, exclusions }
      # paths: list of include path strings to process
      processIncludes =
        chain: state: paths:
        builtins.foldl' (acc: path: processOnePath chain acc path) state paths;

      processOnePath =
        chain: state: path:
        let
          parsed = validateInclude featuresConfig (parseIncludePath path);
        in
        if parsed.type == "feature" then
          processFeatureInclude chain state parsed
        else
          processProviderInclude chain state parsed;

      processFeatureInclude =
        chain: state: parsed:
        let
          name = parsed.feature;
          feature = featuresConfig.${name};
        in
        # Check exclusion first
        if elem name state.exclusions then
          state
        # Already visited (fully resolved) — skip
        else if hasAttr name state.features then
          state
        # Cycle detection: in chain but not yet fully resolved
        else if elem name chain then
          throw "Circular include detected: ${lib.concatStringsSep " → " (chain ++ [ name ])}"
        else
          let
            # Add feature and its excludes
            newExclusions = unique (state.exclusions ++ feature.excludes);
            stateWithFeature = state // {
              features = state.features // {
                ${name} = feature;
              };
              exclusions = newExclusions;
            };
            # Recurse into this feature's includes with updated chain
            childIncludes = filter (
              p:
              let
                cp = parseIncludePath p;
              in
              !elem cp.feature newExclusions
            ) (getFeatureIncludes feature);
          in
          processIncludes (chain ++ [ name ]) stateWithFeature childIncludes;

      processProviderInclude =
        chain: state: parsed:
        let
          featureName = parsed.feature;
          providerName = parsed.provider;
          providerId = "${featureName}/${providerName}";
        in
        # Check exclusion (feature-level or provider-level)
        if elem featureName state.exclusions || elem providerId state.exclusions then
          state
        # Already collected
        else if hasAttr providerId state.providers then
          state
        else
          let
            # Ensure the parent feature is activated first
            stateWithParent = processFeatureInclude chain state {
              type = "feature";
              feature = featureName;
            };
          in
          # Parent might have been excluded during its own processing
          if !hasAttr featureName stateWithParent.features then
            stateWithParent
          else
            let
              provider = featuresConfig.${featureName}.provides.${providerName};
              stateWithProvider = stateWithParent // {
                providers = stateWithParent.providers // {
                  ${providerId} = provider;
                };
              };
              # Recurse into provider's includes
              providerIncludes = provider.includes;
            in
            processIncludes (chain ++ [ providerId ]) stateWithProvider providerIncludes;

    in
    processIncludes [ ] initialState initialFeatureNames;

  # ============================================================================
  # Phase 2 — Provider Collection
  # ============================================================================

  # Scan active features for collectsProviders and gather matching providers.
  collectProviders =
    featuresConfig: phase1State:
    let
      # Find all active features that have collectsProviders set
      activeFeatures = phase1State.features;

      collectors = lib.concatMap (
        name:
        let
          feature = activeFeatures.${name};
          collectorNames = feature.collectsProviders;
        in
        map (cn: {
          collectorFeature = name;
          providerName = cn;
        }) collectorNames
      ) (attrNames activeFeatures);

      # Process all collectors, accumulating state
      processCollectors =
        state: remaining:
        if remaining == [ ] then
          state
        else
          let
            collector = builtins.head remaining;
            rest = builtins.tail remaining;
            newState = processOneCollector state collector;
          in
          processCollectors newState rest;

      processOneCollector =
        state: collector:
        let
          inherit (collector) providerName;

          # Scan all active features for matching provides.<providerName>
          matchingProviders = lib.concatMap (
            featureName:
            let
              feature = state.features.${featureName};
              inherit (feature) provides;
            in
            if hasAttr providerName provides then
              let
                provider = provides.${providerName};
                pid = provider._id;
              in
              # Skip if already collected or excluded
              if hasAttr pid state.providers || elem pid state.exclusions then
                [ ]
              else
                [
                  {
                    id = pid;
                    inherit provider featureName;
                  }
                ]
            else
              [ ]
          ) (attrNames state.features);

          # Warn if no providers matched
          _ =
            if matchingProviders == [ ] then
              warn "collectsProviders '${providerName}' on feature '${collector.collectorFeature}' matched zero providers" null
            else
              null;

          # Add matched providers and resolve their includes
          stateWithProviders = builtins.foldl' (
            acc: match:
            let
              withProvider = acc // {
                providers = acc.providers // {
                  ${match.id} = match.provider;
                };
              };
              # Resolve any includes the provider brings in
              providerIncludes = match.provider.includes;
            in
            if providerIncludes == [ ] then
              withProvider
            else
              let
                subResolved = resolveExplicit featuresConfig {
                  initialFeatureNames = providerIncludes;
                  initialExclusions = withProvider.exclusions;
                };
              in
              {
                features = withProvider.features // subResolved.features;
                providers = withProvider.providers // subResolved.providers;
                exclusions = unique (withProvider.exclusions ++ subResolved.exclusions);
              }
          ) (builtins.seq _ state) matchingProviders;
        in
        stateWithProviders;
    in
    processCollectors phase1State collectors;

  # ============================================================================
  # Top-level Resolution
  # ============================================================================

  coreFeatures = [ "default" ];

  # Full feature resolution pipeline.
  resolveFeatures =
    {
      featuresConfig,
      hostFeatures ? [ ],
      hostExclusions ? [ ],
    }:
    let
      allFeatureNames = unique (coreFeatures ++ hostFeatures);
      phase1 = resolveExplicit featuresConfig {
        initialFeatureNames = allFeatureNames;
        initialExclusions = hostExclusions;
      };
      phase2 = collectProviders featuresConfig phase1;
    in
    phase2;

  # ============================================================================
  # Backward Compatibility Wrappers
  # ============================================================================

  # Returns list of active feature name strings.
  computeActiveFeatures =
    args:
    let
      resolved = resolveFeatures args;
    in
    attrNames resolved.features;

in
{
  config.flake.lib.features.resolver = {
    inherit
      resolveFeatures
      computeActiveFeatures
      coreFeatures
      ;
  };
}
