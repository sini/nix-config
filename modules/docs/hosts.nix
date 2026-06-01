{ dag, ... }:
{
  flake.readme.hosts =
    dag.entryBetween [ "den" ] [ "header" ]
      # markdown
      ''
        ## Hosts

        | Name                                  | Description                                                                                             |    Type     |      Arch      |
        | :------------------------------------ | :------------------------------------------------------------------------------------------------------ | :---------: | :------------: |
        | [uplink](modules/den/hosts/uplink.nix)       | Ryzen 5950X (16/32) - 128GB - 10gbe - Intel Arc A310 - AV1 Transcoding / Router / k8s control           |   Server    |  x86_64-linux  |
        | [axon-01](modules/den/hosts/axon-01.nix)     | MINISFORUM Venus UM790 Pro - Ryzen 9 7940HS (8/16) - 64GB - 2.5gbe - Radeon 780M - k8s node             |   Server    |  x86_64-linux  |
        | [axon-02](modules/den/hosts/axon-02.nix)     | MINISFORUM Venus UM790 Pro - Ryzen 9 7940HS (8/16) - 64GB - 2.5gbe - Radeon 780M - k8s node             |   Server    |  x86_64-linux  |
        | [axon-03](modules/den/hosts/axon-03.nix)     | MINISFORUM Venus UM790 Pro - Ryzen 9 7940HS (8/16) - 64GB - 2.5gbe - Radeon 780M - k8s node             |   Server    |  x86_64-linux  |
        | [bitstream](modules/den/hosts/bitstream.nix) | GMKtec M6 - Ryzen 5 6600H (8/16) - 64GB - 2.5gbe - Radeon 660M - k8s node                               |   Server    |  x86_64-linux  |
        | [cortex](modules/den/hosts/cortex.nix)       | Ryzen 9950X3D (16/32) - 128GB - 10gbe - 7900XTX + 3090TI - Hybrid ML Server/Workstation/VFIO Gaming Rig | Workstation |  x86_64-linux  |
        | [blade](modules/den/hosts/blade.nix)         | Razer Blade 16 (2023) - NixOS - 32GB ram - RTX 4090 (mobile)                                            |   Laptop    |  x86_64-linux  |
        | [patch](modules/den/hosts/patch.nix)         | M1 Macbook Air - 16gb / 1tb - macOS Sequoia 15.2                                                        |   Laptop    | aarch64-darwin |

      '';
}
