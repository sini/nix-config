| Name                                   | Description                                                                                          |    Type     |      Arch      |
| :------------------------------------- | :--------------------------------------------------------------------------------------------------- | :---------: | :------------: |
| [uplink](x86_64-linux/uplink/)         | Ryzen 3900X (12/24) - 64GB - 2x10gbe - Intel Arc A310 - AV1 Transcoding / Router / k8s control       |   Server    |  x86_64-linux  |
| [surge](x86_64-linux/surge/)           | GMKtec M6 - Ryzen 5 6600H (8/16) - 64GB - 2.5gbe - Radeon 660M - k8s node                            |   Server    |  x86_64-linux  |
| [burst](x86_64-linux/burst/)           | MINISFORUM Venus UM790 Pro - Ryzen 9 7940HS (8/16) - 64GB - 2.5gbe - Radeon 780M - k8s node          |   Server    |  x86_64-linux  |
| [pulse](x86_64-linux/pulse/)           | MINISFORUM Venus UM790 Pro - Ryzen 9 7940HS (8/16) - 64GB - 2.5gbe - Radeon 780M - k8s node          |   Server    |  x86_64-linux  |
| [cortex](x86_64-linux/cortex/)         | Ryzen 5950X (16/32) - 128GB - 10gbe - 3090TI + 2080TI - Hybrid ML Server/Workstation/VFIO Gaming Rig | Workstation |  x86_64-linux  |
| [cortex-wsl](x86_64-linux/cortex-wsl/) | Windows VFIO/Qemu instance of the above - WSL                                                        |     VM      |  x86_64-linux  |
| [patch](aarch64-darwin/patch/)         | M1 Macbook Air - 16gb / 1tb - macOS Sequoia 15.2                                                     |   Laptop    | aarch64-darwin |
| [rig](aarch64-linux/rig/)              | Dual boot of above to Asahi NixOS                                                                    |   Laptop    | aarch64-linux  |
| [spike](x86_64-linux/spike/)           | Razer Blade 16 (2023) - NixOS - 32GB ram - RTX 4090 (mobile)                                         |   Laptop    |  x86_64-linux  |
| [spike-wsl](x86_64-linux/spike-wsl/)   | WSL instance of above                                                                                |     VM      |  x86_64-linux  |
| [vault](x86_64-linux/vault/)           | 1tb NVME + 80tb NFS - 2x1gbe + 2.5gbe - TODO: https://github.com/adam-gaia/synology-nix-installer    |     NAS     |    Synology    |
| [loadout](x86_64-iso/loadout/)         | Custom live media, used as an installer/rescue                                                       |     ISO     |   x86_64-iso   |
| [cipher](x86_64-iso/cipher/)           | Air-gapped virtual machine/live-iso configuration for sensitive jobs                                 |     ISO     |   x86_64-iso   |
| [example](x86_64-linux/example/)       | Template                                                                                             |     ISO     |   x86_64-iso   |
