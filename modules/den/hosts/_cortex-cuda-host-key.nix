# cortex-cuda's own SSH host key (also its agenix identity): decrypted by
# cortex into hostKeyShare, mounted read-only in the guest at hostKeyDir.
{
  hostKeyShare = "/var/lib/microvms/cortex-cuda/host-key";
  hostKeyDir = "/etc/ssh/host-key";
}
