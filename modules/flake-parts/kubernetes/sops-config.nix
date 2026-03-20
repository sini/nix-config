{
  config,
  lib,
  ...
}:
let
  # Extract age recipients from master identity .pub files.
  # These files contain a comment line: #    Recipient: age1...
  extractRecipient =
    pubFile:
    let
      contents = builtins.readFile pubFile;
      lines = lib.splitString "\n" contents;
      recipientLines = builtins.filter (
        line: lib.hasPrefix "#" line && lib.hasInfix "Recipient:" line
      ) lines;
      # Extract the age1... key from "# Recipient: age1..."
      parseRecipient =
        line:
        let
          parts = lib.splitString "Recipient: " line;
        in
        lib.trim (lib.last parts);
    in
    if recipientLines != [ ] then parseRecipient (builtins.head recipientLines) else null;

  masterRecipients = lib.unique (
    builtins.filter (r: r != null) (map extractRecipient config.flake.secretsConfig.masterIdentities)
  );

  # Generate per-cluster creation rules from clusters with a sopsAgeRecipient
  clusterRules = lib.concatMapAttrs (
    clusterName: cluster:
    let
      compositeKey = "${cluster.environment}-${clusterName}";
    in
    lib.optionalAttrs (cluster.sopsAgeRecipient != null) {
      ${compositeKey} = {
        path_regex = ".*${lib.escapeRegex compositeKey}.*/(SopsS|S)ecret-.*\\.ya?ml$";
        encrypted_regex = "^(data|stringData)$";
        mac-only-encrypted = true;
        key_groups = [
          {
            age = [ cluster.sopsAgeRecipient ];
          }
        ];
      };
    }
  ) config.clusters;

  sopsConfig = {
    creation_rules = [
      # Master keys for manually encrypted files
      {
        path_regex = ".*\\.enc\\.ya?ml$";
        key_groups = [
          {
            age = masterRecipients;
          }
        ];
      }
    ]
    ++ (lib.mapAttrsToList (_: rule: rule) clusterRules);
  };
in
{
  perSystem =
    { pkgs, ... }:
    let
      sopsYaml =
        pkgs.runCommand ".sops.yaml"
          {
            nativeBuildInputs = [ pkgs.yq ];
            json = builtins.toJSON sopsConfig;
            passAsFile = [ "json" ];
          }
          ''
            yq -y '.' "$jsonPath" > $out
          '';
    in
    {
      files.files = [
        {
          path_ = ".sops.yaml";
          drv = sopsYaml;
        }
      ];
    };
}
