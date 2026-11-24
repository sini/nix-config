# The people in a kanidm group through nested groups, by their kanidm short names.
# den.groups lists a group's member groups; people join groups through their own
# `facts.groups` in den.users, which is what kanidm provisions
# (services/security/kanidm.nix).
{ config, lib }:
group:
let
  groups = config.den.groups;
  nested =
    s:
    let
      n = lib.unique (s ++ lib.concatMap (g: groups.${g}.members or [ ]) s);
    in
    if lib.length n == lib.length s then s else nested n;
  within = nested [ group ];
in
lib.attrNames (
  lib.filterAttrs (_: u: lib.any (g: lib.elem g within) u.facts.groups) config.den.users
)
