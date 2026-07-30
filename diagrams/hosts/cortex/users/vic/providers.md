# Provider Tree: vic

![Providers](./providers.mmd.svg)

```mermaid
%%{init: {"elk":{"mergeEdges":true,"nodePlacementStrategy":"BRANDES_KOEPF"},"flowchart":{"wrappingWidth":600},"layout":"elk","theme":"base","themeVariables":{"activationBkgColor":"#313244","activationBorderColor":"#6c7086","actorBkg":"#313244","actorBorder":"#a6adc8","actorLineColor":"#a6adc8","actorTextColor":"#cdd6f4","background":"#1e1e2e","classText":"#cdd6f4","clusterBkg":"#313244","clusterBorder":"#6c7086","edgeLabelBackground":"#1e1e2e","labelBoxBkgColor":"#313244","labelBoxBorderColor":"#a6adc8","labelTextColor":"#cdd6f4","lineColor":"#a6adc8","loopTextColor":"#cdd6f4","mainBkg":"#313244","nodeBkg":"#313244","nodeBorder":"#a6adc8","nodeTextColor":"#cdd6f4","noteBkgColor":"#313244","noteBorderColor":"#6c7086","noteTextColor":"#cdd6f4","pie1":"#f38ba8","pie2":"#fab387","pie3":"#f9e2af","pie4":"#a6e3a1","pie5":"#94e2d5","pie6":"#89b4fa","pie7":"#cba6f7","pie8":"#f2cdcd","pieLegendTextColor":"#cdd6f4","pieOuterStrokeColor":"#6c7086","pieSectionTextColor":"#cdd6f4","pieStrokeColor":"#6c7086","pieTitleTextColor":"#cdd6f4","primaryBorderColor":"#a6adc8","primaryColor":"#313244","primaryTextColor":"#cdd6f4","secondBkg":"#313244","secondaryBorderColor":"#6c7086","secondaryColor":"#313244","secondaryTextColor":"#cdd6f4","sequenceNumberColor":"#1e1e2e","signalColor":"#a6adc8","signalTextColor":"#cdd6f4","tertiaryBorderColor":"#6c7086","tertiaryColor":"#313244","tertiaryTextColor":"#cdd6f4","textColor":"#cdd6f4","titleColor":"#cdd6f4"}}}%%
graph TD
  vic([vic]):::root
  secrets__agenix[/"secrets/agenix · user"\]:::secrets__agenix_c
  core__systemd__boot[/"systemd/boot · user"\]:::core__systemd__boot_c
  core__impermanence__btrfs[/"impermanence/btrfs · user"\]:::core__impermanence__btrfs_c
  core["core"]:::core_c
  roles__default[/"roles/default · user"\]:::roles__default_c
  core__users__deterministic_uids[/"users/deterministic-uids · user"\]:::core__users__deterministic_uids_c
  core__users__home_manager_shared[/"users/home-manager-shared · user"\]:::core__users__home_manager_shared_c
  core__impermanence[/"core/impermanence · user"\]:::core__impermanence_c
  core__nix[/"core/nix · user"\]:::core__nix_c
  core__nix__nixpkgs[/"nix/nixpkgs · user"\]:::core__nix__nixpkgs_c
  core__security__openssh[/"security/openssh · user"\]:::core__security__openssh_c
  core__security__opkssh[/"security/opkssh · user"\]:::core__security__opkssh_c
  core__impermanence__persist_collector[/"impermanence/persist-collector · user"\]:::core__impermanence__persist_collector_c
  core__impermanence__persist_home_collector[/"impermanence/persist-home-collector · user"\]:::core__impermanence__persist_home_collector_c
  roles["roles"]:::roles_c
  secrets["secrets"]:::secrets_c
  core__security[/"core/security · user"\]:::core__security_c
  core__users__shell[/"users/shell · user"\]:::core__users__shell_c
  core__nix__stateVersion[/"nix/stateVersion · user"\]:::core__nix__stateVersion_c
  core__security__sudo[/"security/sudo · user"\]:::core__security__sudo_c
  core__systemd[/"core/systemd · user"\]:::core__systemd_c
  core__users[/"core/users · user"\]:::core__users_c
  core__utils[/"core/utils · user"\]:::core__utils_c
  core__impermanence__zfs[/"impermanence/zfs · user"\]:::core__impermanence__zfs_c

  secrets --> secrets__agenix
  core__systemd --> core__systemd__boot
  core__impermanence --> core__impermanence__btrfs
  roles --> roles__default
  core__users --> core__users__deterministic_uids
  core__users --> core__users__home_manager_shared
  core --> core__impermanence
  core --> core__nix
  core__nix --> core__nix__nixpkgs
  core__security --> core__security__openssh
  core__security --> core__security__opkssh
  core__impermanence --> core__impermanence__persist_collector
  core__impermanence --> core__impermanence__persist_home_collector
  core --> core__security
  core__users --> core__users__shell
  core__nix --> core__nix__stateVersion
  core__security --> core__security__sudo
  core --> core__systemd
  core --> core__users
  core --> core__utils
  core__impermanence --> core__impermanence__zfs

  classDef root fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,font-weight:bold
  classDef secrets__agenix_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__systemd__boot_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence__btrfs_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:3px
  classDef core_c fill:#f9e2af,stroke:#f9e2af,color:#1e1e2e,stroke-dasharray: 3 3,stroke-width:1px
  classDef roles__default_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__users__deterministic_uids_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:3px
  classDef core__users__home_manager_shared_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__nix_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__nix__nixpkgs_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__security__openssh_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__security__opkssh_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence__persist_collector_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence__persist_home_collector_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:3px
  classDef roles_c fill:#a6e3a1,stroke:#a6e3a1,color:#1e1e2e,stroke-dasharray: 3 3,stroke-width:1px
  classDef secrets_c fill:#f9e2af,stroke:#f9e2af,color:#1e1e2e,stroke-dasharray: 3 3,stroke-width:1px
  classDef core__security_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__users__shell_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__nix__stateVersion_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__security__sudo_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__systemd_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__users_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__utils_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence__zfs_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
```
