# llama.cpp server, Vulkan backend.
#
# Vulkan rather than ROCm deliberately: the axon nodes' Radeon 780M is gfx1103,
# which is NOT in the ROCm image's AMDGPU_TARGETS
# (gfx908;gfx90a;gfx942;gfx1030;gfx1100;gfx1101;gfx1102;gfx1151;gfx1150;gfx1200;gfx1201),
# so that path would need an HSA_OVERRIDE_GFX_VERSION masquerade as gfx1102.
# The Vulkan image carries mesa-vulkan-drivers (RADV) and talks to the same
# /dev/dri render node, with no support gap to work around.
#
# Rolling tag: `server-vulkan` has no versioned variants upstream. Unlike
# hindsight this holds no persistent state — the worst a digest bump can do is
# re-download the model — so it tracks rather than pinning.
{
  imageName = "ghcr.io/ggml-org/llama.cpp";
  imageTag = "server-vulkan";
  imageDigest = "sha256:be8d64a2a05b11ddaf5799c544b0d96f8d9a09fb065e8d117cafa7f03e533896";
  imageHash = "sha256-/wc0uLnkmNlmKI52S4KI8lOENRQ9VdxEwCUhKoO4rXw=";
  arch = "amd64";
  os = "linux";
  pinned = false;
}
