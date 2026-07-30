# Class Slice: nixos: axon-03

![nixos slice](./class-nixos.mmd.svg)

```mermaid
%%{init: {"elk":{"mergeEdges":true,"nodePlacementStrategy":"BRANDES_KOEPF"},"flowchart":{"wrappingWidth":600},"layout":"elk","theme":"base","themeVariables":{"activationBkgColor":"#313244","activationBorderColor":"#6c7086","actorBkg":"#313244","actorBorder":"#a6adc8","actorLineColor":"#a6adc8","actorTextColor":"#cdd6f4","background":"#1e1e2e","classText":"#cdd6f4","clusterBkg":"#313244","clusterBorder":"#6c7086","edgeLabelBackground":"#1e1e2e","labelBoxBkgColor":"#313244","labelBoxBorderColor":"#a6adc8","labelTextColor":"#cdd6f4","lineColor":"#a6adc8","loopTextColor":"#cdd6f4","mainBkg":"#313244","nodeBkg":"#313244","nodeBorder":"#a6adc8","nodeTextColor":"#cdd6f4","noteBkgColor":"#313244","noteBorderColor":"#6c7086","noteTextColor":"#cdd6f4","pie1":"#f38ba8","pie2":"#fab387","pie3":"#f9e2af","pie4":"#a6e3a1","pie5":"#94e2d5","pie6":"#89b4fa","pie7":"#cba6f7","pie8":"#f2cdcd","pieLegendTextColor":"#cdd6f4","pieOuterStrokeColor":"#6c7086","pieSectionTextColor":"#cdd6f4","pieStrokeColor":"#6c7086","pieTitleTextColor":"#cdd6f4","primaryBorderColor":"#a6adc8","primaryColor":"#313244","primaryTextColor":"#cdd6f4","secondBkg":"#313244","secondaryBorderColor":"#6c7086","secondaryColor":"#313244","secondaryTextColor":"#cdd6f4","sequenceNumberColor":"#1e1e2e","signalColor":"#a6adc8","signalTextColor":"#cdd6f4","tertiaryBorderColor":"#6c7086","tertiaryColor":"#313244","tertiaryTextColor":"#cdd6f4","textColor":"#cdd6f4","titleColor":"#cdd6f4"}}}%%
graph LR
  axon_03([axon-03]):::root

  subgraph ctx_user_sini["user: sini"]
  agenix_identity__sini_axon_01{{"agenix-identity/sini@axon-01"}}:::agenix_identity__sini_axon_01_c
  agenix_identity__sini_axon_02{{"agenix-identity/sini@axon-02"}}:::agenix_identity__sini_axon_02_c
  agenix_identity__sini_axon_03{{"agenix-identity/sini@axon-03"}}:::agenix_identity__sini_axon_03_c
  agenix_identity__sini_bitstream{{"agenix-identity/sini@bitstream"}}:::agenix_identity__sini_bitstream_c
  agenix_identity__sini_blade{{"agenix-identity/sini@blade"}}:::agenix_identity__sini_blade_c
  agenix_identity__sini_cortex{{"agenix-identity/sini@cortex"}}:::agenix_identity__sini_cortex_c
  agenix_identity__sini_uplink{{"agenix-identity/sini@uplink"}}:::agenix_identity__sini_uplink_c
  opkssh_authz__sini_axon_01{{"opkssh-authz/sini@axon-01"}}:::opkssh_authz__sini_axon_01_c
  opkssh_authz__sini_axon_02{{"opkssh-authz/sini@axon-02"}}:::opkssh_authz__sini_axon_02_c
  opkssh_authz__sini_axon_03{{"opkssh-authz/sini@axon-03"}}:::opkssh_authz__sini_axon_03_c
  opkssh_authz__sini_bitstream{{"opkssh-authz/sini@bitstream"}}:::opkssh_authz__sini_bitstream_c
  opkssh_authz__sini_blade{{"opkssh-authz/sini@blade"}}:::opkssh_authz__sini_blade_c
  opkssh_authz__sini_cortex{{"opkssh-authz/sini@cortex"}}:::opkssh_authz__sini_cortex_c
  opkssh_authz__sini_patch{{"opkssh-authz/sini@patch"}}:::opkssh_authz__sini_patch_c
  opkssh_authz__sini_slab{{"opkssh-authz/sini@slab"}}:::opkssh_authz__sini_slab_c
  opkssh_authz__sini_uplink{{"opkssh-authz/sini@uplink"}}:::opkssh_authz__sini_uplink_c
  core__network__syncthing__peer_user_sini[/"core/network/syncthing/peer"\]:::core__network__syncthing__peer_user_sini_c
  den__batteries__primary_user_sini_axon_01_{{"batteries/primary-user(sini@axon-01)"}}:::den__batteries__primary_user_sini_axon_01__c
  den__batteries__primary_user_sini_axon_02_{{"batteries/primary-user(sini@axon-02)"}}:::den__batteries__primary_user_sini_axon_02__c
  den__batteries__primary_user_sini_axon_03_{{"batteries/primary-user(sini@axon-03)"}}:::den__batteries__primary_user_sini_axon_03__c
  den__batteries__primary_user_sini_bitstream_{{"batteries/primary-user(sini@bitstream)"}}:::den__batteries__primary_user_sini_bitstream__c
  den__batteries__primary_user_sini_blade_{{"batteries/primary-user(sini@blade)"}}:::den__batteries__primary_user_sini_blade__c
  den__batteries__primary_user_sini_cortex_{{"batteries/primary-user(sini@cortex)"}}:::den__batteries__primary_user_sini_cortex__c
  den__batteries__primary_user_sini_patch_{{"batteries/primary-user(sini@patch)"}}:::den__batteries__primary_user_sini_patch__c
  den__batteries__primary_user_sini_slab_{{"batteries/primary-user(sini@slab)"}}:::den__batteries__primary_user_sini_slab__c
  den__batteries__primary_user_sini_uplink_{{"batteries/primary-user(sini@uplink)"}}:::den__batteries__primary_user_sini_uplink__c
  user_enrich__sini_axon_01{{"user-enrich/sini@axon-01"}}:::user_enrich__sini_axon_01_c
  user_enrich__sini_axon_02{{"user-enrich/sini@axon-02"}}:::user_enrich__sini_axon_02_c
  user_enrich__sini_axon_03{{"user-enrich/sini@axon-03"}}:::user_enrich__sini_axon_03_c
  user_enrich__sini_bitstream{{"user-enrich/sini@bitstream"}}:::user_enrich__sini_bitstream_c
  user_enrich__sini_blade{{"user-enrich/sini@blade"}}:::user_enrich__sini_blade_c
  user_enrich__sini_cortex{{"user-enrich/sini@cortex"}}:::user_enrich__sini_cortex_c
  user_enrich__sini_patch{{"user-enrich/sini@patch"}}:::user_enrich__sini_patch_c
  user_enrich__sini_slab{{"user-enrich/sini@slab"}}:::user_enrich__sini_slab_c
  user_enrich__sini_uplink{{"user-enrich/sini@uplink"}}:::user_enrich__sini_uplink_c

  end
  subgraph ctx_user_dvicory["user: dvicory"]
  agenix_identity__dvicory_axon_01{{"agenix-identity/dvicory@axon-01"}}:::agenix_identity__dvicory_axon_01_c
  agenix_identity__dvicory_axon_02{{"agenix-identity/dvicory@axon-02"}}:::agenix_identity__dvicory_axon_02_c
  agenix_identity__dvicory_axon_03{{"agenix-identity/dvicory@axon-03"}}:::agenix_identity__dvicory_axon_03_c
  agenix_identity__dvicory_bitstream{{"agenix-identity/dvicory@bitstream"}}:::agenix_identity__dvicory_bitstream_c
  agenix_identity__dvicory_uplink{{"agenix-identity/dvicory@uplink"}}:::agenix_identity__dvicory_uplink_c
  core__systemd__boot_user_dvicory[/"core/systemd/boot"\]:::core__systemd__boot_user_dvicory_c
  core__impermanence__btrfs_user_dvicory[/"core/impermanence/btrfs"\]:::core__impermanence__btrfs_user_dvicory_c
  roles__default_user_dvicory[/"roles/default"\]:::roles__default_user_dvicory_c
  core__users__deterministic_uids_user_dvicory[/"core/users/deterministic-uids"\]:::core__users__deterministic_uids_user_dvicory_c
  core__perf__disable_docs_user_dvicory[/"core/perf/disable-docs"\]:::core__perf__disable_docs_user_dvicory_c
  dvicory{{"dvicory"}}:::dvicory_c
  core__system__facter_user_dvicory[/"core/system/facter"\]:::core__system__facter_user_dvicory_c
  core__system__firmware_user_dvicory[/"core/system/firmware"\]:::core__system__firmware_user_dvicory_c
  core__users__home_manager_shared_user_dvicory[/"core/users/home-manager-shared"\]:::core__users__home_manager_shared_user_dvicory_c
  core__network__hostsfile_user_dvicory[/"core/network/hostsfile"\]:::core__network__hostsfile_user_dvicory_c
  core__localization__i18n_user_dvicory[/"core/localization/i18n"\]:::core__localization__i18n_user_dvicory_c
  core__impermanence_user_dvicory[/"core/impermanence"\]:::core__impermanence_user_dvicory_c
  core__system__linux_kernel_user_dvicory[/"core/system/linux-kernel"\]:::core__system__linux_kernel_user_dvicory_c
  core__network__networking_user_dvicory[/"core/network/networking"\]:::core__network__networking_user_dvicory_c
  core__nix_user_dvicory[/"core/nix"\]:::core__nix_user_dvicory_c
  core__security__openssh_user_dvicory[/"core/security/openssh"\]:::core__security__openssh_user_dvicory_c
  core__security__opkssh_user_dvicory[/"core/security/opkssh"\]:::core__security__opkssh_user_dvicory_c
  opkssh_authz__dvicory_axon_01{{"opkssh-authz/dvicory@axon-01"}}:::opkssh_authz__dvicory_axon_01_c
  opkssh_authz__dvicory_axon_02{{"opkssh-authz/dvicory@axon-02"}}:::opkssh_authz__dvicory_axon_02_c
  opkssh_authz__dvicory_axon_03{{"opkssh-authz/dvicory@axon-03"}}:::opkssh_authz__dvicory_axon_03_c
  opkssh_authz__dvicory_bitstream{{"opkssh-authz/dvicory@bitstream"}}:::opkssh_authz__dvicory_bitstream_c
  opkssh_authz__dvicory_uplink{{"opkssh-authz/dvicory@uplink"}}:::opkssh_authz__dvicory_uplink_c
  core__network__syncthing__peer_user_dvicory[/"core/network/syncthing/peer"\]:::core__network__syncthing__peer_user_dvicory_c
  core__impermanence__persist_collector_user_dvicory[/"core/impermanence/persist-collector"\]:::core__impermanence__persist_collector_user_dvicory_c
  core__security_user_dvicory[/"core/security"\]:::core__security_user_dvicory_c
  core__users__shell_user_dvicory[/"core/users/shell"\]:::core__users__shell_user_dvicory_c
  core__perf__ssd_user_dvicory[/"core/perf/ssd"\]:::core__perf__ssd_user_dvicory_c
  core__nix__stateVersion_user_dvicory[/"core/nix/stateVersion"\]:::core__nix__stateVersion_user_dvicory_c
  core__security__sudo_user_dvicory[/"core/security/sudo"\]:::core__security__sudo_user_dvicory_c
  core__systemd_user_dvicory[/"core/systemd"\]:::core__systemd_user_dvicory_c
  core__network__tailscale_user_dvicory[/"core/network/tailscale"\]:::core__network__tailscale_user_dvicory_c
  user_enrich__dvicory_axon_01{{"user-enrich/dvicory@axon-01"}}:::user_enrich__dvicory_axon_01_c
  user_enrich__dvicory_axon_02{{"user-enrich/dvicory@axon-02"}}:::user_enrich__dvicory_axon_02_c
  user_enrich__dvicory_axon_03{{"user-enrich/dvicory@axon-03"}}:::user_enrich__dvicory_axon_03_c
  user_enrich__dvicory_bitstream{{"user-enrich/dvicory@bitstream"}}:::user_enrich__dvicory_bitstream_c
  user_enrich__dvicory_uplink{{"user-enrich/dvicory@uplink"}}:::user_enrich__dvicory_uplink_c
  core__users_user_dvicory[/"core/users"\]:::core__users_user_dvicory_c
  core__utils_user_dvicory[/"core/utils"\]:::core__utils_user_dvicory_c
  core__impermanence__zfs_user_dvicory[/"core/impermanence/zfs"\]:::core__impermanence__zfs_user_dvicory_c
  core__perf__zram_swap_user_dvicory[/"core/perf/zram-swap"\]:::core__perf__zram_swap_user_dvicory_c
  core__impermanence_user_dvicory --> core__impermanence__btrfs_user_dvicory
  core__impermanence_user_dvicory --> core__impermanence__persist_collector_user_dvicory
  core__impermanence_user_dvicory --> core__impermanence__zfs_user_dvicory
  dvicory --> roles__default_user_dvicory
  roles__default_user_dvicory --> core__systemd__boot_user_dvicory
  roles__default_user_dvicory --> core__users__deterministic_uids_user_dvicory
  roles__default_user_dvicory --> core__perf__disable_docs_user_dvicory
  roles__default_user_dvicory --> core__system__facter_user_dvicory
  roles__default_user_dvicory --> core__system__firmware_user_dvicory
  roles__default_user_dvicory --> core__users__home_manager_shared_user_dvicory
  roles__default_user_dvicory --> core__network__hostsfile_user_dvicory
  roles__default_user_dvicory --> core__localization__i18n_user_dvicory
  roles__default_user_dvicory --> core__impermanence_user_dvicory
  roles__default_user_dvicory --> core__system__linux_kernel_user_dvicory
  roles__default_user_dvicory --> core__network__networking_user_dvicory
  roles__default_user_dvicory --> core__nix_user_dvicory
  roles__default_user_dvicory --> core__security__openssh_user_dvicory
  roles__default_user_dvicory --> core__security__opkssh_user_dvicory
  roles__default_user_dvicory --> core__security_user_dvicory
  roles__default_user_dvicory --> core__users__shell_user_dvicory
  roles__default_user_dvicory --> core__perf__ssd_user_dvicory
  roles__default_user_dvicory --> core__nix__stateVersion_user_dvicory
  roles__default_user_dvicory --> core__security__sudo_user_dvicory
  roles__default_user_dvicory --> core__systemd_user_dvicory
  roles__default_user_dvicory --> core__network__tailscale_user_dvicory
  roles__default_user_dvicory --> core__users_user_dvicory
  roles__default_user_dvicory --> core__utils_user_dvicory
  roles__default_user_dvicory --> core__perf__zram_swap_user_dvicory
  end
  subgraph ctx_user_pol["user: pol"]
  agenix_identity__pol_axon_01{{"agenix-identity/pol@axon-01"}}:::agenix_identity__pol_axon_01_c
  agenix_identity__pol_axon_02{{"agenix-identity/pol@axon-02"}}:::agenix_identity__pol_axon_02_c
  agenix_identity__pol_axon_03{{"agenix-identity/pol@axon-03"}}:::agenix_identity__pol_axon_03_c
  agenix_identity__pol_bitstream{{"agenix-identity/pol@bitstream"}}:::agenix_identity__pol_bitstream_c
  agenix_identity__pol_uplink{{"agenix-identity/pol@uplink"}}:::agenix_identity__pol_uplink_c
  core__systemd__boot_user_pol[/"core/systemd/boot"\]:::core__systemd__boot_user_pol_c
  core__impermanence__btrfs_user_pol[/"core/impermanence/btrfs"\]:::core__impermanence__btrfs_user_pol_c
  roles__default_user_pol[/"roles/default"\]:::roles__default_user_pol_c
  core__users__deterministic_uids_user_pol[/"core/users/deterministic-uids"\]:::core__users__deterministic_uids_user_pol_c
  core__perf__disable_docs_user_pol[/"core/perf/disable-docs"\]:::core__perf__disable_docs_user_pol_c
  core__system__facter_user_pol[/"core/system/facter"\]:::core__system__facter_user_pol_c
  core__system__firmware_user_pol[/"core/system/firmware"\]:::core__system__firmware_user_pol_c
  core__users__home_manager_shared_user_pol[/"core/users/home-manager-shared"\]:::core__users__home_manager_shared_user_pol_c
  core__network__hostsfile_user_pol[/"core/network/hostsfile"\]:::core__network__hostsfile_user_pol_c
  core__localization__i18n_user_pol[/"core/localization/i18n"\]:::core__localization__i18n_user_pol_c
  core__impermanence_user_pol[/"core/impermanence"\]:::core__impermanence_user_pol_c
  core__system__linux_kernel_user_pol[/"core/system/linux-kernel"\]:::core__system__linux_kernel_user_pol_c
  core__network__networking_user_pol[/"core/network/networking"\]:::core__network__networking_user_pol_c
  core__nix_user_pol[/"core/nix"\]:::core__nix_user_pol_c
  core__security__openssh_user_pol[/"core/security/openssh"\]:::core__security__openssh_user_pol_c
  core__security__opkssh_user_pol[/"core/security/opkssh"\]:::core__security__opkssh_user_pol_c
  opkssh_authz__pol_axon_01{{"opkssh-authz/pol@axon-01"}}:::opkssh_authz__pol_axon_01_c
  opkssh_authz__pol_axon_02{{"opkssh-authz/pol@axon-02"}}:::opkssh_authz__pol_axon_02_c
  opkssh_authz__pol_axon_03{{"opkssh-authz/pol@axon-03"}}:::opkssh_authz__pol_axon_03_c
  opkssh_authz__pol_bitstream{{"opkssh-authz/pol@bitstream"}}:::opkssh_authz__pol_bitstream_c
  opkssh_authz__pol_uplink{{"opkssh-authz/pol@uplink"}}:::opkssh_authz__pol_uplink_c
  core__network__syncthing__peer_user_pol[/"core/network/syncthing/peer"\]:::core__network__syncthing__peer_user_pol_c
  core__impermanence__persist_collector_user_pol[/"core/impermanence/persist-collector"\]:::core__impermanence__persist_collector_user_pol_c
  pol{{"pol"}}:::pol_c
  core__security_user_pol[/"core/security"\]:::core__security_user_pol_c
  core__users__shell_user_pol[/"core/users/shell"\]:::core__users__shell_user_pol_c
  core__perf__ssd_user_pol[/"core/perf/ssd"\]:::core__perf__ssd_user_pol_c
  core__nix__stateVersion_user_pol[/"core/nix/stateVersion"\]:::core__nix__stateVersion_user_pol_c
  core__security__sudo_user_pol[/"core/security/sudo"\]:::core__security__sudo_user_pol_c
  core__systemd_user_pol[/"core/systemd"\]:::core__systemd_user_pol_c
  core__network__tailscale_user_pol[/"core/network/tailscale"\]:::core__network__tailscale_user_pol_c
  user_enrich__pol_axon_01{{"user-enrich/pol@axon-01"}}:::user_enrich__pol_axon_01_c
  user_enrich__pol_axon_02{{"user-enrich/pol@axon-02"}}:::user_enrich__pol_axon_02_c
  user_enrich__pol_axon_03{{"user-enrich/pol@axon-03"}}:::user_enrich__pol_axon_03_c
  user_enrich__pol_bitstream{{"user-enrich/pol@bitstream"}}:::user_enrich__pol_bitstream_c
  user_enrich__pol_uplink{{"user-enrich/pol@uplink"}}:::user_enrich__pol_uplink_c
  core__users_user_pol[/"core/users"\]:::core__users_user_pol_c
  core__utils_user_pol[/"core/utils"\]:::core__utils_user_pol_c
  core__impermanence__zfs_user_pol[/"core/impermanence/zfs"\]:::core__impermanence__zfs_user_pol_c
  core__perf__zram_swap_user_pol[/"core/perf/zram-swap"\]:::core__perf__zram_swap_user_pol_c
  core__impermanence_user_pol --> core__impermanence__btrfs_user_pol
  core__impermanence_user_pol --> core__impermanence__persist_collector_user_pol
  core__impermanence_user_pol --> core__impermanence__zfs_user_pol
  pol --> roles__default_user_pol
  roles__default_user_pol --> core__systemd__boot_user_pol
  roles__default_user_pol --> core__users__deterministic_uids_user_pol
  roles__default_user_pol --> core__perf__disable_docs_user_pol
  roles__default_user_pol --> core__system__facter_user_pol
  roles__default_user_pol --> core__system__firmware_user_pol
  roles__default_user_pol --> core__users__home_manager_shared_user_pol
  roles__default_user_pol --> core__network__hostsfile_user_pol
  roles__default_user_pol --> core__localization__i18n_user_pol
  roles__default_user_pol --> core__impermanence_user_pol
  roles__default_user_pol --> core__system__linux_kernel_user_pol
  roles__default_user_pol --> core__network__networking_user_pol
  roles__default_user_pol --> core__nix_user_pol
  roles__default_user_pol --> core__security__openssh_user_pol
  roles__default_user_pol --> core__security__opkssh_user_pol
  roles__default_user_pol --> core__security_user_pol
  roles__default_user_pol --> core__users__shell_user_pol
  roles__default_user_pol --> core__perf__ssd_user_pol
  roles__default_user_pol --> core__nix__stateVersion_user_pol
  roles__default_user_pol --> core__security__sudo_user_pol
  roles__default_user_pol --> core__systemd_user_pol
  roles__default_user_pol --> core__network__tailscale_user_pol
  roles__default_user_pol --> core__users_user_pol
  roles__default_user_pol --> core__utils_user_pol
  roles__default_user_pol --> core__perf__zram_swap_user_pol
  end
  subgraph ctx_user_theutz["user: theutz"]
  agenix_identity__theutz_axon_01{{"agenix-identity/theutz@axon-01"}}:::agenix_identity__theutz_axon_01_c
  agenix_identity__theutz_axon_02{{"agenix-identity/theutz@axon-02"}}:::agenix_identity__theutz_axon_02_c
  agenix_identity__theutz_axon_03{{"agenix-identity/theutz@axon-03"}}:::agenix_identity__theutz_axon_03_c
  agenix_identity__theutz_bitstream{{"agenix-identity/theutz@bitstream"}}:::agenix_identity__theutz_bitstream_c
  agenix_identity__theutz_uplink{{"agenix-identity/theutz@uplink"}}:::agenix_identity__theutz_uplink_c
  core__systemd__boot_user_theutz[/"core/systemd/boot"\]:::core__systemd__boot_user_theutz_c
  core__impermanence__btrfs_user_theutz[/"core/impermanence/btrfs"\]:::core__impermanence__btrfs_user_theutz_c
  roles__default_user_theutz[/"roles/default"\]:::roles__default_user_theutz_c
  core__users__deterministic_uids_user_theutz[/"core/users/deterministic-uids"\]:::core__users__deterministic_uids_user_theutz_c
  core__perf__disable_docs_user_theutz[/"core/perf/disable-docs"\]:::core__perf__disable_docs_user_theutz_c
  core__system__facter_user_theutz[/"core/system/facter"\]:::core__system__facter_user_theutz_c
  core__system__firmware_user_theutz[/"core/system/firmware"\]:::core__system__firmware_user_theutz_c
  core__users__home_manager_shared_user_theutz[/"core/users/home-manager-shared"\]:::core__users__home_manager_shared_user_theutz_c
  core__network__hostsfile_user_theutz[/"core/network/hostsfile"\]:::core__network__hostsfile_user_theutz_c
  core__localization__i18n_user_theutz[/"core/localization/i18n"\]:::core__localization__i18n_user_theutz_c
  core__impermanence_user_theutz[/"core/impermanence"\]:::core__impermanence_user_theutz_c
  core__system__linux_kernel_user_theutz[/"core/system/linux-kernel"\]:::core__system__linux_kernel_user_theutz_c
  core__network__networking_user_theutz[/"core/network/networking"\]:::core__network__networking_user_theutz_c
  core__nix_user_theutz[/"core/nix"\]:::core__nix_user_theutz_c
  core__security__openssh_user_theutz[/"core/security/openssh"\]:::core__security__openssh_user_theutz_c
  core__security__opkssh_user_theutz[/"core/security/opkssh"\]:::core__security__opkssh_user_theutz_c
  opkssh_authz__theutz_axon_01{{"opkssh-authz/theutz@axon-01"}}:::opkssh_authz__theutz_axon_01_c
  opkssh_authz__theutz_axon_02{{"opkssh-authz/theutz@axon-02"}}:::opkssh_authz__theutz_axon_02_c
  opkssh_authz__theutz_axon_03{{"opkssh-authz/theutz@axon-03"}}:::opkssh_authz__theutz_axon_03_c
  opkssh_authz__theutz_bitstream{{"opkssh-authz/theutz@bitstream"}}:::opkssh_authz__theutz_bitstream_c
  opkssh_authz__theutz_uplink{{"opkssh-authz/theutz@uplink"}}:::opkssh_authz__theutz_uplink_c
  core__network__syncthing__peer_user_theutz[/"core/network/syncthing/peer"\]:::core__network__syncthing__peer_user_theutz_c
  core__impermanence__persist_collector_user_theutz[/"core/impermanence/persist-collector"\]:::core__impermanence__persist_collector_user_theutz_c
  core__security_user_theutz[/"core/security"\]:::core__security_user_theutz_c
  core__users__shell_user_theutz[/"core/users/shell"\]:::core__users__shell_user_theutz_c
  core__perf__ssd_user_theutz[/"core/perf/ssd"\]:::core__perf__ssd_user_theutz_c
  core__nix__stateVersion_user_theutz[/"core/nix/stateVersion"\]:::core__nix__stateVersion_user_theutz_c
  core__security__sudo_user_theutz[/"core/security/sudo"\]:::core__security__sudo_user_theutz_c
  core__systemd_user_theutz[/"core/systemd"\]:::core__systemd_user_theutz_c
  core__network__tailscale_user_theutz[/"core/network/tailscale"\]:::core__network__tailscale_user_theutz_c
  theutz{{"theutz"}}:::theutz_c
  user_enrich__theutz_axon_01{{"user-enrich/theutz@axon-01"}}:::user_enrich__theutz_axon_01_c
  user_enrich__theutz_axon_02{{"user-enrich/theutz@axon-02"}}:::user_enrich__theutz_axon_02_c
  user_enrich__theutz_axon_03{{"user-enrich/theutz@axon-03"}}:::user_enrich__theutz_axon_03_c
  user_enrich__theutz_bitstream{{"user-enrich/theutz@bitstream"}}:::user_enrich__theutz_bitstream_c
  user_enrich__theutz_uplink{{"user-enrich/theutz@uplink"}}:::user_enrich__theutz_uplink_c
  core__users_user_theutz[/"core/users"\]:::core__users_user_theutz_c
  core__utils_user_theutz[/"core/utils"\]:::core__utils_user_theutz_c
  core__impermanence__zfs_user_theutz[/"core/impermanence/zfs"\]:::core__impermanence__zfs_user_theutz_c
  core__perf__zram_swap_user_theutz[/"core/perf/zram-swap"\]:::core__perf__zram_swap_user_theutz_c
  core__impermanence_user_theutz --> core__impermanence__btrfs_user_theutz
  core__impermanence_user_theutz --> core__impermanence__persist_collector_user_theutz
  core__impermanence_user_theutz --> core__impermanence__zfs_user_theutz
  roles__default_user_theutz --> core__systemd__boot_user_theutz
  roles__default_user_theutz --> core__users__deterministic_uids_user_theutz
  roles__default_user_theutz --> core__perf__disable_docs_user_theutz
  roles__default_user_theutz --> core__system__facter_user_theutz
  roles__default_user_theutz --> core__system__firmware_user_theutz
  roles__default_user_theutz --> core__users__home_manager_shared_user_theutz
  roles__default_user_theutz --> core__network__hostsfile_user_theutz
  roles__default_user_theutz --> core__localization__i18n_user_theutz
  roles__default_user_theutz --> core__impermanence_user_theutz
  roles__default_user_theutz --> core__system__linux_kernel_user_theutz
  roles__default_user_theutz --> core__network__networking_user_theutz
  roles__default_user_theutz --> core__nix_user_theutz
  roles__default_user_theutz --> core__security__openssh_user_theutz
  roles__default_user_theutz --> core__security__opkssh_user_theutz
  roles__default_user_theutz --> core__security_user_theutz
  roles__default_user_theutz --> core__users__shell_user_theutz
  roles__default_user_theutz --> core__perf__ssd_user_theutz
  roles__default_user_theutz --> core__nix__stateVersion_user_theutz
  roles__default_user_theutz --> core__security__sudo_user_theutz
  roles__default_user_theutz --> core__systemd_user_theutz
  roles__default_user_theutz --> core__network__tailscale_user_theutz
  roles__default_user_theutz --> core__users_user_theutz
  roles__default_user_theutz --> core__utils_user_theutz
  roles__default_user_theutz --> core__perf__zram_swap_user_theutz
  theutz --> roles__default_user_theutz
  end
  subgraph ctx_user_vic["user: vic"]
  agenix_identity__vic_axon_01{{"agenix-identity/vic@axon-01"}}:::agenix_identity__vic_axon_01_c
  agenix_identity__vic_axon_02{{"agenix-identity/vic@axon-02"}}:::agenix_identity__vic_axon_02_c
  agenix_identity__vic_axon_03{{"agenix-identity/vic@axon-03"}}:::agenix_identity__vic_axon_03_c
  agenix_identity__vic_bitstream{{"agenix-identity/vic@bitstream"}}:::agenix_identity__vic_bitstream_c
  agenix_identity__vic_blade{{"agenix-identity/vic@blade"}}:::agenix_identity__vic_blade_c
  agenix_identity__vic_cortex{{"agenix-identity/vic@cortex"}}:::agenix_identity__vic_cortex_c
  agenix_identity__vic_uplink{{"agenix-identity/vic@uplink"}}:::agenix_identity__vic_uplink_c
  core__systemd__boot_user_vic[/"core/systemd/boot"\]:::core__systemd__boot_user_vic_c
  core__impermanence__btrfs_user_vic[/"core/impermanence/btrfs"\]:::core__impermanence__btrfs_user_vic_c
  roles__default_user_vic[/"roles/default"\]:::roles__default_user_vic_c
  core__users__deterministic_uids_user_vic[/"core/users/deterministic-uids"\]:::core__users__deterministic_uids_user_vic_c
  core__perf__disable_docs_user_vic[/"core/perf/disable-docs"\]:::core__perf__disable_docs_user_vic_c
  core__system__facter_user_vic[/"core/system/facter"\]:::core__system__facter_user_vic_c
  core__system__firmware_user_vic[/"core/system/firmware"\]:::core__system__firmware_user_vic_c
  core__users__home_manager_shared_user_vic[/"core/users/home-manager-shared"\]:::core__users__home_manager_shared_user_vic_c
  core__network__hostsfile_user_vic[/"core/network/hostsfile"\]:::core__network__hostsfile_user_vic_c
  core__localization__i18n_user_vic[/"core/localization/i18n"\]:::core__localization__i18n_user_vic_c
  core__impermanence_user_vic[/"core/impermanence"\]:::core__impermanence_user_vic_c
  core__system__linux_kernel_user_vic[/"core/system/linux-kernel"\]:::core__system__linux_kernel_user_vic_c
  core__network__networking_user_vic[/"core/network/networking"\]:::core__network__networking_user_vic_c
  core__nix_user_vic[/"core/nix"\]:::core__nix_user_vic_c
  core__security__openssh_user_vic[/"core/security/openssh"\]:::core__security__openssh_user_vic_c
  core__security__opkssh_user_vic[/"core/security/opkssh"\]:::core__security__opkssh_user_vic_c
  opkssh_authz__vic_axon_01{{"opkssh-authz/vic@axon-01"}}:::opkssh_authz__vic_axon_01_c
  opkssh_authz__vic_axon_02{{"opkssh-authz/vic@axon-02"}}:::opkssh_authz__vic_axon_02_c
  opkssh_authz__vic_axon_03{{"opkssh-authz/vic@axon-03"}}:::opkssh_authz__vic_axon_03_c
  opkssh_authz__vic_bitstream{{"opkssh-authz/vic@bitstream"}}:::opkssh_authz__vic_bitstream_c
  opkssh_authz__vic_blade{{"opkssh-authz/vic@blade"}}:::opkssh_authz__vic_blade_c
  opkssh_authz__vic_cortex{{"opkssh-authz/vic@cortex"}}:::opkssh_authz__vic_cortex_c
  opkssh_authz__vic_uplink{{"opkssh-authz/vic@uplink"}}:::opkssh_authz__vic_uplink_c
  core__network__syncthing__peer_user_vic[/"core/network/syncthing/peer"\]:::core__network__syncthing__peer_user_vic_c
  core__impermanence__persist_collector_user_vic[/"core/impermanence/persist-collector"\]:::core__impermanence__persist_collector_user_vic_c
  core__security_user_vic[/"core/security"\]:::core__security_user_vic_c
  core__users__shell_user_vic[/"core/users/shell"\]:::core__users__shell_user_vic_c
  core__perf__ssd_user_vic[/"core/perf/ssd"\]:::core__perf__ssd_user_vic_c
  core__nix__stateVersion_user_vic[/"core/nix/stateVersion"\]:::core__nix__stateVersion_user_vic_c
  core__security__sudo_user_vic[/"core/security/sudo"\]:::core__security__sudo_user_vic_c
  core__systemd_user_vic[/"core/systemd"\]:::core__systemd_user_vic_c
  core__network__tailscale_user_vic[/"core/network/tailscale"\]:::core__network__tailscale_user_vic_c
  user_enrich__vic_axon_01{{"user-enrich/vic@axon-01"}}:::user_enrich__vic_axon_01_c
  user_enrich__vic_axon_02{{"user-enrich/vic@axon-02"}}:::user_enrich__vic_axon_02_c
  user_enrich__vic_axon_03{{"user-enrich/vic@axon-03"}}:::user_enrich__vic_axon_03_c
  user_enrich__vic_bitstream{{"user-enrich/vic@bitstream"}}:::user_enrich__vic_bitstream_c
  user_enrich__vic_blade{{"user-enrich/vic@blade"}}:::user_enrich__vic_blade_c
  user_enrich__vic_cortex{{"user-enrich/vic@cortex"}}:::user_enrich__vic_cortex_c
  user_enrich__vic_uplink{{"user-enrich/vic@uplink"}}:::user_enrich__vic_uplink_c
  core__users_user_vic[/"core/users"\]:::core__users_user_vic_c
  core__utils_user_vic[/"core/utils"\]:::core__utils_user_vic_c
  vic{{"vic"}}:::vic_c
  core__impermanence__zfs_user_vic[/"core/impermanence/zfs"\]:::core__impermanence__zfs_user_vic_c
  core__perf__zram_swap_user_vic[/"core/perf/zram-swap"\]:::core__perf__zram_swap_user_vic_c
  core__impermanence_user_vic --> core__impermanence__btrfs_user_vic
  core__impermanence_user_vic --> core__impermanence__persist_collector_user_vic
  core__impermanence_user_vic --> core__impermanence__zfs_user_vic
  roles__default_user_vic --> core__systemd__boot_user_vic
  roles__default_user_vic --> core__users__deterministic_uids_user_vic
  roles__default_user_vic --> core__perf__disable_docs_user_vic
  roles__default_user_vic --> core__system__facter_user_vic
  roles__default_user_vic --> core__system__firmware_user_vic
  roles__default_user_vic --> core__users__home_manager_shared_user_vic
  roles__default_user_vic --> core__network__hostsfile_user_vic
  roles__default_user_vic --> core__localization__i18n_user_vic
  roles__default_user_vic --> core__impermanence_user_vic
  roles__default_user_vic --> core__system__linux_kernel_user_vic
  roles__default_user_vic --> core__network__networking_user_vic
  roles__default_user_vic --> core__nix_user_vic
  roles__default_user_vic --> core__security__openssh_user_vic
  roles__default_user_vic --> core__security__opkssh_user_vic
  roles__default_user_vic --> core__security_user_vic
  roles__default_user_vic --> core__users__shell_user_vic
  roles__default_user_vic --> core__perf__ssd_user_vic
  roles__default_user_vic --> core__nix__stateVersion_user_vic
  roles__default_user_vic --> core__security__sudo_user_vic
  roles__default_user_vic --> core__systemd_user_vic
  roles__default_user_vic --> core__network__tailscale_user_vic
  roles__default_user_vic --> core__users_user_vic
  roles__default_user_vic --> core__utils_user_vic
  roles__default_user_vic --> core__perf__zram_swap_user_vic
  vic --> roles__default_user_vic
  end
  subgraph ctx_host_axon_03["host: axon-03"]
  services__security__acme[/"security/acme"\]:::services__security__acme_c
  agenix__axon_03{{"agenix/axon-03"}}:::agenix__axon_03_c
  hardware__cpu__amd[/"cpu/amd"\]:::hardware__cpu__amd_c
  hardware__gpu__amd[/"gpu/amd"\]:::hardware__gpu__amd_c
  services__bgp[/"services/bgp"\]:::services__bgp_c
  core__systemd__boot_host_axon_03[/"core/systemd/boot"\]:::core__systemd__boot_host_axon_03_c
  services__k3s__bootstrap[/"k3s/bootstrap"\]:::services__k3s__bootstrap_c
  core__impermanence__btrfs_host_axon_03[/"core/impermanence/btrfs"\]:::core__impermanence__btrfs_host_axon_03_c
  services__bgp__cilium_bgp[/"bgp/cilium-bgp"\]:::services__bgp__cilium_bgp_c
  core__secrets__collector[/"secrets/collector"\]:::core__secrets__collector_c
  services__k3s__containerd[/"k3s/containerd"\]:::services__k3s__containerd_c
  roles__default_host_axon_03[/"roles/default"\]:::roles__default_host_axon_03_c
  den__batteries__define_user[/"batteries/define-user"\]:::den__batteries__define_user_c
  den__batteries__define_user__dvicory_axon_03{{"batteries/define-user/dvicory@axon-03"}}:::den__batteries__define_user__dvicory_axon_03_c
  den__batteries__define_user__pol_axon_03{{"batteries/define-user/pol@axon-03"}}:::den__batteries__define_user__pol_axon_03_c
  den__batteries__define_user__sini_axon_03{{"batteries/define-user/sini@axon-03"}}:::den__batteries__define_user__sini_axon_03_c
  den__batteries__define_user__theutz_axon_03{{"batteries/define-user/theutz@axon-03"}}:::den__batteries__define_user__theutz_axon_03_c
  den__batteries__define_user__vic_axon_03{{"batteries/define-user/vic@axon-03"}}:::den__batteries__define_user__vic_axon_03_c
  core__users__deterministic_uids_host_axon_03[/"core/users/deterministic-uids"\]:::core__users__deterministic_uids_host_axon_03_c
  core__perf__disable_docs_host_axon_03[/"core/perf/disable-docs"\]:::core__perf__disable_docs_host_axon_03_c
  core__system__facter_host_axon_03[/"core/system/facter"\]:::core__system__facter_host_axon_03_c
  core__network__firewall_collector[/"network/firewall-collector"\]:::core__network__firewall_collector_c
  core__system__firmware_host_axon_03[/"core/system/firmware"\]:::core__system__firmware_host_axon_03_c
  core__users__home_manager_shared_host_axon_03[/"core/users/home-manager-shared"\]:::core__users__home_manager_shared_host_axon_03_c
  den__batteries__hostname[/"batteries/hostname"\]:::den__batteries__hostname_c
  den__batteries__hostname__os{{"batteries/hostname/os"}}:::den__batteries__hostname__os_c
  core__network__hostsfile_host_axon_03[/"core/network/hostsfile"\]:::core__network__hostsfile_host_axon_03_c
  core__localization__i18n_host_axon_03[/"core/localization/i18n"\]:::core__localization__i18n_host_axon_03_c
  core__impermanence_host_axon_03[/"core/impermanence"\]:::core__impermanence_host_axon_03_c
  den__batteries__inputs_[/"batteries/inputs'"\]:::den__batteries__inputs__c
  den__batteries__inputs___os{{"batteries/inputs'/os"}}:::den__batteries__inputs___os_c
  insecure_predicate["insecure-predicate"]:::insecure_predicate_c
  insecure_predicate__os{{"insecure-predicate/os"}}:::insecure_predicate__os_c
  services__k3s[/"services/k3s"\]:::services__k3s_c
  core__system__linux_kernel_host_axon_03[/"core/system/linux-kernel"\]:::core__system__linux_kernel_host_axon_03_c
  services__storage__media_data_share[/"storage/media-data-share"\]:::services__storage__media_data_share_c
  core__boot__network_initrd[/"boot/network-initrd"\]:::core__boot__network_initrd_c
  core__network__networking_host_axon_03[/"core/network/networking"\]:::core__network__networking_host_axon_03_c
  core__nix_host_axon_03[/"core/nix"\]:::core__nix_host_axon_03_c
  roles__nix_builder[/"roles/nix-builder"\]:::roles__nix_builder_c
  services__k3s__node[/"k3s/node"\]:::services__k3s__node_c
  services__k3s__node_lifecycle[/"k3s/node-lifecycle"\]:::services__k3s__node_lifecycle_c
  core__security__openssh_host_axon_03[/"core/security/openssh"\]:::core__security__openssh_host_axon_03_c
  core__security__opkssh_host_axon_03[/"core/security/opkssh"\]:::core__security__opkssh_host_axon_03_c
  core__impermanence__persist_collector_host_axon_03[/"core/impermanence/persist-collector"\]:::core__impermanence__persist_collector_host_axon_03_c
  services__monitoring__prometheus_exporter[/"monitoring/prometheus-exporter"\]:::services__monitoring__prometheus_exporter_c
  services__nix__remote_build_server[/"nix/remote-build-server"\]:::services__nix__remote_build_server_c
  disk__zfs_disk_single__root[/"zfs-disk-single/root"\]:::disk__zfs_disk_single__root_c
  core__security_host_axon_03[/"core/security"\]:::core__security_host_axon_03_c
  den__batteries__self_[/"batteries/self'"\]:::den__batteries__self__c
  den__batteries__self___os{{"batteries/self'/os"}}:::den__batteries__self___os_c
  roles__server[/"roles/server"\]:::roles__server_c
  core__users__shell_host_axon_03[/"core/users/shell"\]:::core__users__shell_host_axon_03_c
  services__bgp__spoke[/"bgp/spoke"\]:::services__bgp__spoke_c
  core__perf__ssd_host_axon_03[/"core/perf/ssd"\]:::core__perf__ssd_host_axon_03_c
  core__nix__stateVersion_host_axon_03[/"core/nix/stateVersion"\]:::core__nix__stateVersion_host_axon_03_c
  core__security__sudo_host_axon_03[/"core/security/sudo"\]:::core__security__sudo_host_axon_03_c
  core__systemd_host_axon_03[/"core/systemd"\]:::core__systemd_host_axon_03_c
  core__network__tailscale_host_axon_03[/"core/network/tailscale"\]:::core__network__tailscale_host_axon_03_c
  services__security__tang[/"security/tang"\]:::services__security__tang_c
  services__networking__thunderbolt_mesh_of[/"networking/thunderbolt-mesh-of"\]:::services__networking__thunderbolt_mesh_of_c
  hardware__thunderbolt_network[/"hardware/thunderbolt-network"\]:::hardware__thunderbolt_network_c
  unfree_predicate["unfree-predicate"]:::unfree_predicate_c
  unfree_predicate__os{{"unfree-predicate/os"}}:::unfree_predicate__os_c
  core__users_host_axon_03[/"core/users"\]:::core__users_host_axon_03_c
  core__utils_host_axon_03[/"core/utils"\]:::core__utils_host_axon_03_c
  disk__xfs_disk_longhorn[/"disk/xfs-disk-longhorn"\]:::disk__xfs_disk_longhorn_c
  core__impermanence__zfs_host_axon_03[/"core/impermanence/zfs"\]:::core__impermanence__zfs_host_axon_03_c
  disk__zfs_diff[/"disk/zfs-diff"\]:::disk__zfs_diff_c
  disk__zfs_disk_single[/"disk/zfs-disk-single"\]:::disk__zfs_disk_single_c
  core__perf__zram_swap_host_axon_03[/"core/perf/zram-swap"\]:::core__perf__zram_swap_host_axon_03_c
  axon_03 --> hardware__cpu__amd
  axon_03 --> hardware__gpu__amd
  axon_03 --> services__bgp__cilium_bgp
  axon_03 --> roles__default_host_axon_03
  axon_03 --> services__k3s
  axon_03 --> core__boot__network_initrd
  axon_03 --> roles__nix_builder
  axon_03 --> roles__server
  axon_03 --> services__bgp__spoke
  axon_03 --> services__networking__thunderbolt_mesh_of
  axon_03 --> disk__xfs_disk_longhorn
  axon_03 --> disk__zfs_disk_single
  core__impermanence_host_axon_03 --> core__impermanence__btrfs_host_axon_03
  core__impermanence_host_axon_03 --> core__impermanence__persist_collector_host_axon_03
  core__impermanence_host_axon_03 --> core__impermanence__zfs_host_axon_03
  den__batteries__define_user --> den__batteries__define_user__dvicory_axon_03
  den__batteries__define_user --> den__batteries__define_user__pol_axon_03
  den__batteries__define_user --> den__batteries__define_user__sini_axon_03
  den__batteries__define_user --> den__batteries__define_user__theutz_axon_03
  den__batteries__define_user --> den__batteries__define_user__vic_axon_03
  den__batteries__hostname --> den__batteries__hostname__os
  den__batteries__inputs_ --> den__batteries__inputs___os
  den__batteries__self_ --> den__batteries__self___os
  disk__zfs_disk_single --> disk__zfs_disk_single__root
  disk__zfs_disk_single__root --> disk__zfs_diff
  insecure_predicate --> insecure_predicate__os
  roles__default_host_axon_03 --> core__systemd__boot_host_axon_03
  roles__default_host_axon_03 --> core__users__deterministic_uids_host_axon_03
  roles__default_host_axon_03 --> core__perf__disable_docs_host_axon_03
  roles__default_host_axon_03 --> core__system__facter_host_axon_03
  roles__default_host_axon_03 --> core__system__firmware_host_axon_03
  roles__default_host_axon_03 --> core__users__home_manager_shared_host_axon_03
  roles__default_host_axon_03 --> core__network__hostsfile_host_axon_03
  roles__default_host_axon_03 --> core__localization__i18n_host_axon_03
  roles__default_host_axon_03 --> core__impermanence_host_axon_03
  roles__default_host_axon_03 --> core__system__linux_kernel_host_axon_03
  roles__default_host_axon_03 --> core__network__networking_host_axon_03
  roles__default_host_axon_03 --> core__nix_host_axon_03
  roles__default_host_axon_03 --> core__security__openssh_host_axon_03
  roles__default_host_axon_03 --> core__security__opkssh_host_axon_03
  roles__default_host_axon_03 --> core__security_host_axon_03
  roles__default_host_axon_03 --> core__users__shell_host_axon_03
  roles__default_host_axon_03 --> core__perf__ssd_host_axon_03
  roles__default_host_axon_03 --> core__nix__stateVersion_host_axon_03
  roles__default_host_axon_03 --> core__security__sudo_host_axon_03
  roles__default_host_axon_03 --> core__systemd_host_axon_03
  roles__default_host_axon_03 --> core__network__tailscale_host_axon_03
  roles__default_host_axon_03 --> core__users_host_axon_03
  roles__default_host_axon_03 --> core__utils_host_axon_03
  roles__default_host_axon_03 --> core__perf__zram_swap_host_axon_03
  roles__nix_builder --> services__nix__remote_build_server
  roles__server --> services__security__acme
  roles__server --> services__storage__media_data_share
  roles__server --> services__monitoring__prometheus_exporter
  roles__server --> services__security__tang
  services__bgp__spoke --> services__bgp
  services__k3s --> services__k3s__bootstrap
  services__k3s --> services__k3s__containerd
  services__k3s --> services__k3s__node
  services__k3s --> services__k3s__node_lifecycle
  services__networking__thunderbolt_mesh_of --> hardware__thunderbolt_network
  unfree_predicate --> unfree_predicate__os
  end


  classDef root fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,font-weight:bold
  classDef services__security__acme_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef agenix_identity__dvicory_axon_01_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__dvicory_axon_02_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__dvicory_axon_03_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__dvicory_bitstream_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__dvicory_uplink_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__pol_axon_01_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__pol_axon_02_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__pol_axon_03_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__pol_bitstream_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__pol_uplink_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__sini_axon_01_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__sini_axon_02_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__sini_axon_03_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__sini_bitstream_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__sini_blade_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__sini_cortex_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__sini_uplink_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__theutz_axon_01_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__theutz_axon_02_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__theutz_axon_03_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__theutz_bitstream_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__theutz_uplink_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__vic_axon_01_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__vic_axon_02_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__vic_axon_03_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__vic_bitstream_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__vic_blade_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__vic_cortex_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef agenix_identity__vic_uplink_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef agenix__axon_03_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:2px
  classDef hardware__cpu__amd_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef hardware__gpu__amd_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef axon_03_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef services__bgp_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef core__systemd__boot_user_dvicory_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__systemd__boot_user_pol_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__systemd__boot_user_theutz_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__systemd__boot_user_vic_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__systemd__boot_host_axon_03_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef services__k3s__bootstrap_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence__btrfs_user_dvicory_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence__btrfs_user_pol_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence__btrfs_user_theutz_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence__btrfs_user_vic_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence__btrfs_host_axon_03_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef services__bgp__cilium_bgp_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef core__secrets__collector_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:2px
  classDef services__k3s__containerd_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef core_c fill:#f9e2af,stroke:#f9e2af,color:#1e1e2e,stroke-dasharray: 3 3,stroke-width:1px
  classDef roles__default_user_dvicory_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef roles__default_user_pol_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef roles__default_user_theutz_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef roles__default_user_vic_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef roles__default_host_axon_03_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef den__batteries__define_user_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef den__batteries__define_user__dvicory_axon_03_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef den__batteries__define_user__pol_axon_03_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef den__batteries__define_user__sini_axon_03_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:2px
  classDef den__batteries__define_user__theutz_axon_03_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef den__batteries__define_user__vic_axon_03_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:2px
  classDef core__users__deterministic_uids_user_dvicory_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:3px
  classDef core__users__deterministic_uids_user_pol_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:3px
  classDef core__users__deterministic_uids_user_theutz_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:3px
  classDef core__users__deterministic_uids_user_vic_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:3px
  classDef core__users__deterministic_uids_host_axon_03_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__perf__disable_docs_user_dvicory_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__perf__disable_docs_user_pol_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__perf__disable_docs_user_theutz_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__perf__disable_docs_user_vic_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__perf__disable_docs_host_axon_03_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef disk_c fill:#a6e3a1,stroke:#a6e3a1,color:#1e1e2e,stroke-dasharray: 3 3,stroke-width:1px
  classDef dvicory_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__system__facter_user_dvicory_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__system__facter_user_pol_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__system__facter_user_theutz_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__system__facter_user_vic_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__system__facter_host_axon_03_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef core__network__firewall_collector_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:2px
  classDef core__system__firmware_user_dvicory_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__system__firmware_user_pol_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__system__firmware_user_theutz_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__system__firmware_user_vic_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__system__firmware_host_axon_03_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef hardware_c fill:#a6e3a1,stroke:#a6e3a1,color:#1e1e2e,stroke-dasharray: 3 3,stroke-width:1px
  classDef core__users__home_manager_shared_user_dvicory_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__users__home_manager_shared_user_pol_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__users__home_manager_shared_user_theutz_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__users__home_manager_shared_user_vic_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__users__home_manager_shared_host_axon_03_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef den__batteries__hostname_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef den__batteries__hostname__os_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:2px
  classDef core__network__hostsfile_user_dvicory_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__network__hostsfile_user_pol_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__network__hostsfile_user_theutz_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__network__hostsfile_user_vic_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__network__hostsfile_host_axon_03_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef core__localization__i18n_user_dvicory_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__localization__i18n_user_pol_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__localization__i18n_user_theutz_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__localization__i18n_user_vic_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__localization__i18n_host_axon_03_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence_user_dvicory_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence_user_pol_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence_user_theutz_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence_user_vic_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence_host_axon_03_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef den__batteries__inputs__c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef den__batteries__inputs___os_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:2px
  classDef insecure_predicate_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef insecure_predicate__os_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:2px
  classDef services__k3s_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__system__linux_kernel_user_dvicory_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__system__linux_kernel_user_pol_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__system__linux_kernel_user_theutz_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__system__linux_kernel_user_vic_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__system__linux_kernel_host_axon_03_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef services__storage__media_data_share_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef core__boot__network_initrd_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef core__network__networking_user_dvicory_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__network__networking_user_pol_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__network__networking_user_theutz_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__network__networking_user_vic_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__network__networking_host_axon_03_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef core__nix_user_dvicory_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__nix_user_pol_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__nix_user_theutz_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__nix_user_vic_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__nix_host_axon_03_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef roles__nix_builder_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef services__k3s__node_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef services__k3s__node_lifecycle_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef core__security__openssh_user_dvicory_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__security__openssh_user_pol_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__security__openssh_user_theutz_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__security__openssh_user_vic_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__security__openssh_host_axon_03_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef core__security__opkssh_user_dvicory_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__security__opkssh_user_pol_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__security__opkssh_user_theutz_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__security__opkssh_user_vic_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__security__opkssh_host_axon_03_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef opkssh_authz__dvicory_axon_01_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__dvicory_axon_02_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__dvicory_axon_03_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__dvicory_bitstream_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__dvicory_uplink_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__pol_axon_01_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__pol_axon_02_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__pol_axon_03_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__pol_bitstream_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__pol_uplink_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__sini_axon_01_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__sini_axon_02_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__sini_axon_03_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__sini_bitstream_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__sini_blade_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__sini_cortex_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__sini_patch_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__sini_slab_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__sini_uplink_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__theutz_axon_01_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__theutz_axon_02_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__theutz_axon_03_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__theutz_bitstream_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__theutz_uplink_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__vic_axon_01_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__vic_axon_02_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__vic_axon_03_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__vic_bitstream_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__vic_blade_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__vic_cortex_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef opkssh_authz__vic_uplink_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef core__network__syncthing__peer_user_sini_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef core__network__syncthing__peer_user_dvicory_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef core__network__syncthing__peer_user_pol_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef core__network__syncthing__peer_user_theutz_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef core__network__syncthing__peer_user_vic_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef core__impermanence__persist_collector_user_dvicory_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence__persist_collector_user_pol_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence__persist_collector_user_theutz_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence__persist_collector_user_vic_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence__persist_collector_host_axon_03_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef pol_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef den__batteries__primary_user_sini_axon_01__c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef den__batteries__primary_user_sini_axon_02__c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef den__batteries__primary_user_sini_axon_03__c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef den__batteries__primary_user_sini_bitstream__c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef den__batteries__primary_user_sini_blade__c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef den__batteries__primary_user_sini_cortex__c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef den__batteries__primary_user_sini_patch__c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef den__batteries__primary_user_sini_slab__c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef den__batteries__primary_user_sini_uplink__c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef services__monitoring__prometheus_exporter_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef services__nix__remote_build_server_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef roles_c fill:#a6e3a1,stroke:#a6e3a1,color:#1e1e2e,stroke-dasharray: 3 3,stroke-width:1px
  classDef disk__zfs_disk_single__root_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef core__security_user_dvicory_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__security_user_pol_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__security_user_theutz_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__security_user_vic_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__security_host_axon_03_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef den__batteries__self__c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef den__batteries__self___os_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef roles__server_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef services_c fill:#a6e3a1,stroke:#a6e3a1,color:#1e1e2e,stroke-dasharray: 3 3,stroke-width:1px
  classDef core__users__shell_user_dvicory_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__users__shell_user_pol_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__users__shell_user_theutz_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__users__shell_user_vic_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__users__shell_host_axon_03_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef services__bgp__spoke_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef core__perf__ssd_user_dvicory_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__perf__ssd_user_pol_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__perf__ssd_user_theutz_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__perf__ssd_user_vic_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__perf__ssd_host_axon_03_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef core__nix__stateVersion_user_dvicory_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__nix__stateVersion_user_pol_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__nix__stateVersion_user_theutz_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__nix__stateVersion_user_vic_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__nix__stateVersion_host_axon_03_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef core__security__sudo_user_dvicory_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__security__sudo_user_pol_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__security__sudo_user_theutz_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__security__sudo_user_vic_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__security__sudo_host_axon_03_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef core__systemd_user_dvicory_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__systemd_user_pol_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__systemd_user_theutz_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__systemd_user_vic_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__systemd_host_axon_03_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef core__network__tailscale_user_dvicory_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:3px
  classDef core__network__tailscale_user_pol_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:3px
  classDef core__network__tailscale_user_theutz_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:3px
  classDef core__network__tailscale_user_vic_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:3px
  classDef core__network__tailscale_host_axon_03_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef services__security__tang_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef theutz_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef services__networking__thunderbolt_mesh_of_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef hardware__thunderbolt_network_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef unfree_predicate_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef unfree_predicate__os_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__dvicory_axon_01_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__dvicory_axon_02_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__dvicory_axon_03_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__dvicory_bitstream_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__dvicory_uplink_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__pol_axon_01_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__pol_axon_02_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__pol_axon_03_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__pol_bitstream_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__pol_uplink_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__sini_axon_01_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__sini_axon_02_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__sini_axon_03_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__sini_bitstream_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__sini_blade_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__sini_cortex_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__sini_patch_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__sini_slab_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__sini_uplink_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__theutz_axon_01_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__theutz_axon_02_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__theutz_axon_03_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__theutz_bitstream_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__theutz_uplink_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__vic_axon_01_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__vic_axon_02_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__vic_axon_03_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__vic_bitstream_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__vic_blade_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__vic_cortex_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:2px
  classDef user_enrich__vic_uplink_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:2px
  classDef core__users_user_dvicory_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__users_user_pol_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__users_user_theutz_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__users_user_vic_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__users_host_axon_03_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef core__utils_user_dvicory_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:3px
  classDef core__utils_user_pol_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:3px
  classDef core__utils_user_theutz_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:3px
  classDef core__utils_user_vic_c fill:#fab387,stroke:#fab387,color:#1e1e2e,stroke-width:3px
  classDef core__utils_host_axon_03_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef vic_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef disk__xfs_disk_longhorn_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence__zfs_user_dvicory_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence__zfs_user_pol_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence__zfs_user_theutz_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence__zfs_user_vic_c fill:#f2cdcd,stroke:#f2cdcd,color:#1e1e2e,stroke-width:3px
  classDef core__impermanence__zfs_host_axon_03_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef disk__zfs_diff_c fill:#89b4fa,stroke:#89b4fa,color:#1e1e2e,stroke-width:3px
  classDef disk__zfs_disk_single_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
  classDef core__perf__zram_swap_user_dvicory_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__perf__zram_swap_user_pol_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__perf__zram_swap_user_theutz_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__perf__zram_swap_user_vic_c fill:#f38ba8,stroke:#f38ba8,color:#1e1e2e,stroke-width:3px
  classDef core__perf__zram_swap_host_axon_03_c fill:#cba6f7,stroke:#cba6f7,color:#1e1e2e,stroke-width:3px
style ctx_user_sini fill:#313244,stroke:#6c7086,stroke-width:2px
style ctx_user_dvicory fill:#313244,stroke:#6c7086,stroke-width:2px
style ctx_user_pol fill:#313244,stroke:#6c7086,stroke-width:2px
style ctx_user_theutz fill:#313244,stroke:#6c7086,stroke-width:2px
style ctx_user_vic fill:#313244,stroke:#6c7086,stroke-width:2px
style ctx_host_axon_03 fill:#313244,stroke:#6c7086,stroke-width:2px
```
