{
  lib,
  self,
  ...
}:
let
  # Collect all secrets from a configuration
  collectSecrets =
    configName: cfg:
    let
      secrets = cfg.config.age.secrets or { };
    in
    lib.mapAttrsToList (
      secretName: secretConfig:
      let
        hasGenerator = secretConfig ? generator;
        hasGeneratorScript = hasGenerator && (secretConfig.generator ? script);

        # Only truly generated if it has a script to generate content
        isGenerated = hasGeneratorScript;

        generatorType =
          if !hasGeneratorScript then
            null
          else if builtins.isString secretConfig.generator.script then
            "built-in: ${secretConfig.generator.script}"
          else if
            builtins.isFunction secretConfig.generator.script
            || (builtins.isAttrs secretConfig.generator.script && secretConfig.generator.script ? __functor)
          then
            "custom-script"
          else
            "unknown";

        rekeyFile = secretConfig.rekeyFile or null;
        rekeyPath =
          if rekeyFile != null then lib.removePrefix "${toString self}/" (toString rekeyFile) else null;

        isIntermediary = secretConfig.intermediary or false;
      in
      {
        inherit
          secretName
          configName
          isGenerated
          generatorType
          rekeyPath
          isIntermediary
          ;
        owner = secretConfig.owner or "root";
        group = secretConfig.group or "root";
        mode = secretConfig.mode or "0400";
        hasDependencies = hasGeneratorScript && (secretConfig.generator.dependencies or [ ]) != [ ];
      }
    ) secrets;

  # Collect from NixOS configurations
  nixosSecrets = lib.flatten (
    lib.mapAttrsToList (hostName: host: collectSecrets "nixos:${hostName}" host) (self.nodes or { })
  );

  # Collect from Darwin configurations
  darwinSecrets = lib.flatten (
    lib.mapAttrsToList (hostName: host: collectSecrets "darwin:${hostName}" host) (
      self.outputs.darwinConfigurations or { }
    )
  );

  # Collect from Home Manager configurations
  homeManagerSecrets =
    let
      collectFromHost =
        hostName: host:
        let
          hmUsers = host.config.home-manager.users or { };
        in
        lib.flatten (
          lib.mapAttrsToList (
            userName: userConfig: collectSecrets "home:${userName}@${hostName}" { config = userConfig; }
          ) hmUsers
        );
    in
    lib.flatten (
      lib.mapAttrsToList (hostName: host: collectFromHost hostName host) (self.nodes or { })
    );

  # Combine all secrets
  allSecrets = nixosSecrets ++ darwinSecrets ++ homeManagerSecrets;

  # Group secrets by their rekeyFile path to merge duplicates
  groupedSecrets =
    let
      # Create a unique key based on rekeyFile and secretName
      getKey = s: "${s.secretName}|${s.rekeyPath or "no-rekey"}";

      # Fold secrets into groups
      grouped = lib.foldl' (
        acc: secret:
        let
          key = getKey secret;
          existing = acc.${key} or null;
        in
        if existing == null then
          acc
          // {
            ${key} = secret // {
              usedBy = [ secret.configName ];
            };
          }
        else
          acc
          // {
            ${key} = existing // {
              usedBy = existing.usedBy ++ [ secret.configName ];
            };
          }
      ) { } allSecrets;
    in
    builtins.attrValues grouped;

  # Separate into generated and manual
  generatedSecrets = builtins.filter (s: s.isGenerated) groupedSecrets;
  manualSecrets = builtins.filter (s: !s.isGenerated) groupedSecrets;

  # Sort secrets by name
  sortByName = builtins.sort (a: b: a.secretName < b.secretName);

  # Format a single secret entry
  formatSecret =
    secret:
    let
      usedByList =
        if builtins.length secret.usedBy == 1 then
          builtins.head secret.usedBy
        else
          "\n  " + lib.concatStringsSep "\n  " (map (c: "- ${c}") secret.usedBy);
    in
    ''
      ### ${secret.secretName}
      - **Used by**: ${usedByList}
      - **Owner**: ${secret.owner}:${secret.group} (${secret.mode})
      ${lib.optionalString (secret.rekeyPath != null) "- **Rekey File**: `${secret.rekeyPath}`"}
      ${lib.optionalString secret.isGenerated "- **Generator**: ${secret.generatorType}"}
      ${lib.optionalString secret.hasDependencies "- **Has Dependencies**: Yes"}
      ${lib.optionalString secret.isIntermediary "- **Intermediary**: Yes (not exposed to services)"}
    '';

  # Generate the complete manifest
  generateManifest = ''
    # Agenix Secrets Manifest

    Generated on: ${lib.trivial.release}
    Total unique secrets: ${toString (builtins.length groupedSecrets)}
    - Generated: ${toString (builtins.length generatedSecrets)}
    - Manually set: ${toString (builtins.length manualSecrets)}

    ---

    ## Manually Set Secrets

    These secrets must be manually created and encrypted. They are stored in the repository
    and rekeyed for each host.

    ${lib.concatStringsSep "\n" (map formatSecret (sortByName manualSecrets))}

    ---

    ## Generated Secrets

    These secrets are automatically generated using agenix-rekey's generator functionality.
    They will be created automatically if they don't exist.

    ${lib.concatStringsSep "\n" (map formatSecret (sortByName generatedSecrets))}

    ---

    ## Secret File Organization

    ### User Secrets
    - Location: `.secrets/users/<username>/`
    - Types: hashed passwords, age identities

    ### Environment Secrets
    - Location: `.secrets/env/<environment>/`
    - Types: OIDC credentials, API keys, cluster tokens

    ### Service Secrets
    - Location: `.secrets/services/<service>/`
    - Types: certificates, API keys, service-specific credentials

    ---

    ## Master Identities

    Secrets can be decrypted using any of these master keys:
    - `.secrets/pub/master.pub`
    - `.secrets/pub/master-clone1.pub`
    - `.secrets/pub/master-clone2.pub`
  '';
in
{
  perSystem =
    { pkgs, ... }:
    {
      files.files = [
        {
          path_ = ".secrets/secrets-manifest.md";
          drv = pkgs.writeText "secrets-manifest.md" generateManifest;
        }
      ];
    };
}
