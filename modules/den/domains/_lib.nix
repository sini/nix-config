# Pure domain routing and record-key helpers, shared by the domain policies,
# the terranix records module and their check (checks/domains-lib).
{ lib }:
rec {
  # The longest candidate that is `name` or a parent of it; null when none.
  longestSuffix =
    candidates: name:
    lib.findFirst (z: name == z || lib.hasSuffix ".${z}" name) null (
      lib.sort (a: b: lib.stringLength a > lib.stringLength b) candidates
    );

  # The nearest proper ancestor of `name` among `candidates`.
  parentOf = candidates: name: longestSuffix (lib.remove name candidates) name;

  # A record's resource key: name, type and a short hash of its content, so
  # several records can share a name and reordering never changes a key.
  recordKey =
    r:
    "${lib.replaceStrings [ "." "*" ] [ "_" "wildcard" ] r.name}_${r.type}_${
      builtins.substring 0 8 (builtins.hashString "sha256" r.content)
    }";
}
