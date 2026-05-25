# Provider Tree: patch

![Providers](./providers.mmd.svg)

```mermaid
%%{init: {"elk":{"mergeEdges":true,"nodePlacementStrategy":"BRANDES_KOEPF"},"flowchart":{"wrappingWidth":600},"layout":"elk","theme":"base","themeVariables":{"activationBkgColor":"#313244","activationBorderColor":"#6c7086","actorBkg":"#313244","actorBorder":"#a6adc8","actorLineColor":"#a6adc8","actorTextColor":"#cdd6f4","background":"#1e1e2e","classText":"#cdd6f4","clusterBkg":"#313244","clusterBorder":"#6c7086","edgeLabelBackground":"#1e1e2e","labelBoxBkgColor":"#313244","labelBoxBorderColor":"#a6adc8","labelTextColor":"#cdd6f4","lineColor":"#a6adc8","loopTextColor":"#cdd6f4","mainBkg":"#313244","nodeBkg":"#313244","nodeBorder":"#a6adc8","nodeTextColor":"#cdd6f4","noteBkgColor":"#313244","noteBorderColor":"#6c7086","noteTextColor":"#cdd6f4","pie1":"#f38ba8","pie2":"#fab387","pie3":"#f9e2af","pie4":"#a6e3a1","pie5":"#94e2d5","pie6":"#89b4fa","pie7":"#cba6f7","pie8":"#f2cdcd","pieLegendTextColor":"#cdd6f4","pieOuterStrokeColor":"#6c7086","pieSectionTextColor":"#cdd6f4","pieStrokeColor":"#6c7086","pieTitleTextColor":"#cdd6f4","primaryBorderColor":"#a6adc8","primaryColor":"#313244","primaryTextColor":"#cdd6f4","secondBkg":"#313244","secondaryBorderColor":"#6c7086","secondaryColor":"#313244","secondaryTextColor":"#cdd6f4","sequenceNumberColor":"#1e1e2e","signalColor":"#a6adc8","signalTextColor":"#cdd6f4","tertiaryBorderColor":"#6c7086","tertiaryColor":"#313244","tertiaryTextColor":"#cdd6f4","textColor":"#cdd6f4","titleColor":"#cdd6f4"}}}%%
graph TD
  patch([patch]):::root
  hardware__adb[/"hardware/adb · host"\]:::hardware__adb_c
  apps["apps"]:::apps_c
  apps__bat[/"apps/bat · host"\]:::apps__bat_c
  apps__claude[/"apps/claude · host"\]:::apps__claude_c
  core["core"]:::core_c
  core__default[/"core/default · host"\]:::core__default_c
  core__deterministic_uids[/"core/deterministic-uids · host"\]:::core__deterministic_uids_c
  roles__dev[/"roles/dev · host"\]:::roles__dev_c
  apps__direnv[/"apps/direnv · host"\]:::apps__direnv_c
  apps__eza[/"apps/eza · host"\]:::apps__eza_c
  core__facter[/"core/facter · host"\]:::core__facter_c
  core__firewall_collector[/"core/firewall-collector · host"\]:::core__firewall_collector_c
  core__firmware[/"core/firmware · host"\]:::core__firmware_c
  apps__git[/"apps/git · host"\]:::apps__git_c
  apps__gpg[/"apps/gpg · host"\]:::apps__gpg_c
  hardware["hardware"]:::hardware_c
  core__home_manager[/"core/home-manager · host"\]:::core__home_manager_c
  network__hosts[/"network/hosts · host"\]:::network__hosts_c
  core__i18n[/"core/i18n · host"\]:::core__i18n_c
  apps__k9s[/"apps/k9s · host"\]:::apps__k9s_c
  core__linux_kernel[/"core/linux-kernel · host"\]:::core__linux_kernel_c
  core__lix[/"core/lix · host"\]:::core__lix_c
  apps__misc_tools[/"apps/misc-tools · host"\]:::apps__misc_tools_c
  network["network"]:::network_c
  network__networking[/"network/networking · host"\]:::network__networking_c
  core__nix[/"core/nix · host"\]:::core__nix_c
  apps__nix_index[/"apps/nix-index · host"\]:::apps__nix_index_c
  core__nix_remote_build_client[/"core/nix-remote-build-client · host"\]:::core__nix_remote_build_client_c
  core__nixpkgs[/"core/nixpkgs · host"\]:::core__nixpkgs_c
  apps__nvf[/"apps/nvf · host"\]:::apps__nvf_c
  network__openssh[/"network/openssh · host"\]:::network__openssh_c
  apps__python[/"apps/python · host"\]:::apps__python_c
  roles["roles"]:::roles_c
  core__secrets_collector[/"core/secrets-collector · host"\]:::core__secrets_collector_c
  core__security[/"core/security · host"\]:::core__security_c
  services["services"]:::services_c
  core__shell[/"core/shell · host"\]:::core__shell_c
  core__ssd[/"core/ssd · host"\]:::core__ssd_c
  apps__ssh[/"apps/ssh · host"\]:::apps__ssh_c
  apps__starship[/"apps/starship · host"\]:::apps__starship_c
  core__stateVersion[/"core/stateVersion · host"\]:::core__stateVersion_c
  core__sudo[/"core/sudo · host"\]:::core__sudo_c
  apps__sysmon[/"apps/sysmon · host"\]:::apps__sysmon_c
  core__systemd[/"core/systemd · host"\]:::core__systemd_c
  core__systemd_boot[/"core/systemd-boot · host"\]:::core__systemd_boot_c
  services__tailscale[/"services/tailscale · host"\]:::services__tailscale_c
  core__time[/"core/time · host"\]:::core__time_c
  core__users[/"core/users · host"\]:::core__users_c
  core__utils[/"core/utils · host"\]:::core__utils_c
  apps__yazi[/"apps/yazi · host"\]:::apps__yazi_c
  apps__zoxide[/"apps/zoxide · host"\]:::apps__zoxide_c
  apps__zsh[/"apps/zsh · host"\]:::apps__zsh_c

  hardware --> hardware__adb
  apps --> apps__bat
  apps --> apps__claude
  core --> core__default
  core --> core__deterministic_uids
  roles --> roles__dev
  apps --> apps__direnv
  apps --> apps__eza
  core --> core__facter
  core --> core__firewall_collector
  core --> core__firmware
  apps --> apps__git
  apps --> apps__gpg
  core --> core__home_manager
  network --> network__hosts
  core --> core__i18n
  apps --> apps__k9s
  core --> core__linux_kernel
  core --> core__lix
  apps --> apps__misc_tools
  network --> network__networking
  core --> core__nix
  apps --> apps__nix_index
  core --> core__nix_remote_build_client
  core --> core__nixpkgs
  apps --> apps__nvf
  network --> network__openssh
  apps --> apps__python
  core --> core__secrets_collector
  core --> core__security
  core --> core__shell
  core --> core__ssd
  apps --> apps__ssh
  apps --> apps__starship
  core --> core__stateVersion
  core --> core__sudo
  apps --> apps__sysmon
  core --> core__systemd
  core --> core__systemd_boot
  services --> services__tailscale
  core --> core__time
  core --> core__users
  core --> core__utils
  apps --> apps__yazi
  apps --> apps__zoxide
  apps --> apps__zsh

  classDef root fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,font-weight:bold
  classDef hardware__adb_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef apps_c fill:#a6e3a1,stroke:#a6e3a1,color:#1e1e2e,stroke-dasharray: 3 3,stroke-width:1px
  classDef apps__bat_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef apps__claude_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core_c fill:#f9e2af,stroke:#f9e2af,color:#1e1e2e,stroke-dasharray: 3 3,stroke-width:1px
  classDef core__default_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__deterministic_uids_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef roles__dev_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef apps__direnv_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef apps__eza_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef core__facter_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef core__firewall_collector_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:2px
  classDef core__firmware_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef apps__git_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef apps__gpg_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef hardware_c fill:#a6e3a1,stroke:#a6e3a1,color:#1e1e2e,stroke-dasharray: 3 3,stroke-width:1px
  classDef core__home_manager_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef network__hosts_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef core__i18n_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef apps__k9s_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__linux_kernel_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef core__lix_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef apps__misc_tools_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef network_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-dasharray: 3 3,stroke-width:1px
  classDef network__networking_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef core__nix_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef apps__nix_index_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__nix_remote_build_client_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__nixpkgs_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef apps__nvf_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef network__openssh_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef apps__python_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef roles_c fill:#a6e3a1,stroke:#a6e3a1,color:#1e1e2e,stroke-dasharray: 3 3,stroke-width:1px
  classDef core__secrets_collector_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:2px
  classDef core__security_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef services_c fill:#a6e3a1,stroke:#a6e3a1,color:#1e1e2e,stroke-dasharray: 3 3,stroke-width:1px
  classDef core__shell_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef core__ssd_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef apps__ssh_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef apps__starship_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef core__stateVersion_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef core__sudo_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef apps__sysmon_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef core__systemd_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef core__systemd_boot_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef services__tailscale_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef core__time_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef core__users_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef core__utils_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef apps__yazi_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef apps__zoxide_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef apps__zsh_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
```
