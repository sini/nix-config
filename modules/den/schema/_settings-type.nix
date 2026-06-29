# Shared dynamic settings type — recursively discovers aspects that declare a
# `.settings` block and mirrors the aspect tree into a typed submodule. Used by
# BOTH the host and cluster entity schemas so each exposes the SAME per-aspect
# settings namespace:
#   den.aspects.<path>.settings  →  host.settings.<path>.*
#                                →  cluster.settings.<path>.*
#
# Underscore prefix keeps import-tree from auto-importing this; host.nix and
# cluster.nix import it explicitly with `{ inherit den lib; }`.
{ den, lib }:
let
  inherit (lib) mkOption types;
  inherit (den.lib.aspects.fx.keyClassification) structuralKeysSet;
  classKeys = den.classes or { };
  quirkKeys = den.quirks or { };
  skipKey = k: structuralKeysSet ? ${k} || classKeys ? ${k} || quirkKeys ? ${k};

  # Settings declarations may be plain option attrsets
  # (`{ foo = mkOption {...}; }`) or module-shaped with explicit
  # imports/config. Default the module keys so plain attrsets work.
  #
  # imports'/config' are bound under distinct names on purpose: writing
  # `imports = raw.imports or [ ]` here gets rewritten by statix (W04) to
  # `inherit (raw) imports`, which DROPS the `or` default and throws when
  # raw is a plain options attrset with no imports/config key.
  reshapeSettings =
    raw:
    let
      imports' = raw.imports or [ ];
      config' = raw.config or { };
    in
    {
      imports = imports';
      config = config';
      options = removeAttrs raw [
        "imports"
        "config"
      ];
    };

  # True if a node has .settings anywhere in its aspect subtree.
  hasSettingsDeep =
    node:
    builtins.isAttrs node
    && (
      (node ? settings)
      || lib.any (k: !(skipKey k) && hasSettingsDeep (node.${k} or null)) (builtins.attrNames node)
    );

  # Build the submodule for one aspect-tree node, mirroring the tree.
  # A node may be BOTH an aspect with .settings AND a parent of child
  # aspects that have settings (e.g. services.bgp has localAsn settings and
  # also parents services.bgp.cilium-bgp). Merge the node's own settings
  # options with recursion into its settings-bearing children.
  nodeModule =
    node:
    let
      ownSettings =
        if node ? settings then
          reshapeSettings node.settings
        else
          {
            imports = [ ];
            config = { };
            options = { };
          };
      settingChildren = lib.filterAttrs (
        k: v: !(skipKey k) && builtins.isAttrs v && hasSettingsDeep v
      ) node;
      childOptions = lib.mapAttrs (
        name: child:
        mkOption {
          type = types.submodule (nodeModule child);
          default = { };
          description = "Settings under ${name}";
        }
      ) settingChildren;
      # Distinct names so statix (W04) can't rewrite to
      # `inherit (ownSettings) imports`, which would drop the `or` default.
      ownImports = ownSettings.imports or [ ];
      ownConfig = ownSettings.config or { };
    in
    {
      imports = ownImports;
      config = ownConfig;
      options = (ownSettings.options or { }) // childOptions;
    };
in
types.submodule (nodeModule (den.aspects or { }))
