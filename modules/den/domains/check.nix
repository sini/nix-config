# Runnable check for the domain routing and record-key helpers (./_lib.nix):
#   nix build .#checks.x86_64-linux.domains-lib
{ lib, ... }:
let
  inherit (import ./_lib.nix { inherit lib; }) longestSuffix parentOf recordKey;

  mx = content: priority: {
    name = "json64.dev";
    type = "MX";
    inherit content priority;
  };
  keysOf = rs: lib.sort lib.lessThan (map recordKey rs);
  zones = [
    "gen.wtf"
    "json64.dev"
  ];
  domains = zones ++ [
    "dev.json64.dev"
    "s3.json64.dev"
  ];

  failures = lib.runTests {
    # Keys depend on the record, not its position: reordering keeps every key.
    testKeysStableUnderReorder = {
      expr = keysOf [
        (mx "mail.protonmail.ch" 10)
        (mx "mailsec.protonmail.ch" 20)
      ];
      expected = keysOf [
        (mx "mailsec.protonmail.ch" 20)
        (mx "mail.protonmail.ch" 10)
      ];
    };
    # Records sharing a name and type get distinct keys.
    testKeysDistinctForSharedName = {
      expr = recordKey (mx "mail.protonmail.ch" 10) != recordKey (mx "mailsec.protonmail.ch" 20);
      expected = true;
    };
    testKeyShape = {
      expr = lib.hasPrefix "wildcard_s3_json64_dev_A_" (recordKey {
        name = "*.s3.json64.dev";
        type = "A";
        content = "157.131.140.225";
      });
      expected = true;
    };
    # A sub-zone with no zone of its own is hosted in its parent.
    testSubZoneHostedInParent = {
      expr = longestSuffix zones "argocd.dev.json64.dev";
      expected = "json64.dev";
    };
    # Once delegated (its own zone), the longer suffix wins.
    testLongestSuffixWins = {
      expr = longestSuffix (zones ++ [ "dev.json64.dev" ]) "argocd.dev.json64.dev";
      expected = "dev.json64.dev";
    };
    testApexIsItsOwnZone = {
      expr = longestSuffix zones "json64.dev";
      expected = "json64.dev";
    };
    # A label boundary, not a string suffix: notjson64.dev is not in json64.dev.
    testLabelBoundary = {
      expr = longestSuffix zones "notjson64.dev";
      expected = null;
    };
    testUnmanaged = {
      expr = longestSuffix zones "argocd.zeroday.run";
      expected = null;
    };
    testParentOfSubZone = {
      expr = parentOf domains "dev.json64.dev";
      expected = "json64.dev";
    };
    testParentOfTopLevel = {
      expr = parentOf domains "json64.dev";
      expected = null;
    };
  };
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.domains-lib =
        assert lib.assertMsg (failures == [ ]) "domains-lib: ${builtins.toJSON failures}";
        pkgs.runCommand "domains-lib" { } "touch $out";
    };
}
