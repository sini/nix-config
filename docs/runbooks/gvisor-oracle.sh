#!/usr/bin/env bash
# Pre-deploy oracle for the gVisor runtime (docs/runbooks/gvisor.md).
#   1. axon-01's containerd has the runsc handler (shim on PATH, node labelled
#      node.kubernetes.io/gvisor=true) and axon-02's has none of the three.
#   2. The rendered prod-axon env has RuntimeClass `gvisor`, handler `runsc`.
# Exit 0 = both hold, 1 = a property failed, 2 = could not measure (eval/build
# error). One host per eval, each capped at 12G.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2

cap() { timeout 900 systemd-run --user --scope -q -p MemoryMax=12G -p MemorySwapMax=0 "$@"; }
fail=0

probe='c:
  let
    rt = c.virtualisation.containerd.settings.plugins."io.containerd.cri.v1.runtime".containerd.runtimes;
  in
  [
    ((rt.runsc or { }).runtime_type or null == "io.containerd.runsc.v1")
    (builtins.any (p: (p.pname or "") == "gvisor") c.systemd.services.containerd.path)
    (builtins.match ".*--node-label=node.kubernetes.io/gvisor=true.*" c.services.k3s.extraFlags != null)
  ]'

for spec in axon-01:true axon-02:false; do
  host=${spec%%:*} want=${spec#*:}
  if ! got=$(cap nix eval --json ".#nixosConfigurations.${host}.config" --apply "$probe"); then
    echo "UNMEASURED ${host}: nix eval failed" >&2
    exit 2
  fi
  if [ "$got" = "[$want,$want,$want]" ]; then
    echo "PASS ${host}: [runsc handler, gvisor on containerd PATH, gvisor label] = ${got}"
  else
    echo "FAIL ${host}: [runsc handler, gvisor on containerd PATH, gvisor label] = ${got}, want all ${want}"
    fail=1
  fi
done

if ! env=$(cap nix build --no-link --print-out-paths ".#nixidyEnvs.x86_64-linux.axon.environmentPackage"); then
  echo "UNMEASURED manifests: nixidy env build failed" >&2
  exit 2
fi
rc="$env/gvisor/RuntimeClass-gvisor.yaml"
if [ -f "$rc" ] && grep -qx 'kind: RuntimeClass' "$rc" && grep -qx '  name: gvisor' "$rc" && grep -qx 'handler: runsc' "$rc"; then
  echo "PASS manifests: ${rc#"$env"/} is RuntimeClass gvisor, handler runsc"
else
  echo "FAIL manifests: no RuntimeClass gvisor with handler runsc at ${rc#"$env"/}"
  fail=1
fi

exit "$fail"
