{
  text.readme.parts.hosts =
    # markdown
    ''
      ## Hosts

      | Name                                  | Description                                                                                             |    Type     |      Arch      |
      | :------------------------------------ | :------------------------------------------------------------------------------------------------------ | :---------: | :------------: |
      | [uplink](modules/hosts/uplink/)       | Ryzen 5950X (16/32) - 128GB - 10gbe - Intel Arc A310 - AV1 Transcoding / Router / k8s control           |   Server    |  x86_64-linux  |
      | [axon-01](modules/hosts/axon-01/)     | MINISFORUM Venus UM790 Pro - Ryzen 9 7940HS (8/16) - 64GB - 2.5gbe - Radeon 780M - k8s node             |   Server    |  x86_64-linux  |
      | [axon-02](modules/hosts/axon-02/)     | MINISFORUM Venus UM790 Pro - Ryzen 9 7940HS (8/16) - 64GB - 2.5gbe - Radeon 780M - k8s node             |   Server    |  x86_64-linux  |
      | [axon-03](modules/hosts/axon-03/)     | MINISFORUM Venus UM790 Pro - Ryzen 9 7940HS (8/16) - 64GB - 2.5gbe - Radeon 780M - k8s node             |   Server    |  x86_64-linux  |
      | [bitstream](modules/hosts/bitstream/) | GMKtec M6 - Ryzen 5 6600H (8/16) - 64GB - 2.5gbe - Radeon 660M - k8s node                               |   Server    |  x86_64-linux  |
      | [cortex](modules/hosts/cortex/)       | Ryzen 9950X3D (16/32) - 128GB - 10gbe - 7900XTX + 3090TI - Hybrid ML Server/Workstation/VFIO Gaming Rig | Workstation |  x86_64-linux  |
      | [spike](modules/hosts/spike/)         | Razer Blade 16 (2023) - NixOS - 32GB ram - RTX 4090 (mobile)                                            |   Laptop    |  x86_64-linux  |
      | [patch](modules/hosts/patch/)         | M1 Macbook Air - 16gb / 1tb - macOS Sequoia 15.2                                                        |   Laptop    | aarch64-darwin |
      | [vault](modules/hosts/vault/)         | 1tb NVME + 80tb NFS - 2x1gbe + 2.5gbe                                                                   |     NAS     |  x86_64-linux  |

    '';
}
