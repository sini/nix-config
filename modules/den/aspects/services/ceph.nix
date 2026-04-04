# Ceph storage for k8s/rook-ceph.
#
# NOTE: Currently a stub — the original feature only had empty persist dirs.
{ den, ... }:
{
  den.aspects.ceph = den.lib.perHost {
    nixos = { };
  };
}
