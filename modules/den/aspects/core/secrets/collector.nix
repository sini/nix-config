{
  den.aspects.core.secrets.collector =
    let
      # `age-secrets` is a broadcast quirk: a shared-rekeyFile secret (e.g.
      # `registry-password`) is legitimately emitted by several aspects on a
      # single host — the registry host owns it AND the podman `containers`
      # aspect makes the host a recipient of the same `.age`. A naive
      # `lib.mkMerge` then sees two definitions of `age.secrets.registry-password`
      # and conflicts (down to path-vs-string of an otherwise-identical
      # rekeyFile). Deduplicate by secret name instead with a shallow merge:
      # equivalent broadcast emissions collapse to one, last definition wins.
      #
      # This requires every `age-secrets` emitter to return a plain
      # `{ age.secrets = <attrset>; }` (no `mkIf`/`mkMerge` wrappers, which a
      # shallow merge can't see through) — emitters express conditional/iterative
      # secret sets with `optionalAttrs`/`mergeAttrsList` instead.
      collect =
        lib: age-secrets:
        let
          merged = lib.mergeAttrsList (map (m: m.age.secrets or { }) age-secrets);
        in
        # Only touch `age.secrets` when there's at least one secret. A microvm
        # guest (e.g. cortex-cuda) gets this collector aspect but has no agenix
        # module, so its config has no `age` option — an unconditional
        # `age.secrets = {}` would fail to evaluate there. This matches the old
        # `lib.mkMerge []` no-op for hosts/guests with no secrets.
        lib.optionalAttrs (merged != { }) { age.secrets = merged; };
    in
    {
      nixos = { age-secrets, lib, ... }: collect lib age-secrets;
      darwin = { age-secrets, lib, ... }: collect lib age-secrets;
    };
}
