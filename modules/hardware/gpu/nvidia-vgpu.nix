{ }
# {
# VGPU support for NVIDIA GPUs -- limited to 2000 series and older
# ref:
# looking glass: https://gist.github.com/j-brn/716a03822d256bc5bf5d77b951c7915c
# https://github.com/mrzenc/vgpu4nixos
# https://github.com/VGPU-Community-Drivers/vGPU-Unlock-patcher
# https://github.com/ultrahiroo/nixos-config/blob/main/host/main/vgpu/default.nix
# https://github.com/tomasharkema/nix-config/blob/main/modules/nixos/traits/hardware/nvidia/default.nix
# https://github.com/cyrilschreiber3/nixconfig/blob/master/modules/nixos/vgpu.nix
# https://github.com/MakiseKurisu/nixos-config/blob/main/modules/nvidia-vgpu.nix
# https://github.com/Dyllan2000alfa/nixos-config/blob/main/modules/graphics/nvidia-vgpu.nix
# https://github.com/icewind1991/nvidia-patch-nixos/

#   flake.modules.nixos.gpu-nvidia-vgpu =
#     {
#       inputs,
#       ...
#     }:
#     {
#       #     vgpu4nixos.url = "github:mrzenc/vgpu4nixos";

#       imports = [
#         inputs.vgpu4nixos.nixosModules.host # Use nixosModules.guest for VMs
#       ]

#       hardware.nvidia.vgpu.patcher.enable = true;
#       hardware.nvidia.vgpu.patcher.copyVGPUProfiles = {
#         "2187:0000" = "1E30:12BA";
#       };
#     };
# }
