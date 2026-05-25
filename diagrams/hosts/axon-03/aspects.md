# Aspect Hierarchy: axon-03

![Aspect hierarchy](./aspects.mmd.svg)

```mermaid
%%{init: {"elk":{"mergeEdges":true,"nodePlacementStrategy":"BRANDES_KOEPF"},"flowchart":{"wrappingWidth":600},"layout":"elk","theme":"base","themeVariables":{"activationBkgColor":"#d0d7de","activationBorderColor":"#8c959f","actorBkg":"#d0d7de","actorBorder":"#6e7781","actorLineColor":"#6e7781","actorTextColor":"#424a53","background":"#eaeef2","classText":"#424a53","clusterBkg":"#d0d7de","clusterBorder":"#8c959f","edgeLabelBackground":"#eaeef2","labelBoxBkgColor":"#d0d7de","labelBoxBorderColor":"#6e7781","labelTextColor":"#424a53","lineColor":"#6e7781","loopTextColor":"#424a53","mainBkg":"#d0d7de","nodeBkg":"#d0d7de","nodeBorder":"#6e7781","nodeTextColor":"#424a53","noteBkgColor":"#d0d7de","noteBorderColor":"#8c959f","noteTextColor":"#424a53","pie1":"#fa4549","pie2":"#e16f24","pie3":"#bf8700","pie4":"#2da44e","pie5":"#339D9B","pie6":"#218bff","pie7":"#a475f9","pie8":"#4d2d00","pieLegendTextColor":"#424a53","pieOuterStrokeColor":"#8c959f","pieSectionTextColor":"#424a53","pieStrokeColor":"#8c959f","pieTitleTextColor":"#424a53","primaryBorderColor":"#6e7781","primaryColor":"#d0d7de","primaryTextColor":"#424a53","secondBkg":"#d0d7de","secondaryBorderColor":"#8c959f","secondaryColor":"#d0d7de","secondaryTextColor":"#424a53","sequenceNumberColor":"#eaeef2","signalColor":"#6e7781","signalTextColor":"#424a53","tertiaryBorderColor":"#8c959f","tertiaryColor":"#d0d7de","tertiaryTextColor":"#424a53","textColor":"#424a53","titleColor":"#424a53"}}}%%
graph LR
  axon_03([axon-03]):::root

  subgraph ctx_host_axon_03["host: axon-03"]
  services__acme[/"services/acme"\]:::services__acme_c
  secrets__agenix[/"secrets/agenix"\]:::secrets__agenix_c
  services__bgp[/"services/bgp"\]:::services__bgp_c
  services__cilium_bgp[/"services/cilium-bgp"\]:::services__cilium_bgp_c
  collect_bgp_peers["collect-bgp-peers"]:::collect_bgp_peers_c
  collect_host_addrs["collect-host-addrs"]:::collect_host_addrs_c
  collect_k3s_nodes["collect-k3s-nodes"]:::collect_k3s_nodes_c
  collect_ollama_endpoints["collect-ollama-endpoints"]:::collect_ollama_endpoints_c
  collect_prometheus_targets["collect-prometheus-targets"]:::collect_prometheus_targets_c
  collect_thunderbolt_mesh_peers["collect-thunderbolt-mesh-peers"]:::collect_thunderbolt_mesh_peers_c
  collect_vault_peers["collect-vault-peers"]:::collect_vault_peers_c
  hardware__cpu_amd[/"hardware/cpu-amd"\]:::hardware__cpu_amd_c
  core__default[/"core/default"\]:::core__default_c
  den__batteries__define_user[/"batteries/define-user"\]:::den__batteries__define_user_c
  core__deterministic_uids[/"core/deterministic-uids"\]:::core__deterministic_uids_c
  core__facter[/"core/facter"\]:::core__facter_c
  core__firewall_collector[/"core/firewall-collector"\]:::core__firewall_collector_c
  core__firmware[/"core/firmware"\]:::core__firmware_c
  hardware__gpu_amd[/"hardware/gpu-amd"\]:::hardware__gpu_amd_c
  core__home_manager[/"core/home-manager"\]:::core__home_manager_c
  den__batteries__hostname[/"batteries/hostname"\]:::den__batteries__hostname_c
  den__batteries__hostname__os{{"batteries/hostname/os"}}:::den__batteries__hostname__os_c
  network__hosts[/"network/hosts"\]:::network__hosts_c
  core__i18n[/"core/i18n"\]:::core__i18n_c
  disk__impermanence[/"disk/impermanence"\]:::disk__impermanence_c
  insecure_predicate["insecure-predicate"]:::insecure_predicate_c
  insecure_predicate__os{{"insecure-predicate/os"}}:::insecure_predicate__os_c
  services__k3s[/"services/k3s"\]:::services__k3s_c
  services__k3s_containerd[/"services/k3s-containerd"\]:::services__k3s_containerd_c
  core__linux_kernel[/"core/linux-kernel"\]:::core__linux_kernel_c
  core__lix[/"core/lix"\]:::core__lix_c
  services__media_data_share[/"services/media-data-share"\]:::services__media_data_share_c
  network__network_boot[/"network/network-boot"\]:::network__network_boot_c
  network__networking[/"network/networking"\]:::network__networking_c
  core__nix[/"core/nix"\]:::core__nix_c
  roles__nix_builder[/"roles/nix-builder"\]:::roles__nix_builder_c
  core__nix_remote_build_client[/"core/nix-remote-build-client"\]:::core__nix_remote_build_client_c
  services__nix_remote_build_server[/"services/nix-remote-build-server"\]:::services__nix_remote_build_server_c
  core__nixpkgs[/"core/nixpkgs"\]:::core__nixpkgs_c
  network__openssh[/"network/openssh"\]:::network__openssh_c
  os_to_host["os-to-host"]:::os_to_host_c
  core__persist_collector[/"core/persist-collector"\]:::core__persist_collector_c
  core__persist_home_collector[/"core/persist-home-collector"\]:::core__persist_home_collector_c
  den__batteries__primary_user[/"batteries/primary-user"\]:::den__batteries__primary_user_c
  services__prometheus_exporter[/"services/prometheus-exporter"\]:::services__prometheus_exporter_c
  disk__zfs_disk_single__root[/"zfs-disk-single/root"\]:::disk__zfs_disk_single__root_c
  core__secrets_collector[/"core/secrets-collector"\]:::core__secrets_collector_c
  core__security[/"core/security"\]:::core__security_c
  roles__server[/"roles/server"\]:::roles__server_c
  core__shell[/"core/shell"\]:::core__shell_c
  services__bgp__spoke[/"bgp/spoke"\]:::services__bgp__spoke_c
  core__ssd[/"core/ssd"\]:::core__ssd_c
  core__stateVersion[/"core/stateVersion"\]:::core__stateVersion_c
  core__sudo[/"core/sudo"\]:::core__sudo_c
  core__systemd[/"core/systemd"\]:::core__systemd_c
  core__systemd_boot[/"core/systemd-boot"\]:::core__systemd_boot_c
  services__tailscale[/"services/tailscale"\]:::services__tailscale_c
  services__tang[/"services/tang"\]:::services__tang_c
  services__thunderbolt_mesh_of[/"services/thunderbolt-mesh-of"\]:::services__thunderbolt_mesh_of_c
  hardware__thunderbolt_network[/"hardware/thunderbolt-network"\]:::hardware__thunderbolt_network_c
  core__time[/"core/time"\]:::core__time_c
  unfree_predicate["unfree-predicate"]:::unfree_predicate_c
  unfree_predicate__os{{"unfree-predicate/os"}}:::unfree_predicate__os_c
  roles__unlock[/"roles/unlock"\]:::roles__unlock_c
  core__users[/"core/users"\]:::core__users_c
  core__utils[/"core/utils"\]:::core__utils_c
  disk__xfs_disk_longhorn[/"disk/xfs-disk-longhorn"\]:::disk__xfs_disk_longhorn_c
  disk__zfs_diff[/"disk/zfs-diff"\]:::disk__zfs_diff_c
  disk__zfs_disk_single[/"disk/zfs-disk-single"\]:::disk__zfs_disk_single_c
  apps__zsh[/"apps/zsh"\]:::apps__zsh_c
  axon_03 --> secrets__agenix
  axon_03 --> services__cilium_bgp
  axon_03 --> hardware__cpu_amd
  axon_03 --> core__default
  axon_03 --> hardware__gpu_amd
  axon_03 --> disk__impermanence
  axon_03 --> services__k3s
  axon_03 --> network__network_boot
  axon_03 --> roles__nix_builder
  axon_03 --> roles__server
  axon_03 --> services__bgp__spoke
  axon_03 --> services__thunderbolt_mesh_of
  axon_03 --> roles__unlock
  axon_03 --> disk__xfs_disk_longhorn
  axon_03 --> disk__zfs_disk_single
  core__default --> core__deterministic_uids
  core__default --> core__facter
  core__default --> core__firmware
  core__default --> core__home_manager
  core__default --> network__hosts
  core__default --> core__i18n
  core__default --> core__linux_kernel
  core__default --> core__lix
  core__default --> network__networking
  core__default --> core__nix
  core__default --> core__nix_remote_build_client
  core__default --> core__nixpkgs
  core__default --> network__openssh
  core__default --> core__security
  core__default --> core__shell
  core__default --> core__ssd
  core__default --> core__stateVersion
  core__default --> core__sudo
  core__default --> core__systemd
  core__default --> core__systemd_boot
  core__default --> services__tailscale
  core__default --> core__time
  core__default --> core__users
  core__default --> core__utils
  core__default --> apps__zsh
  den__batteries__hostname --> den__batteries__hostname__os
  disk__impermanence --> core__persist_collector
  disk__impermanence --> core__persist_home_collector
  disk__zfs_disk_single --> disk__zfs_disk_single__root
  disk__zfs_disk_single__root --> disk__zfs_diff
  insecure_predicate --> insecure_predicate__os
  roles__nix_builder --> services__nix_remote_build_server
  roles__server --> services__acme
  roles__server --> services__media_data_share
  roles__server --> services__prometheus_exporter
  roles__server --> services__tang
  services__bgp__spoke --> services__bgp
  services__k3s --> services__k3s_containerd
  services__thunderbolt_mesh_of --> hardware__thunderbolt_network
  unfree_predicate --> unfree_predicate__os
  end


  classDef root fill:#218bff,stroke:#218bff,color:#1f2328,font-weight:bold
  classDef services__acme_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef secrets__agenix_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef apps_c fill:#2da44e,stroke:#2da44e,color:#1f2328,stroke-dasharray: 3 3,stroke-width:1px
  classDef axon_03_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef services__bgp_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef services__cilium_bgp_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef collect_bgp_peers_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:2px,stroke-dasharray: 8 4
  classDef collect_host_addrs_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:2px,stroke-dasharray: 8 4
  classDef collect_k3s_nodes_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:2px,stroke-dasharray: 8 4
  classDef collect_ollama_endpoints_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:2px,stroke-dasharray: 8 4
  classDef collect_prometheus_targets_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:2px,stroke-dasharray: 8 4
  classDef collect_thunderbolt_mesh_peers_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:2px,stroke-dasharray: 8 4
  classDef collect_vault_peers_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:2px,stroke-dasharray: 8 4
  classDef core_c fill:#bf8700,stroke:#bf8700,color:#1f2328,stroke-dasharray: 3 3,stroke-width:1px
  classDef hardware__cpu_amd_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef core__default_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef den__batteries__define_user_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef core__deterministic_uids_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef disk_c fill:#2da44e,stroke:#2da44e,color:#1f2328,stroke-dasharray: 3 3,stroke-width:1px
  classDef core__facter_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef core__firewall_collector_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:2px
  classDef core__firmware_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef hardware__gpu_amd_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef hardware_c fill:#2da44e,stroke:#2da44e,color:#1f2328,stroke-dasharray: 3 3,stroke-width:1px
  classDef core__home_manager_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef den__batteries__hostname_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef den__batteries__hostname__os_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:2px
  classDef network__hosts_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef core__i18n_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef disk__impermanence_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef insecure_predicate_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef insecure_predicate__os_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:2px
  classDef services__k3s_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef services__k3s_containerd_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef core__linux_kernel_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef core__lix_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef services__media_data_share_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef network_c fill:#e16f24,stroke:#e16f24,color:#1f2328,stroke-dasharray: 3 3,stroke-width:1px
  classDef network__network_boot_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef network__networking_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef core__nix_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef roles__nix_builder_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef core__nix_remote_build_client_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef services__nix_remote_build_server_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef core__nixpkgs_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef network__openssh_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef os_to_host_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:2px,stroke-dasharray: 8 4
  classDef core__persist_collector_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef core__persist_home_collector_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef den__batteries__primary_user_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-dasharray: 3 3,stroke-width:1px
  classDef services__prometheus_exporter_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef roles_c fill:#2da44e,stroke:#2da44e,color:#1f2328,stroke-dasharray: 3 3,stroke-width:1px
  classDef disk__zfs_disk_single__root_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef secrets_c fill:#bf8700,stroke:#bf8700,color:#1f2328,stroke-dasharray: 3 3,stroke-width:1px
  classDef core__secrets_collector_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:2px
  classDef core__security_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef roles__server_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef services_c fill:#2da44e,stroke:#2da44e,color:#1f2328,stroke-dasharray: 3 3,stroke-width:1px
  classDef core__shell_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef services__bgp__spoke_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef core__ssd_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef core__stateVersion_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef core__sudo_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef core__systemd_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef core__systemd_boot_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef services__tailscale_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef services__tang_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef services__thunderbolt_mesh_of_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef hardware__thunderbolt_network_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef core__time_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef unfree_predicate_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef unfree_predicate__os_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:2px
  classDef roles__unlock_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef core__users_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef core__utils_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef disk__xfs_disk_longhorn_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef disk__zfs_diff_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef disk__zfs_disk_single_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef apps__zsh_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
style ctx_host_axon_03 fill:#d0d7de,stroke:#8c959f,stroke-width:2px
```
