# Fleet DAG

![Fleet DAG](./fleet-dag.mmd.svg)

```mermaid
%%{init: {"theme":"base","themeVariables":{"activationBkgColor":"#313244","activationBorderColor":"#6c7086","actorBkg":"#313244","actorBorder":"#a6adc8","actorLineColor":"#a6adc8","actorTextColor":"#cdd6f4","background":"#1e1e2e","classText":"#cdd6f4","clusterBkg":"#313244","clusterBorder":"#6c7086","edgeLabelBackground":"#1e1e2e","labelBoxBkgColor":"#313244","labelBoxBorderColor":"#a6adc8","labelTextColor":"#cdd6f4","lineColor":"#a6adc8","loopTextColor":"#cdd6f4","mainBkg":"#313244","nodeBkg":"#313244","nodeBorder":"#a6adc8","nodeTextColor":"#cdd6f4","noteBkgColor":"#313244","noteBorderColor":"#6c7086","noteTextColor":"#cdd6f4","pie1":"#f38ba8","pie2":"#fab387","pie3":"#f9e2af","pie4":"#a6e3a1","pie5":"#94e2d5","pie6":"#89b4fa","pie7":"#cba6f7","pie8":"#f2cdcd","pieLegendTextColor":"#cdd6f4","pieOuterStrokeColor":"#6c7086","pieSectionTextColor":"#cdd6f4","pieStrokeColor":"#6c7086","pieTitleTextColor":"#cdd6f4","primaryBorderColor":"#a6adc8","primaryColor":"#313244","primaryTextColor":"#cdd6f4","secondBkg":"#313244","secondaryBorderColor":"#6c7086","secondaryColor":"#313244","secondaryTextColor":"#cdd6f4","sequenceNumberColor":"#1e1e2e","signalColor":"#a6adc8","signalTextColor":"#cdd6f4","tertiaryBorderColor":"#6c7086","tertiaryColor":"#313244","tertiaryTextColor":"#cdd6f4","textColor":"#cdd6f4","titleColor":"#cdd6f4"}}}%%
graph LR
  subgraph env_dev["dev"]
    subgraph host_bitstream["bitstream"]
      bitstream__agenix_identity__dvicory_axon_01{{"agenix-identity/dvicory@axon-01"}}
      bitstream__agenix_identity__dvicory_axon_02{{"agenix-identity/dvicory@axon-02"}}
      bitstream__agenix_identity__dvicory_axon_03{{"agenix-identity/dvicory@axon-03"}}
      bitstream__agenix_identity__dvicory_bitstream{{"agenix-identity/dvicory@bitstream"}}
      bitstream__agenix_identity__dvicory_uplink{{"agenix-identity/dvicory@uplink"}}
      bitstream__agenix_identity__pol_axon_01{{"agenix-identity/pol@axon-01"}}
      bitstream__agenix_identity__pol_axon_02{{"agenix-identity/pol@axon-02"}}
      bitstream__agenix_identity__pol_axon_03{{"agenix-identity/pol@axon-03"}}
      bitstream__agenix_identity__pol_bitstream{{"agenix-identity/pol@bitstream"}}
      bitstream__agenix_identity__pol_uplink{{"agenix-identity/pol@uplink"}}
      bitstream__agenix_identity__sini_axon_01{{"agenix-identity/sini@axon-01"}}
      bitstream__agenix_identity__sini_axon_02{{"agenix-identity/sini@axon-02"}}
      bitstream__agenix_identity__sini_axon_03{{"agenix-identity/sini@axon-03"}}
      bitstream__agenix_identity__sini_bitstream{{"agenix-identity/sini@bitstream"}}
      bitstream__agenix_identity__sini_blade{{"agenix-identity/sini@blade"}}
      bitstream__agenix_identity__sini_cortex{{"agenix-identity/sini@cortex"}}
      bitstream__agenix_identity__sini_uplink{{"agenix-identity/sini@uplink"}}
      bitstream__agenix_identity__theutz_axon_01{{"agenix-identity/theutz@axon-01"}}
      bitstream__agenix_identity__theutz_axon_02{{"agenix-identity/theutz@axon-02"}}
      bitstream__agenix_identity__theutz_axon_03{{"agenix-identity/theutz@axon-03"}}
      bitstream__agenix_identity__theutz_bitstream{{"agenix-identity/theutz@bitstream"}}
      bitstream__agenix_identity__theutz_uplink{{"agenix-identity/theutz@uplink"}}
      bitstream__agenix_identity__vic_axon_01{{"agenix-identity/vic@axon-01"}}
      bitstream__agenix_identity__vic_axon_02{{"agenix-identity/vic@axon-02"}}
      bitstream__agenix_identity__vic_axon_03{{"agenix-identity/vic@axon-03"}}
      bitstream__agenix_identity__vic_bitstream{{"agenix-identity/vic@bitstream"}}
      bitstream__agenix_identity__vic_blade{{"agenix-identity/vic@blade"}}
      bitstream__agenix_identity__vic_cortex{{"agenix-identity/vic@cortex"}}
      bitstream__agenix_identity__vic_uplink{{"agenix-identity/vic@uplink"}}
      bitstream__agenix__bitstream{{"agenix/bitstream"}}
      bitstream__den__batteries__define_user__dvicory_bitstream{{"batteries/define-user/dvicory@bitstream"}}
      bitstream__den__batteries__define_user__pol_bitstream{{"batteries/define-user/pol@bitstream"}}
      bitstream__den__batteries__define_user__sini_bitstream{{"batteries/define-user/sini@bitstream"}}
      bitstream__den__batteries__define_user__theutz_bitstream{{"batteries/define-user/theutz@bitstream"}}
      bitstream__den__batteries__define_user__vic_bitstream{{"batteries/define-user/vic@bitstream"}}
      bitstream__den__batteries__hostname__os{{"batteries/hostname/os"}}
      bitstream__den__batteries__inputs___os{{"batteries/inputs'/os"}}
      bitstream__den__batteries__primary_user_sini_axon_01_{{"batteries/primary-user(sini@axon-01)"}}
      bitstream__den__batteries__primary_user_sini_axon_02_{{"batteries/primary-user(sini@axon-02)"}}
      bitstream__den__batteries__primary_user_sini_axon_03_{{"batteries/primary-user(sini@axon-03)"}}
      bitstream__den__batteries__primary_user_sini_bitstream_{{"batteries/primary-user(sini@bitstream)"}}
      bitstream__den__batteries__primary_user_sini_blade_{{"batteries/primary-user(sini@blade)"}}
      bitstream__den__batteries__primary_user_sini_cortex_{{"batteries/primary-user(sini@cortex)"}}
      bitstream__den__batteries__primary_user_sini_patch_{{"batteries/primary-user(sini@patch)"}}
      bitstream__den__batteries__primary_user_sini_slab_{{"batteries/primary-user(sini@slab)"}}
      bitstream__den__batteries__primary_user_sini_uplink_{{"batteries/primary-user(sini@uplink)"}}
      bitstream__den__batteries__self___os{{"batteries/self'/os"}}
      bitstream__bitstream{{"bitstream"}}
      bitstream__core__boot__network_initrd[/"boot/network-initrd"\]
      bitstream__core__impermanence_host_bitstream[/"core/impermanence"\]
      bitstream__core__impermanence_user_dvicory[/"core/impermanence"\]
      bitstream__core__impermanence_user_pol[/"core/impermanence"\]
      bitstream__core__impermanence_user_theutz[/"core/impermanence"\]
      bitstream__core__impermanence_user_vic[/"core/impermanence"\]
      bitstream__core__impermanence__btrfs_host_bitstream[/"core/impermanence/btrfs"\]
      bitstream__core__impermanence__btrfs_user_dvicory[/"core/impermanence/btrfs"\]
      bitstream__core__impermanence__btrfs_user_pol[/"core/impermanence/btrfs"\]
      bitstream__core__impermanence__btrfs_user_theutz[/"core/impermanence/btrfs"\]
      bitstream__core__impermanence__btrfs_user_vic[/"core/impermanence/btrfs"\]
      bitstream__core__impermanence__persist_collector_host_bitstream[/"core/impermanence/persist-collector"\]
      bitstream__core__impermanence__persist_collector_user_dvicory[/"core/impermanence/persist-collector"\]
      bitstream__core__impermanence__persist_collector_user_pol[/"core/impermanence/persist-collector"\]
      bitstream__core__impermanence__persist_collector_user_theutz[/"core/impermanence/persist-collector"\]
      bitstream__core__impermanence__persist_collector_user_vic[/"core/impermanence/persist-collector"\]
      bitstream__core__impermanence__zfs_host_bitstream[/"core/impermanence/zfs"\]
      bitstream__core__impermanence__zfs_user_dvicory[/"core/impermanence/zfs"\]
      bitstream__core__impermanence__zfs_user_pol[/"core/impermanence/zfs"\]
      bitstream__core__impermanence__zfs_user_theutz[/"core/impermanence/zfs"\]
      bitstream__core__impermanence__zfs_user_vic[/"core/impermanence/zfs"\]
      bitstream__core__localization__i18n_host_bitstream[/"core/localization/i18n"\]
      bitstream__core__localization__i18n_user_dvicory[/"core/localization/i18n"\]
      bitstream__core__localization__i18n_user_pol[/"core/localization/i18n"\]
      bitstream__core__localization__i18n_user_theutz[/"core/localization/i18n"\]
      bitstream__core__localization__i18n_user_vic[/"core/localization/i18n"\]
      bitstream__core__network__hostsfile_host_bitstream[/"core/network/hostsfile"\]
      bitstream__core__network__hostsfile_user_dvicory[/"core/network/hostsfile"\]
      bitstream__core__network__hostsfile_user_pol[/"core/network/hostsfile"\]
      bitstream__core__network__hostsfile_user_theutz[/"core/network/hostsfile"\]
      bitstream__core__network__hostsfile_user_vic[/"core/network/hostsfile"\]
      bitstream__core__network__networking_host_bitstream[/"core/network/networking"\]
      bitstream__core__network__networking_user_dvicory[/"core/network/networking"\]
      bitstream__core__network__networking_user_pol[/"core/network/networking"\]
      bitstream__core__network__networking_user_theutz[/"core/network/networking"\]
      bitstream__core__network__networking_user_vic[/"core/network/networking"\]
      bitstream__core__network__syncthing__peer_user_sini[/"core/network/syncthing/peer"\]
      bitstream__core__network__syncthing__peer_user_dvicory[/"core/network/syncthing/peer"\]
      bitstream__core__network__syncthing__peer_user_pol[/"core/network/syncthing/peer"\]
      bitstream__core__network__syncthing__peer_user_theutz[/"core/network/syncthing/peer"\]
      bitstream__core__network__syncthing__peer_user_vic[/"core/network/syncthing/peer"\]
      bitstream__core__network__tailscale_host_bitstream[/"core/network/tailscale"\]
      bitstream__core__network__tailscale_user_dvicory[/"core/network/tailscale"\]
      bitstream__core__network__tailscale_user_pol[/"core/network/tailscale"\]
      bitstream__core__network__tailscale_user_theutz[/"core/network/tailscale"\]
      bitstream__core__network__tailscale_user_vic[/"core/network/tailscale"\]
      bitstream__core__nix_host_bitstream[/"core/nix"\]
      bitstream__core__nix_user_dvicory[/"core/nix"\]
      bitstream__core__nix_user_pol[/"core/nix"\]
      bitstream__core__nix_user_theutz[/"core/nix"\]
      bitstream__core__nix_user_vic[/"core/nix"\]
      bitstream__core__nix__stateVersion_host_bitstream[/"core/nix/stateVersion"\]
      bitstream__core__nix__stateVersion_user_dvicory[/"core/nix/stateVersion"\]
      bitstream__core__nix__stateVersion_user_pol[/"core/nix/stateVersion"\]
      bitstream__core__nix__stateVersion_user_theutz[/"core/nix/stateVersion"\]
      bitstream__core__nix__stateVersion_user_vic[/"core/nix/stateVersion"\]
      bitstream__core__perf__disable_docs_host_bitstream[/"core/perf/disable-docs"\]
      bitstream__core__perf__disable_docs_user_dvicory[/"core/perf/disable-docs"\]
      bitstream__core__perf__disable_docs_user_pol[/"core/perf/disable-docs"\]
      bitstream__core__perf__disable_docs_user_theutz[/"core/perf/disable-docs"\]
      bitstream__core__perf__disable_docs_user_vic[/"core/perf/disable-docs"\]
      bitstream__core__perf__ssd_host_bitstream[/"core/perf/ssd"\]
      bitstream__core__perf__ssd_user_dvicory[/"core/perf/ssd"\]
      bitstream__core__perf__ssd_user_pol[/"core/perf/ssd"\]
      bitstream__core__perf__ssd_user_theutz[/"core/perf/ssd"\]
      bitstream__core__perf__ssd_user_vic[/"core/perf/ssd"\]
      bitstream__core__perf__zram_swap_host_bitstream[/"core/perf/zram-swap"\]
      bitstream__core__perf__zram_swap_user_dvicory[/"core/perf/zram-swap"\]
      bitstream__core__perf__zram_swap_user_pol[/"core/perf/zram-swap"\]
      bitstream__core__perf__zram_swap_user_theutz[/"core/perf/zram-swap"\]
      bitstream__core__perf__zram_swap_user_vic[/"core/perf/zram-swap"\]
      bitstream__core__security_host_bitstream[/"core/security"\]
      bitstream__core__security_user_dvicory[/"core/security"\]
      bitstream__core__security_user_pol[/"core/security"\]
      bitstream__core__security_user_theutz[/"core/security"\]
      bitstream__core__security_user_vic[/"core/security"\]
      bitstream__core__security__openssh_host_bitstream[/"core/security/openssh"\]
      bitstream__core__security__openssh_user_dvicory[/"core/security/openssh"\]
      bitstream__core__security__openssh_user_pol[/"core/security/openssh"\]
      bitstream__core__security__openssh_user_theutz[/"core/security/openssh"\]
      bitstream__core__security__openssh_user_vic[/"core/security/openssh"\]
      bitstream__core__security__opkssh_host_bitstream[/"core/security/opkssh"\]
      bitstream__core__security__opkssh_user_dvicory[/"core/security/opkssh"\]
      bitstream__core__security__opkssh_user_pol[/"core/security/opkssh"\]
      bitstream__core__security__opkssh_user_theutz[/"core/security/opkssh"\]
      bitstream__core__security__opkssh_user_vic[/"core/security/opkssh"\]
      bitstream__core__security__sudo_host_bitstream[/"core/security/sudo"\]
      bitstream__core__security__sudo_user_dvicory[/"core/security/sudo"\]
      bitstream__core__security__sudo_user_pol[/"core/security/sudo"\]
      bitstream__core__security__sudo_user_theutz[/"core/security/sudo"\]
      bitstream__core__security__sudo_user_vic[/"core/security/sudo"\]
      bitstream__core__system__facter_host_bitstream[/"core/system/facter"\]
      bitstream__core__system__facter_user_dvicory[/"core/system/facter"\]
      bitstream__core__system__facter_user_pol[/"core/system/facter"\]
      bitstream__core__system__facter_user_theutz[/"core/system/facter"\]
      bitstream__core__system__facter_user_vic[/"core/system/facter"\]
      bitstream__core__system__firmware_host_bitstream[/"core/system/firmware"\]
      bitstream__core__system__firmware_user_dvicory[/"core/system/firmware"\]
      bitstream__core__system__firmware_user_pol[/"core/system/firmware"\]
      bitstream__core__system__firmware_user_theutz[/"core/system/firmware"\]
      bitstream__core__system__firmware_user_vic[/"core/system/firmware"\]
      bitstream__core__system__linux_kernel_host_bitstream[/"core/system/linux-kernel"\]
      bitstream__core__system__linux_kernel_user_dvicory[/"core/system/linux-kernel"\]
      bitstream__core__system__linux_kernel_user_pol[/"core/system/linux-kernel"\]
      bitstream__core__system__linux_kernel_user_theutz[/"core/system/linux-kernel"\]
      bitstream__core__system__linux_kernel_user_vic[/"core/system/linux-kernel"\]
      bitstream__core__systemd_host_bitstream[/"core/systemd"\]
      bitstream__core__systemd_user_dvicory[/"core/systemd"\]
      bitstream__core__systemd_user_pol[/"core/systemd"\]
      bitstream__core__systemd_user_theutz[/"core/systemd"\]
      bitstream__core__systemd_user_vic[/"core/systemd"\]
      bitstream__core__systemd__boot_host_bitstream[/"core/systemd/boot"\]
      bitstream__core__systemd__boot_user_dvicory[/"core/systemd/boot"\]
      bitstream__core__systemd__boot_user_pol[/"core/systemd/boot"\]
      bitstream__core__systemd__boot_user_theutz[/"core/systemd/boot"\]
      bitstream__core__systemd__boot_user_vic[/"core/systemd/boot"\]
      bitstream__core__users_host_bitstream[/"core/users"\]
      bitstream__core__users_user_dvicory[/"core/users"\]
      bitstream__core__users_user_pol[/"core/users"\]
      bitstream__core__users_user_theutz[/"core/users"\]
      bitstream__core__users_user_vic[/"core/users"\]
      bitstream__core__users__deterministic_uids_host_bitstream[/"core/users/deterministic-uids"\]
      bitstream__core__users__deterministic_uids_user_dvicory[/"core/users/deterministic-uids"\]
      bitstream__core__users__deterministic_uids_user_pol[/"core/users/deterministic-uids"\]
      bitstream__core__users__deterministic_uids_user_theutz[/"core/users/deterministic-uids"\]
      bitstream__core__users__deterministic_uids_user_vic[/"core/users/deterministic-uids"\]
      bitstream__core__users__home_manager_shared_host_bitstream[/"core/users/home-manager-shared"\]
      bitstream__core__users__home_manager_shared_user_dvicory[/"core/users/home-manager-shared"\]
      bitstream__core__users__home_manager_shared_user_pol[/"core/users/home-manager-shared"\]
      bitstream__core__users__home_manager_shared_user_theutz[/"core/users/home-manager-shared"\]
      bitstream__core__users__home_manager_shared_user_vic[/"core/users/home-manager-shared"\]
      bitstream__core__users__shell_host_bitstream[/"core/users/shell"\]
      bitstream__core__users__shell_user_dvicory[/"core/users/shell"\]
      bitstream__core__users__shell_user_pol[/"core/users/shell"\]
      bitstream__core__users__shell_user_theutz[/"core/users/shell"\]
      bitstream__core__users__shell_user_vic[/"core/users/shell"\]
      bitstream__core__utils_host_bitstream[/"core/utils"\]
      bitstream__core__utils_user_dvicory[/"core/utils"\]
      bitstream__core__utils_user_pol[/"core/utils"\]
      bitstream__core__utils_user_theutz[/"core/utils"\]
      bitstream__core__utils_user_vic[/"core/utils"\]
      bitstream__hardware__cpu__amd[/"cpu/amd"\]
      bitstream__disk__zfs_diff[/"disk/zfs-diff"\]
      bitstream__disk__zfs_disk_single[/"disk/zfs-disk-single"\]
      bitstream__hardware__gpu__amd[/"gpu/amd"\]
      bitstream__insecure_predicate__os{{"insecure-predicate/os"}}
      bitstream__services__monitoring__prometheus_exporter[/"monitoring/prometheus-exporter"\]
      bitstream__core__network__firewall_collector[/"network/firewall-collector"\]
      bitstream__services__nix__remote_build_server[/"nix/remote-build-server"\]
      bitstream__opkssh_authz__dvicory_axon_01{{"opkssh-authz/dvicory@axon-01"}}
      bitstream__opkssh_authz__dvicory_axon_02{{"opkssh-authz/dvicory@axon-02"}}
      bitstream__opkssh_authz__dvicory_axon_03{{"opkssh-authz/dvicory@axon-03"}}
      bitstream__opkssh_authz__dvicory_bitstream{{"opkssh-authz/dvicory@bitstream"}}
      bitstream__opkssh_authz__dvicory_uplink{{"opkssh-authz/dvicory@uplink"}}
      bitstream__opkssh_authz__pol_axon_01{{"opkssh-authz/pol@axon-01"}}
      bitstream__opkssh_authz__pol_axon_02{{"opkssh-authz/pol@axon-02"}}
      bitstream__opkssh_authz__pol_axon_03{{"opkssh-authz/pol@axon-03"}}
      bitstream__opkssh_authz__pol_bitstream{{"opkssh-authz/pol@bitstream"}}
      bitstream__opkssh_authz__pol_uplink{{"opkssh-authz/pol@uplink"}}
      bitstream__opkssh_authz__sini_axon_01{{"opkssh-authz/sini@axon-01"}}
      bitstream__opkssh_authz__sini_axon_02{{"opkssh-authz/sini@axon-02"}}
      bitstream__opkssh_authz__sini_axon_03{{"opkssh-authz/sini@axon-03"}}
      bitstream__opkssh_authz__sini_bitstream{{"opkssh-authz/sini@bitstream"}}
      bitstream__opkssh_authz__sini_blade{{"opkssh-authz/sini@blade"}}
      bitstream__opkssh_authz__sini_cortex{{"opkssh-authz/sini@cortex"}}
      bitstream__opkssh_authz__sini_patch{{"opkssh-authz/sini@patch"}}
      bitstream__opkssh_authz__sini_slab{{"opkssh-authz/sini@slab"}}
      bitstream__opkssh_authz__sini_uplink{{"opkssh-authz/sini@uplink"}}
      bitstream__opkssh_authz__theutz_axon_01{{"opkssh-authz/theutz@axon-01"}}
      bitstream__opkssh_authz__theutz_axon_02{{"opkssh-authz/theutz@axon-02"}}
      bitstream__opkssh_authz__theutz_axon_03{{"opkssh-authz/theutz@axon-03"}}
      bitstream__opkssh_authz__theutz_bitstream{{"opkssh-authz/theutz@bitstream"}}
      bitstream__opkssh_authz__theutz_uplink{{"opkssh-authz/theutz@uplink"}}
      bitstream__opkssh_authz__vic_axon_01{{"opkssh-authz/vic@axon-01"}}
      bitstream__opkssh_authz__vic_axon_02{{"opkssh-authz/vic@axon-02"}}
      bitstream__opkssh_authz__vic_axon_03{{"opkssh-authz/vic@axon-03"}}
      bitstream__opkssh_authz__vic_bitstream{{"opkssh-authz/vic@bitstream"}}
      bitstream__opkssh_authz__vic_blade{{"opkssh-authz/vic@blade"}}
      bitstream__opkssh_authz__vic_cortex{{"opkssh-authz/vic@cortex"}}
      bitstream__opkssh_authz__vic_uplink{{"opkssh-authz/vic@uplink"}}
      bitstream__roles__server[/"roles/server"\]
      bitstream__core__secrets__collector[/"secrets/collector"\]
      bitstream__services__security__acme[/"security/acme"\]
      bitstream__services__security__tang[/"security/tang"\]
      bitstream__services__storage__media_data_share[/"storage/media-data-share"\]
      bitstream__unfree_predicate__os{{"unfree-predicate/os"}}
      bitstream__user_enrich__dvicory_axon_01{{"user-enrich/dvicory@axon-01"}}
      bitstream__user_enrich__dvicory_axon_02{{"user-enrich/dvicory@axon-02"}}
      bitstream__user_enrich__dvicory_axon_03{{"user-enrich/dvicory@axon-03"}}
      bitstream__user_enrich__dvicory_bitstream{{"user-enrich/dvicory@bitstream"}}
      bitstream__user_enrich__dvicory_uplink{{"user-enrich/dvicory@uplink"}}
      bitstream__user_enrich__pol_axon_01{{"user-enrich/pol@axon-01"}}
      bitstream__user_enrich__pol_axon_02{{"user-enrich/pol@axon-02"}}
      bitstream__user_enrich__pol_axon_03{{"user-enrich/pol@axon-03"}}
      bitstream__user_enrich__pol_bitstream{{"user-enrich/pol@bitstream"}}
      bitstream__user_enrich__pol_uplink{{"user-enrich/pol@uplink"}}
      bitstream__user_enrich__sini_axon_01{{"user-enrich/sini@axon-01"}}
      bitstream__user_enrich__sini_axon_02{{"user-enrich/sini@axon-02"}}
      bitstream__user_enrich__sini_axon_03{{"user-enrich/sini@axon-03"}}
      bitstream__user_enrich__sini_bitstream{{"user-enrich/sini@bitstream"}}
      bitstream__user_enrich__sini_blade{{"user-enrich/sini@blade"}}
      bitstream__user_enrich__sini_cortex{{"user-enrich/sini@cortex"}}
      bitstream__user_enrich__sini_patch{{"user-enrich/sini@patch"}}
      bitstream__user_enrich__sini_slab{{"user-enrich/sini@slab"}}
      bitstream__user_enrich__sini_uplink{{"user-enrich/sini@uplink"}}
      bitstream__user_enrich__theutz_axon_01{{"user-enrich/theutz@axon-01"}}
      bitstream__user_enrich__theutz_axon_02{{"user-enrich/theutz@axon-02"}}
      bitstream__user_enrich__theutz_axon_03{{"user-enrich/theutz@axon-03"}}
      bitstream__user_enrich__theutz_bitstream{{"user-enrich/theutz@bitstream"}}
      bitstream__user_enrich__theutz_uplink{{"user-enrich/theutz@uplink"}}
      bitstream__user_enrich__vic_axon_01{{"user-enrich/vic@axon-01"}}
      bitstream__user_enrich__vic_axon_02{{"user-enrich/vic@axon-02"}}
      bitstream__user_enrich__vic_axon_03{{"user-enrich/vic@axon-03"}}
      bitstream__user_enrich__vic_bitstream{{"user-enrich/vic@bitstream"}}
      bitstream__user_enrich__vic_blade{{"user-enrich/vic@blade"}}
      bitstream__user_enrich__vic_cortex{{"user-enrich/vic@cortex"}}
      bitstream__user_enrich__vic_uplink{{"user-enrich/vic@uplink"}}
      bitstream__disk__zfs_disk_single__root[/"zfs-disk-single/root"\]
      bitstream__bitstream --> bitstream__hardware__cpu__amd
      bitstream__bitstream --> bitstream__hardware__gpu__amd
      bitstream__bitstream --> bitstream__roles__server
      bitstream__bitstream --> bitstream__disk__zfs_disk_single
      bitstream__core__impermanence_host_bitstream --> bitstream__core__impermanence__btrfs_host_bitstream
      bitstream__core__impermanence_user_dvicory --> bitstream__core__impermanence__btrfs_user_dvicory
      bitstream__core__impermanence_user_pol --> bitstream__core__impermanence__btrfs_user_pol
      bitstream__core__impermanence_user_theutz --> bitstream__core__impermanence__btrfs_user_theutz
      bitstream__core__impermanence_user_vic --> bitstream__core__impermanence__btrfs_user_vic
      bitstream__core__impermanence_host_bitstream --> bitstream__core__impermanence__persist_collector_host_bitstream
      bitstream__core__impermanence_user_dvicory --> bitstream__core__impermanence__persist_collector_user_dvicory
      bitstream__core__impermanence_user_pol --> bitstream__core__impermanence__persist_collector_user_pol
      bitstream__core__impermanence_user_theutz --> bitstream__core__impermanence__persist_collector_user_theutz
      bitstream__core__impermanence_user_vic --> bitstream__core__impermanence__persist_collector_user_vic
      bitstream__core__impermanence_host_bitstream --> bitstream__core__impermanence__zfs_host_bitstream
      bitstream__core__impermanence_user_dvicory --> bitstream__core__impermanence__zfs_user_dvicory
      bitstream__core__impermanence_user_pol --> bitstream__core__impermanence__zfs_user_pol
      bitstream__core__impermanence_user_theutz --> bitstream__core__impermanence__zfs_user_theutz
      bitstream__core__impermanence_user_vic --> bitstream__core__impermanence__zfs_user_vic
      bitstream__disk__zfs_disk_single --> bitstream__disk__zfs_disk_single__root
      bitstream__disk__zfs_disk_single__root --> bitstream__disk__zfs_diff
      bitstream__roles__server --> bitstream__services__security__acme
      bitstream__roles__server --> bitstream__services__storage__media_data_share
      bitstream__roles__server --> bitstream__core__boot__network_initrd
      bitstream__roles__server --> bitstream__services__monitoring__prometheus_exporter
      bitstream__roles__server --> bitstream__services__security__tang
    end
    subgraph host_blade["blade"]
      blade__agenix_identity__shuo_blade{{"agenix-identity/shuo@blade"}}
      blade__agenix_identity__shuo_cortex{{"agenix-identity/shuo@cortex"}}
      blade__agenix_identity__sini_axon_01{{"agenix-identity/sini@axon-01"}}
      blade__agenix_identity__sini_axon_02{{"agenix-identity/sini@axon-02"}}
      blade__agenix_identity__sini_axon_03{{"agenix-identity/sini@axon-03"}}
      blade__agenix_identity__sini_bitstream{{"agenix-identity/sini@bitstream"}}
      blade__agenix_identity__sini_blade{{"agenix-identity/sini@blade"}}
      blade__agenix_identity__sini_cortex{{"agenix-identity/sini@cortex"}}
      blade__agenix_identity__sini_uplink{{"agenix-identity/sini@uplink"}}
      blade__agenix_identity__vic_axon_01{{"agenix-identity/vic@axon-01"}}
      blade__agenix_identity__vic_axon_02{{"agenix-identity/vic@axon-02"}}
      blade__agenix_identity__vic_axon_03{{"agenix-identity/vic@axon-03"}}
      blade__agenix_identity__vic_bitstream{{"agenix-identity/vic@bitstream"}}
      blade__agenix_identity__vic_blade{{"agenix-identity/vic@blade"}}
      blade__agenix_identity__vic_cortex{{"agenix-identity/vic@cortex"}}
      blade__agenix_identity__vic_uplink{{"agenix-identity/vic@uplink"}}
      blade__agenix_identity__will_blade{{"agenix-identity/will@blade"}}
      blade__agenix_identity__will_cortex{{"agenix-identity/will@cortex"}}
      blade__agenix__blade{{"agenix/blade"}}
      blade__applications__gaming__steam_host_blade[/"applications/gaming/steam"\]
      blade__applications__gaming__steam_user_shuo[/"applications/gaming/steam"\]
      blade__den__batteries__define_user__shuo_blade{{"batteries/define-user/shuo@blade"}}
      blade__den__batteries__define_user__sini_blade{{"batteries/define-user/sini@blade"}}
      blade__den__batteries__define_user__vic_blade{{"batteries/define-user/vic@blade"}}
      blade__den__batteries__define_user__will_blade{{"batteries/define-user/will@blade"}}
      blade__den__batteries__hostname__os{{"batteries/hostname/os"}}
      blade__den__batteries__inputs___os{{"batteries/inputs'/os"}}
      blade__den__batteries__primary_user_sini_axon_01_{{"batteries/primary-user(sini@axon-01)"}}
      blade__den__batteries__primary_user_sini_axon_02_{{"batteries/primary-user(sini@axon-02)"}}
      blade__den__batteries__primary_user_sini_axon_03_{{"batteries/primary-user(sini@axon-03)"}}
      blade__den__batteries__primary_user_sini_bitstream_{{"batteries/primary-user(sini@bitstream)"}}
      blade__den__batteries__primary_user_sini_blade_{{"batteries/primary-user(sini@blade)"}}
      blade__den__batteries__primary_user_sini_cortex_{{"batteries/primary-user(sini@cortex)"}}
      blade__den__batteries__primary_user_sini_patch_{{"batteries/primary-user(sini@patch)"}}
      blade__den__batteries__primary_user_sini_slab_{{"batteries/primary-user(sini@slab)"}}
      blade__den__batteries__primary_user_sini_uplink_{{"batteries/primary-user(sini@uplink)"}}
      blade__den__batteries__self___os{{"batteries/self'/os"}}
      blade__blade{{"blade"}}
      blade__core__boot__network_initrd[/"boot/network-initrd"\]
      blade__core__boot__wireless_initrd[/"boot/wireless-initrd"\]
      blade__core__impermanence_user_vic[/"core/impermanence"\]
      blade__core__impermanence_host_blade[/"core/impermanence"\]
      blade__core__impermanence_user_shuo[/"core/impermanence"\]
      blade__core__impermanence_user_will[/"core/impermanence"\]
      blade__core__impermanence__btrfs_user_vic[/"core/impermanence/btrfs"\]
      blade__core__impermanence__btrfs_host_blade[/"core/impermanence/btrfs"\]
      blade__core__impermanence__btrfs_user_shuo[/"core/impermanence/btrfs"\]
      blade__core__impermanence__btrfs_user_will[/"core/impermanence/btrfs"\]
      blade__core__impermanence__persist_collector_user_vic[/"core/impermanence/persist-collector"\]
      blade__core__impermanence__persist_collector_host_blade[/"core/impermanence/persist-collector"\]
      blade__core__impermanence__persist_collector_user_shuo[/"core/impermanence/persist-collector"\]
      blade__core__impermanence__persist_collector_user_will[/"core/impermanence/persist-collector"\]
      blade__core__impermanence__zfs_user_vic[/"core/impermanence/zfs"\]
      blade__core__impermanence__zfs_host_blade[/"core/impermanence/zfs"\]
      blade__core__impermanence__zfs_user_shuo[/"core/impermanence/zfs"\]
      blade__core__impermanence__zfs_user_will[/"core/impermanence/zfs"\]
      blade__core__localization__i18n_user_vic[/"core/localization/i18n"\]
      blade__core__localization__i18n_host_blade[/"core/localization/i18n"\]
      blade__core__localization__i18n_user_shuo[/"core/localization/i18n"\]
      blade__core__localization__i18n_user_will[/"core/localization/i18n"\]
      blade__core__network__hostsfile_user_vic[/"core/network/hostsfile"\]
      blade__core__network__hostsfile_host_blade[/"core/network/hostsfile"\]
      blade__core__network__hostsfile_user_shuo[/"core/network/hostsfile"\]
      blade__core__network__hostsfile_user_will[/"core/network/hostsfile"\]
      blade__core__network__networking_user_vic[/"core/network/networking"\]
      blade__core__network__networking_host_blade[/"core/network/networking"\]
      blade__core__network__networking_user_shuo[/"core/network/networking"\]
      blade__core__network__networking_user_will[/"core/network/networking"\]
      blade__core__network__syncthing__peer_user_sini[/"core/network/syncthing/peer"\]
      blade__core__network__syncthing__peer_user_vic[/"core/network/syncthing/peer"\]
      blade__core__network__syncthing__peer_user_shuo[/"core/network/syncthing/peer"\]
      blade__core__network__syncthing__peer_user_will[/"core/network/syncthing/peer"\]
      blade__core__network__tailscale_user_vic[/"core/network/tailscale"\]
      blade__core__network__tailscale_host_blade[/"core/network/tailscale"\]
      blade__core__network__tailscale_user_shuo[/"core/network/tailscale"\]
      blade__core__network__tailscale_user_will[/"core/network/tailscale"\]
      blade__core__nix_user_vic[/"core/nix"\]
      blade__core__nix_host_blade[/"core/nix"\]
      blade__core__nix_user_shuo[/"core/nix"\]
      blade__core__nix_user_will[/"core/nix"\]
      blade__core__nix__stateVersion_user_vic[/"core/nix/stateVersion"\]
      blade__core__nix__stateVersion_host_blade[/"core/nix/stateVersion"\]
      blade__core__nix__stateVersion_user_shuo[/"core/nix/stateVersion"\]
      blade__core__nix__stateVersion_user_will[/"core/nix/stateVersion"\]
      blade__core__perf__disable_docs_user_vic[/"core/perf/disable-docs"\]
      blade__core__perf__disable_docs_host_blade[/"core/perf/disable-docs"\]
      blade__core__perf__disable_docs_user_shuo[/"core/perf/disable-docs"\]
      blade__core__perf__disable_docs_user_will[/"core/perf/disable-docs"\]
      blade__core__perf__ssd_user_vic[/"core/perf/ssd"\]
      blade__core__perf__ssd_host_blade[/"core/perf/ssd"\]
      blade__core__perf__ssd_user_shuo[/"core/perf/ssd"\]
      blade__core__perf__ssd_user_will[/"core/perf/ssd"\]
      blade__core__perf__zram_swap_user_vic[/"core/perf/zram-swap"\]
      blade__core__perf__zram_swap_host_blade[/"core/perf/zram-swap"\]
      blade__core__perf__zram_swap_user_shuo[/"core/perf/zram-swap"\]
      blade__core__perf__zram_swap_user_will[/"core/perf/zram-swap"\]
      blade__core__security_user_vic[/"core/security"\]
      blade__core__security_host_blade[/"core/security"\]
      blade__core__security_user_shuo[/"core/security"\]
      blade__core__security_user_will[/"core/security"\]
      blade__core__security__openssh_user_vic[/"core/security/openssh"\]
      blade__core__security__openssh_host_blade[/"core/security/openssh"\]
      blade__core__security__openssh_user_shuo[/"core/security/openssh"\]
      blade__core__security__openssh_user_will[/"core/security/openssh"\]
      blade__core__security__opkssh_user_vic[/"core/security/opkssh"\]
      blade__core__security__opkssh_host_blade[/"core/security/opkssh"\]
      blade__core__security__opkssh_user_shuo[/"core/security/opkssh"\]
      blade__core__security__opkssh_user_will[/"core/security/opkssh"\]
      blade__core__security__sudo_user_vic[/"core/security/sudo"\]
      blade__core__security__sudo_host_blade[/"core/security/sudo"\]
      blade__core__security__sudo_user_shuo[/"core/security/sudo"\]
      blade__core__security__sudo_user_will[/"core/security/sudo"\]
      blade__core__system__facter_user_vic[/"core/system/facter"\]
      blade__core__system__facter_host_blade[/"core/system/facter"\]
      blade__core__system__facter_user_shuo[/"core/system/facter"\]
      blade__core__system__facter_user_will[/"core/system/facter"\]
      blade__core__system__firmware_user_vic[/"core/system/firmware"\]
      blade__core__system__firmware_host_blade[/"core/system/firmware"\]
      blade__core__system__firmware_user_shuo[/"core/system/firmware"\]
      blade__core__system__firmware_user_will[/"core/system/firmware"\]
      blade__core__system__linux_kernel_user_vic[/"core/system/linux-kernel"\]
      blade__core__system__linux_kernel_host_blade[/"core/system/linux-kernel"\]
      blade__core__system__linux_kernel_user_shuo[/"core/system/linux-kernel"\]
      blade__core__system__linux_kernel_user_will[/"core/system/linux-kernel"\]
      blade__core__systemd_user_vic[/"core/systemd"\]
      blade__core__systemd_host_blade[/"core/systemd"\]
      blade__core__systemd_user_shuo[/"core/systemd"\]
      blade__core__systemd_user_will[/"core/systemd"\]
      blade__core__systemd__boot_user_vic[/"core/systemd/boot"\]
      blade__core__systemd__boot_host_blade[/"core/systemd/boot"\]
      blade__core__systemd__boot_user_shuo[/"core/systemd/boot"\]
      blade__core__systemd__boot_user_will[/"core/systemd/boot"\]
      blade__core__users_user_vic[/"core/users"\]
      blade__core__users_host_blade[/"core/users"\]
      blade__core__users_user_shuo[/"core/users"\]
      blade__core__users_user_will[/"core/users"\]
      blade__core__users__deterministic_uids_user_vic[/"core/users/deterministic-uids"\]
      blade__core__users__deterministic_uids_host_blade[/"core/users/deterministic-uids"\]
      blade__core__users__deterministic_uids_user_shuo[/"core/users/deterministic-uids"\]
      blade__core__users__deterministic_uids_user_will[/"core/users/deterministic-uids"\]
      blade__core__users__home_manager_shared_user_vic[/"core/users/home-manager-shared"\]
      blade__core__users__home_manager_shared_host_blade[/"core/users/home-manager-shared"\]
      blade__core__users__home_manager_shared_user_shuo[/"core/users/home-manager-shared"\]
      blade__core__users__home_manager_shared_user_will[/"core/users/home-manager-shared"\]
      blade__core__users__shell_user_vic[/"core/users/shell"\]
      blade__core__users__shell_host_blade[/"core/users/shell"\]
      blade__core__users__shell_user_shuo[/"core/users/shell"\]
      blade__core__users__shell_user_will[/"core/users/shell"\]
      blade__core__utils_user_vic[/"core/utils"\]
      blade__core__utils_host_blade[/"core/utils"\]
      blade__core__utils_user_shuo[/"core/utils"\]
      blade__core__utils_user_will[/"core/utils"\]
      blade__hardware__cpu__intel[/"cpu/intel"\]
      blade__desktop__gdm[/"desktop/gdm"\]
      blade__desktop__gnome[/"desktop/gnome"\]
      blade__desktop__uwsm[/"desktop/uwsm"\]
      blade__desktop__xdg_portal[/"desktop/xdg-portal"\]
      blade__desktop__xserver[/"desktop/xserver"\]
      blade__desktop__xwayland[/"desktop/xwayland"\]
      blade__disk__zfs_diff[/"disk/zfs-diff"\]
      blade__disk__zfs_disk_single[/"disk/zfs-disk-single"\]
      blade__desktop__style__fonts__nerd_fonts[/"fonts/nerd-fonts"\]
      blade__desktop__style__fonts__regular[/"fonts/regular"\]
      blade__applications__gaming__emulation[/"gaming/emulation"\]
      blade__applications__gaming__nix_ld[/"gaming/nix-ld"\]
      blade__applications__gaming__sunshine[/"gaming/sunshine"\]
      blade__hardware__gpu__intel[/"gpu/intel"\]
      blade__hardware__gpu__nvidia[/"gpu/nvidia"\]
      blade__hardware__gpu__nvidia_prime[/"gpu/nvidia-prime"\]
      blade__hardware__adb[/"hardware/adb"\]
      blade__hardware__audio[/"hardware/audio"\]
      blade__hardware__bluetooth[/"hardware/bluetooth"\]
      blade__hardware__coolercontrol[/"hardware/coolercontrol"\]
      blade__hardware__ddcutil[/"hardware/ddcutil"\]
      blade__hardware__gamepad[/"hardware/gamepad"\]
      blade__hardware__keyboard[/"hardware/keyboard"\]
      blade__hardware__laptop[/"hardware/laptop"\]
      blade__hardware__performance[/"hardware/performance"\]
      blade__hardware__razer[/"hardware/razer"\]
      blade__host__resolve_dev_gui_["host/resolve(dev-gui)"]
      blade__insecure_predicate__os{{"insecure-predicate/os"}}
      blade__applications__messaging__kdeconnect[/"messaging/kdeconnect"\]
      blade__applications__dev__mux__herdr_pair[/"mux/herdr-pair"\]
      blade__core__network__firewall_collector[/"network/firewall-collector"\]
      blade__core__network__manager[/"network/manager"\]
      blade__opkssh_authz__shuo_blade{{"opkssh-authz/shuo@blade"}}
      blade__opkssh_authz__shuo_cortex{{"opkssh-authz/shuo@cortex"}}
      blade__opkssh_authz__sini_axon_01{{"opkssh-authz/sini@axon-01"}}
      blade__opkssh_authz__sini_axon_02{{"opkssh-authz/sini@axon-02"}}
      blade__opkssh_authz__sini_axon_03{{"opkssh-authz/sini@axon-03"}}
      blade__opkssh_authz__sini_bitstream{{"opkssh-authz/sini@bitstream"}}
      blade__opkssh_authz__sini_blade{{"opkssh-authz/sini@blade"}}
      blade__opkssh_authz__sini_cortex{{"opkssh-authz/sini@cortex"}}
      blade__opkssh_authz__sini_patch{{"opkssh-authz/sini@patch"}}
      blade__opkssh_authz__sini_slab{{"opkssh-authz/sini@slab"}}
      blade__opkssh_authz__sini_uplink{{"opkssh-authz/sini@uplink"}}
      blade__opkssh_authz__vic_axon_01{{"opkssh-authz/vic@axon-01"}}
      blade__opkssh_authz__vic_axon_02{{"opkssh-authz/vic@axon-02"}}
      blade__opkssh_authz__vic_axon_03{{"opkssh-authz/vic@axon-03"}}
      blade__opkssh_authz__vic_bitstream{{"opkssh-authz/vic@bitstream"}}
      blade__opkssh_authz__vic_blade{{"opkssh-authz/vic@blade"}}
      blade__opkssh_authz__vic_cortex{{"opkssh-authz/vic@cortex"}}
      blade__opkssh_authz__vic_uplink{{"opkssh-authz/vic@uplink"}}
      blade__opkssh_authz__will_blade{{"opkssh-authz/will@blade"}}
      blade__opkssh_authz__will_cortex{{"opkssh-authz/will@cortex"}}
      blade__den__provides__unfree_antigravity_{{"provides/unfree(antigravity)"}}
      blade__den__provides__unfree_corefonts_vista_fonts_{{"provides/unfree(corefonts,vista-fonts)"}}
      blade__core__secrets__collector[/"secrets/collector"\]
      blade__desktop__style__fonts[/"style/fonts"\]
      blade__desktop__style__stylix[/"style/stylix"\]
      blade__unfree_predicate__os{{"unfree-predicate/os"}}
      blade__user_enrich__shuo_blade{{"user-enrich/shuo@blade"}}
      blade__user_enrich__shuo_cortex{{"user-enrich/shuo@cortex"}}
      blade__user_enrich__sini_axon_01{{"user-enrich/sini@axon-01"}}
      blade__user_enrich__sini_axon_02{{"user-enrich/sini@axon-02"}}
      blade__user_enrich__sini_axon_03{{"user-enrich/sini@axon-03"}}
      blade__user_enrich__sini_bitstream{{"user-enrich/sini@bitstream"}}
      blade__user_enrich__sini_blade{{"user-enrich/sini@blade"}}
      blade__user_enrich__sini_cortex{{"user-enrich/sini@cortex"}}
      blade__user_enrich__sini_patch{{"user-enrich/sini@patch"}}
      blade__user_enrich__sini_slab{{"user-enrich/sini@slab"}}
      blade__user_enrich__sini_uplink{{"user-enrich/sini@uplink"}}
      blade__user_enrich__vic_axon_01{{"user-enrich/vic@axon-01"}}
      blade__user_enrich__vic_axon_02{{"user-enrich/vic@axon-02"}}
      blade__user_enrich__vic_axon_03{{"user-enrich/vic@axon-03"}}
      blade__user_enrich__vic_bitstream{{"user-enrich/vic@bitstream"}}
      blade__user_enrich__vic_blade{{"user-enrich/vic@blade"}}
      blade__user_enrich__vic_cortex{{"user-enrich/vic@cortex"}}
      blade__user_enrich__vic_uplink{{"user-enrich/vic@uplink"}}
      blade__user_enrich__will_blade{{"user-enrich/will@blade"}}
      blade__user_enrich__will_cortex{{"user-enrich/will@cortex"}}
      blade__virtualization__libvirt[/"virtualization/libvirt"\]
      blade__disk__zfs_disk_single__root[/"zfs-disk-single/root"\]
      blade__blade --> blade__applications__dev__mux__herdr_pair
      blade__blade --> blade__hardware__cpu__intel
      blade__blade --> blade__hardware__gpu__intel
      blade__blade --> blade__hardware__laptop
      blade__blade --> blade__core__network__manager
      blade__blade --> blade__hardware__gpu__nvidia
      blade__blade --> blade__hardware__gpu__nvidia_prime
      blade__blade --> blade__hardware__performance
      blade__blade --> blade__hardware__razer
      blade__blade --> blade__desktop__uwsm
      blade__blade --> blade__core__boot__wireless_initrd
      blade__blade --> blade__disk__zfs_disk_single
      blade__core__boot__wireless_initrd --> blade__core__boot__network_initrd
      blade__core__impermanence_user_vic --> blade__core__impermanence__btrfs_user_vic
      blade__core__impermanence_host_blade --> blade__core__impermanence__btrfs_host_blade
      blade__core__impermanence_user_shuo --> blade__core__impermanence__btrfs_user_shuo
      blade__core__impermanence_user_will --> blade__core__impermanence__btrfs_user_will
      blade__core__impermanence_user_vic --> blade__core__impermanence__persist_collector_user_vic
      blade__core__impermanence_host_blade --> blade__core__impermanence__persist_collector_host_blade
      blade__core__impermanence_user_shuo --> blade__core__impermanence__persist_collector_user_shuo
      blade__core__impermanence_user_will --> blade__core__impermanence__persist_collector_user_will
      blade__core__impermanence_user_vic --> blade__core__impermanence__zfs_user_vic
      blade__core__impermanence_host_blade --> blade__core__impermanence__zfs_host_blade
      blade__core__impermanence_user_shuo --> blade__core__impermanence__zfs_user_shuo
      blade__core__impermanence_user_will --> blade__core__impermanence__zfs_user_will
      blade__desktop__style__fonts --> blade__desktop__style__fonts__nerd_fonts
      blade__desktop__style__fonts --> blade__desktop__style__fonts__regular
      blade__desktop__style__fonts__regular --> blade__den__provides__unfree_corefonts_vista_fonts_
      blade__disk__zfs_disk_single --> blade__disk__zfs_disk_single__root
      blade__disk__zfs_disk_single__root --> blade__disk__zfs_diff
    end
    subgraph host_cortex["cortex"]
      cortex__agenix_identity__shuo_blade{{"agenix-identity/shuo@blade"}}
      cortex__agenix_identity__shuo_cortex{{"agenix-identity/shuo@cortex"}}
      cortex__agenix_identity__sini_axon_01{{"agenix-identity/sini@axon-01"}}
      cortex__agenix_identity__sini_axon_02{{"agenix-identity/sini@axon-02"}}
      cortex__agenix_identity__sini_axon_03{{"agenix-identity/sini@axon-03"}}
      cortex__agenix_identity__sini_bitstream{{"agenix-identity/sini@bitstream"}}
      cortex__agenix_identity__sini_blade{{"agenix-identity/sini@blade"}}
      cortex__agenix_identity__sini_cortex{{"agenix-identity/sini@cortex"}}
      cortex__agenix_identity__sini_uplink{{"agenix-identity/sini@uplink"}}
      cortex__agenix_identity__vic_axon_01{{"agenix-identity/vic@axon-01"}}
      cortex__agenix_identity__vic_axon_02{{"agenix-identity/vic@axon-02"}}
      cortex__agenix_identity__vic_axon_03{{"agenix-identity/vic@axon-03"}}
      cortex__agenix_identity__vic_bitstream{{"agenix-identity/vic@bitstream"}}
      cortex__agenix_identity__vic_blade{{"agenix-identity/vic@blade"}}
      cortex__agenix_identity__vic_cortex{{"agenix-identity/vic@cortex"}}
      cortex__agenix_identity__vic_uplink{{"agenix-identity/vic@uplink"}}
      cortex__agenix_identity__will_blade{{"agenix-identity/will@blade"}}
      cortex__agenix_identity__will_cortex{{"agenix-identity/will@cortex"}}
      cortex__agenix__cortex{{"agenix/cortex"}}
      cortex__services__ai__ollama[/"ai/ollama"\]
      cortex__applications__gaming__steam_user_shuo[/"applications/gaming/steam"\]
      cortex__applications__gaming__steam_host_cortex[/"applications/gaming/steam"\]
      cortex__den__batteries__define_user__shuo_cortex{{"batteries/define-user/shuo@cortex"}}
      cortex__den__batteries__define_user__sini_cortex{{"batteries/define-user/sini@cortex"}}
      cortex__den__batteries__define_user__vic_cortex{{"batteries/define-user/vic@cortex"}}
      cortex__den__batteries__define_user__will_cortex{{"batteries/define-user/will@cortex"}}
      cortex__den__batteries__hostname__os{{"batteries/hostname/os"}}
      cortex__den__batteries__inputs___os{{"batteries/inputs'/os"}}
      cortex__den__batteries__primary_user_sini_axon_01_{{"batteries/primary-user(sini@axon-01)"}}
      cortex__den__batteries__primary_user_sini_axon_02_{{"batteries/primary-user(sini@axon-02)"}}
      cortex__den__batteries__primary_user_sini_axon_03_{{"batteries/primary-user(sini@axon-03)"}}
      cortex__den__batteries__primary_user_sini_bitstream_{{"batteries/primary-user(sini@bitstream)"}}
      cortex__den__batteries__primary_user_sini_blade_{{"batteries/primary-user(sini@blade)"}}
      cortex__den__batteries__primary_user_sini_cortex_{{"batteries/primary-user(sini@cortex)"}}
      cortex__den__batteries__primary_user_sini_patch_{{"batteries/primary-user(sini@patch)"}}
      cortex__den__batteries__primary_user_sini_slab_{{"batteries/primary-user(sini@slab)"}}
      cortex__den__batteries__primary_user_sini_uplink_{{"batteries/primary-user(sini@uplink)"}}
      cortex__den__batteries__self___os{{"batteries/self'/os"}}
      cortex__core__boot__network_initrd[/"boot/network-initrd"\]
      cortex__core__impermanence_user_vic[/"core/impermanence"\]
      cortex__core__impermanence_user_shuo[/"core/impermanence"\]
      cortex__core__impermanence_user_will[/"core/impermanence"\]
      cortex__core__impermanence_host_cortex[/"core/impermanence"\]
      cortex__core__impermanence__btrfs_user_vic[/"core/impermanence/btrfs"\]
      cortex__core__impermanence__btrfs_user_shuo[/"core/impermanence/btrfs"\]
      cortex__core__impermanence__btrfs_user_will[/"core/impermanence/btrfs"\]
      cortex__core__impermanence__btrfs_host_cortex[/"core/impermanence/btrfs"\]
      cortex__core__impermanence__persist_collector_user_vic[/"core/impermanence/persist-collector"\]
      cortex__core__impermanence__persist_collector_user_shuo[/"core/impermanence/persist-collector"\]
      cortex__core__impermanence__persist_collector_user_will[/"core/impermanence/persist-collector"\]
      cortex__core__impermanence__persist_collector_host_cortex[/"core/impermanence/persist-collector"\]
      cortex__core__impermanence__zfs_user_vic[/"core/impermanence/zfs"\]
      cortex__core__impermanence__zfs_user_shuo[/"core/impermanence/zfs"\]
      cortex__core__impermanence__zfs_user_will[/"core/impermanence/zfs"\]
      cortex__core__impermanence__zfs_host_cortex[/"core/impermanence/zfs"\]
      cortex__core__localization__i18n_user_vic[/"core/localization/i18n"\]
      cortex__core__localization__i18n_user_shuo[/"core/localization/i18n"\]
      cortex__core__localization__i18n_user_will[/"core/localization/i18n"\]
      cortex__core__localization__i18n_host_cortex[/"core/localization/i18n"\]
      cortex__core__network__hostsfile_user_vic[/"core/network/hostsfile"\]
      cortex__core__network__hostsfile_user_shuo[/"core/network/hostsfile"\]
      cortex__core__network__hostsfile_user_will[/"core/network/hostsfile"\]
      cortex__core__network__hostsfile_host_cortex[/"core/network/hostsfile"\]
      cortex__core__network__networking_user_vic[/"core/network/networking"\]
      cortex__core__network__networking_user_shuo[/"core/network/networking"\]
      cortex__core__network__networking_user_will[/"core/network/networking"\]
      cortex__core__network__networking_host_cortex[/"core/network/networking"\]
      cortex__core__network__syncthing__peer_user_sini[/"core/network/syncthing/peer"\]
      cortex__core__network__syncthing__peer_user_vic[/"core/network/syncthing/peer"\]
      cortex__core__network__syncthing__peer_user_shuo[/"core/network/syncthing/peer"\]
      cortex__core__network__syncthing__peer_user_will[/"core/network/syncthing/peer"\]
      cortex__core__network__tailscale_user_vic[/"core/network/tailscale"\]
      cortex__core__network__tailscale_user_shuo[/"core/network/tailscale"\]
      cortex__core__network__tailscale_user_will[/"core/network/tailscale"\]
      cortex__core__network__tailscale_host_cortex[/"core/network/tailscale"\]
      cortex__core__nix_user_vic[/"core/nix"\]
      cortex__core__nix_user_shuo[/"core/nix"\]
      cortex__core__nix_user_will[/"core/nix"\]
      cortex__core__nix_host_cortex[/"core/nix"\]
      cortex__core__nix__stateVersion_user_vic[/"core/nix/stateVersion"\]
      cortex__core__nix__stateVersion_user_shuo[/"core/nix/stateVersion"\]
      cortex__core__nix__stateVersion_user_will[/"core/nix/stateVersion"\]
      cortex__core__nix__stateVersion_host_cortex[/"core/nix/stateVersion"\]
      cortex__core__perf__disable_docs_user_vic[/"core/perf/disable-docs"\]
      cortex__core__perf__disable_docs_user_shuo[/"core/perf/disable-docs"\]
      cortex__core__perf__disable_docs_user_will[/"core/perf/disable-docs"\]
      cortex__core__perf__disable_docs_host_cortex[/"core/perf/disable-docs"\]
      cortex__core__perf__ssd_user_vic[/"core/perf/ssd"\]
      cortex__core__perf__ssd_user_shuo[/"core/perf/ssd"\]
      cortex__core__perf__ssd_user_will[/"core/perf/ssd"\]
      cortex__core__perf__ssd_host_cortex[/"core/perf/ssd"\]
      cortex__core__perf__zram_swap_user_vic[/"core/perf/zram-swap"\]
      cortex__core__perf__zram_swap_user_shuo[/"core/perf/zram-swap"\]
      cortex__core__perf__zram_swap_user_will[/"core/perf/zram-swap"\]
      cortex__core__perf__zram_swap_host_cortex[/"core/perf/zram-swap"\]
      cortex__core__security_user_vic[/"core/security"\]
      cortex__core__security_user_shuo[/"core/security"\]
      cortex__core__security_user_will[/"core/security"\]
      cortex__core__security_host_cortex[/"core/security"\]
      cortex__core__security__openssh_user_vic[/"core/security/openssh"\]
      cortex__core__security__openssh_user_shuo[/"core/security/openssh"\]
      cortex__core__security__openssh_user_will[/"core/security/openssh"\]
      cortex__core__security__openssh_host_cortex[/"core/security/openssh"\]
      cortex__core__security__opkssh_user_vic[/"core/security/opkssh"\]
      cortex__core__security__opkssh_user_shuo[/"core/security/opkssh"\]
      cortex__core__security__opkssh_user_will[/"core/security/opkssh"\]
      cortex__core__security__opkssh_host_cortex[/"core/security/opkssh"\]
      cortex__core__security__sudo_user_vic[/"core/security/sudo"\]
      cortex__core__security__sudo_user_shuo[/"core/security/sudo"\]
      cortex__core__security__sudo_user_will[/"core/security/sudo"\]
      cortex__core__security__sudo_host_cortex[/"core/security/sudo"\]
      cortex__core__system__facter_user_vic[/"core/system/facter"\]
      cortex__core__system__facter_user_shuo[/"core/system/facter"\]
      cortex__core__system__facter_user_will[/"core/system/facter"\]
      cortex__core__system__facter_host_cortex[/"core/system/facter"\]
      cortex__core__system__firmware_user_vic[/"core/system/firmware"\]
      cortex__core__system__firmware_user_shuo[/"core/system/firmware"\]
      cortex__core__system__firmware_user_will[/"core/system/firmware"\]
      cortex__core__system__firmware_host_cortex[/"core/system/firmware"\]
      cortex__core__system__linux_kernel_user_vic[/"core/system/linux-kernel"\]
      cortex__core__system__linux_kernel_user_shuo[/"core/system/linux-kernel"\]
      cortex__core__system__linux_kernel_user_will[/"core/system/linux-kernel"\]
      cortex__core__system__linux_kernel_host_cortex[/"core/system/linux-kernel"\]
      cortex__core__systemd_user_vic[/"core/systemd"\]
      cortex__core__systemd_user_shuo[/"core/systemd"\]
      cortex__core__systemd_user_will[/"core/systemd"\]
      cortex__core__systemd_host_cortex[/"core/systemd"\]
      cortex__core__systemd__boot_user_vic[/"core/systemd/boot"\]
      cortex__core__systemd__boot_user_shuo[/"core/systemd/boot"\]
      cortex__core__systemd__boot_user_will[/"core/systemd/boot"\]
      cortex__core__systemd__boot_host_cortex[/"core/systemd/boot"\]
      cortex__core__users_user_vic[/"core/users"\]
      cortex__core__users_user_shuo[/"core/users"\]
      cortex__core__users_user_will[/"core/users"\]
      cortex__core__users_host_cortex[/"core/users"\]
      cortex__core__users__deterministic_uids_user_vic[/"core/users/deterministic-uids"\]
      cortex__core__users__deterministic_uids_user_shuo[/"core/users/deterministic-uids"\]
      cortex__core__users__deterministic_uids_user_will[/"core/users/deterministic-uids"\]
      cortex__core__users__deterministic_uids_host_cortex[/"core/users/deterministic-uids"\]
      cortex__core__users__home_manager_shared_user_vic[/"core/users/home-manager-shared"\]
      cortex__core__users__home_manager_shared_user_shuo[/"core/users/home-manager-shared"\]
      cortex__core__users__home_manager_shared_user_will[/"core/users/home-manager-shared"\]
      cortex__core__users__home_manager_shared_host_cortex[/"core/users/home-manager-shared"\]
      cortex__core__users__shell_user_vic[/"core/users/shell"\]
      cortex__core__users__shell_user_shuo[/"core/users/shell"\]
      cortex__core__users__shell_user_will[/"core/users/shell"\]
      cortex__core__users__shell_host_cortex[/"core/users/shell"\]
      cortex__core__utils_user_vic[/"core/utils"\]
      cortex__core__utils_user_shuo[/"core/utils"\]
      cortex__core__utils_user_will[/"core/utils"\]
      cortex__core__utils_host_cortex[/"core/utils"\]
      cortex__cortex{{"cortex"}}
      cortex__hardware__cpu__amd[/"cpu/amd"\]
      cortex__desktop__gdm[/"desktop/gdm"\]
      cortex__desktop__gnome[/"desktop/gnome"\]
      cortex__desktop__uwsm[/"desktop/uwsm"\]
      cortex__desktop__xdg_portal[/"desktop/xdg-portal"\]
      cortex__desktop__xserver[/"desktop/xserver"\]
      cortex__desktop__xwayland[/"desktop/xwayland"\]
      cortex__disk__zfs_diff[/"disk/zfs-diff"\]
      cortex__disk__zfs_disk_single[/"disk/zfs-disk-single"\]
      cortex__desktop__style__fonts__nerd_fonts[/"fonts/nerd-fonts"\]
      cortex__desktop__style__fonts__regular[/"fonts/regular"\]
      cortex__applications__gaming__emulation[/"gaming/emulation"\]
      cortex__applications__gaming__nix_ld[/"gaming/nix-ld"\]
      cortex__applications__gaming__sunshine[/"gaming/sunshine"\]
      cortex__hardware__gpu__amd[/"gpu/amd"\]
      cortex__hardware__gpu__nvidia_vfio[/"gpu/nvidia-vfio"\]
      cortex__hardware__adb[/"hardware/adb"\]
      cortex__hardware__audio[/"hardware/audio"\]
      cortex__hardware__bluetooth[/"hardware/bluetooth"\]
      cortex__hardware__coolercontrol[/"hardware/coolercontrol"\]
      cortex__hardware__ddcutil[/"hardware/ddcutil"\]
      cortex__hardware__gamepad[/"hardware/gamepad"\]
      cortex__hardware__keyboard[/"hardware/keyboard"\]
      cortex__hardware__performance[/"hardware/performance"\]
      cortex__hardware__vr_amd[/"hardware/vr-amd"\]
      cortex__host__resolve_dev_gui_["host/resolve(dev-gui)"]
      cortex__insecure_predicate__os{{"insecure-predicate/os"}}
      cortex__applications__media__easyeffects[/"media/easyeffects"\]
      cortex__applications__messaging__kdeconnect[/"messaging/kdeconnect"\]
      cortex__core__network__firewall_collector[/"network/firewall-collector"\]
      cortex__services__nix__remote_build_server[/"nix/remote-build-server"\]
      cortex__opkssh_authz__shuo_blade{{"opkssh-authz/shuo@blade"}}
      cortex__opkssh_authz__shuo_cortex{{"opkssh-authz/shuo@cortex"}}
      cortex__opkssh_authz__sini_axon_01{{"opkssh-authz/sini@axon-01"}}
      cortex__opkssh_authz__sini_axon_02{{"opkssh-authz/sini@axon-02"}}
      cortex__opkssh_authz__sini_axon_03{{"opkssh-authz/sini@axon-03"}}
      cortex__opkssh_authz__sini_bitstream{{"opkssh-authz/sini@bitstream"}}
      cortex__opkssh_authz__sini_blade{{"opkssh-authz/sini@blade"}}
      cortex__opkssh_authz__sini_cortex{{"opkssh-authz/sini@cortex"}}
      cortex__opkssh_authz__sini_patch{{"opkssh-authz/sini@patch"}}
      cortex__opkssh_authz__sini_slab{{"opkssh-authz/sini@slab"}}
      cortex__opkssh_authz__sini_uplink{{"opkssh-authz/sini@uplink"}}
      cortex__opkssh_authz__vic_axon_01{{"opkssh-authz/vic@axon-01"}}
      cortex__opkssh_authz__vic_axon_02{{"opkssh-authz/vic@axon-02"}}
      cortex__opkssh_authz__vic_axon_03{{"opkssh-authz/vic@axon-03"}}
      cortex__opkssh_authz__vic_bitstream{{"opkssh-authz/vic@bitstream"}}
      cortex__opkssh_authz__vic_blade{{"opkssh-authz/vic@blade"}}
      cortex__opkssh_authz__vic_cortex{{"opkssh-authz/vic@cortex"}}
      cortex__opkssh_authz__vic_uplink{{"opkssh-authz/vic@uplink"}}
      cortex__opkssh_authz__will_blade{{"opkssh-authz/will@blade"}}
      cortex__opkssh_authz__will_cortex{{"opkssh-authz/will@cortex"}}
      cortex__den__provides__unfree_antigravity_{{"provides/unfree(antigravity)"}}
      cortex__den__provides__unfree_corefonts_vista_fonts_{{"provides/unfree(corefonts,vista-fonts)"}}
      cortex__core__secrets__collector[/"secrets/collector"\]
      cortex__services__storage__media_data_share[/"storage/media-data-share"\]
      cortex__desktop__style__fonts[/"style/fonts"\]
      cortex__desktop__style__stylix[/"style/stylix"\]
      cortex__unfree_predicate__os{{"unfree-predicate/os"}}
      cortex__user_enrich__shuo_blade{{"user-enrich/shuo@blade"}}
      cortex__user_enrich__shuo_cortex{{"user-enrich/shuo@cortex"}}
      cortex__user_enrich__sini_axon_01{{"user-enrich/sini@axon-01"}}
      cortex__user_enrich__sini_axon_02{{"user-enrich/sini@axon-02"}}
      cortex__user_enrich__sini_axon_03{{"user-enrich/sini@axon-03"}}
      cortex__user_enrich__sini_bitstream{{"user-enrich/sini@bitstream"}}
      cortex__user_enrich__sini_blade{{"user-enrich/sini@blade"}}
      cortex__user_enrich__sini_cortex{{"user-enrich/sini@cortex"}}
      cortex__user_enrich__sini_patch{{"user-enrich/sini@patch"}}
      cortex__user_enrich__sini_slab{{"user-enrich/sini@slab"}}
      cortex__user_enrich__sini_uplink{{"user-enrich/sini@uplink"}}
      cortex__user_enrich__vic_axon_01{{"user-enrich/vic@axon-01"}}
      cortex__user_enrich__vic_axon_02{{"user-enrich/vic@axon-02"}}
      cortex__user_enrich__vic_axon_03{{"user-enrich/vic@axon-03"}}
      cortex__user_enrich__vic_bitstream{{"user-enrich/vic@bitstream"}}
      cortex__user_enrich__vic_blade{{"user-enrich/vic@blade"}}
      cortex__user_enrich__vic_cortex{{"user-enrich/vic@cortex"}}
      cortex__user_enrich__vic_uplink{{"user-enrich/vic@uplink"}}
      cortex__user_enrich__will_blade{{"user-enrich/will@blade"}}
      cortex__user_enrich__will_cortex{{"user-enrich/will@cortex"}}
      cortex__virtualization__libvirt[/"virtualization/libvirt"\]
      cortex__virtualization__microvm_host[/"virtualization/microvm-host"\]
      cortex__virtualization__podman[/"virtualization/podman"\]
      cortex__virtualization__windows_vfio[/"virtualization/windows-vfio"\]
      cortex__disk__zfs_disk_single__root[/"zfs-disk-single/root"\]
      cortex__core__impermanence_user_vic --> cortex__core__impermanence__btrfs_user_vic
      cortex__core__impermanence_user_shuo --> cortex__core__impermanence__btrfs_user_shuo
      cortex__core__impermanence_user_will --> cortex__core__impermanence__btrfs_user_will
      cortex__core__impermanence_host_cortex --> cortex__core__impermanence__btrfs_host_cortex
      cortex__core__impermanence_user_vic --> cortex__core__impermanence__persist_collector_user_vic
      cortex__core__impermanence_user_shuo --> cortex__core__impermanence__persist_collector_user_shuo
      cortex__core__impermanence_user_will --> cortex__core__impermanence__persist_collector_user_will
      cortex__core__impermanence_host_cortex --> cortex__core__impermanence__persist_collector_host_cortex
      cortex__core__impermanence_user_vic --> cortex__core__impermanence__zfs_user_vic
      cortex__core__impermanence_user_shuo --> cortex__core__impermanence__zfs_user_shuo
      cortex__core__impermanence_user_will --> cortex__core__impermanence__zfs_user_will
      cortex__core__impermanence_host_cortex --> cortex__core__impermanence__zfs_host_cortex
      cortex__cortex --> cortex__hardware__cpu__amd
      cortex__cortex --> cortex__hardware__gpu__amd
      cortex__cortex --> cortex__applications__media__easyeffects
      cortex__cortex --> cortex__services__storage__media_data_share
      cortex__cortex --> cortex__virtualization__microvm_host
      cortex__cortex --> cortex__core__boot__network_initrd
      cortex__cortex --> cortex__hardware__gpu__nvidia_vfio
      cortex__cortex --> cortex__hardware__performance
      cortex__cortex --> cortex__virtualization__podman
      cortex__cortex --> cortex__desktop__uwsm
      cortex__cortex --> cortex__hardware__vr_amd
      cortex__cortex --> cortex__virtualization__windows_vfio
      cortex__cortex --> cortex__disk__zfs_disk_single
      cortex__desktop__style__fonts --> cortex__desktop__style__fonts__nerd_fonts
      cortex__desktop__style__fonts --> cortex__desktop__style__fonts__regular
      cortex__desktop__style__fonts__regular --> cortex__den__provides__unfree_corefonts_vista_fonts_
      cortex__disk__zfs_disk_single --> cortex__disk__zfs_disk_single__root
      cortex__disk__zfs_disk_single__root --> cortex__disk__zfs_diff
    end
    subgraph host_patch["patch"]
      patch__agenix_identity__sini_axon_01{{"agenix-identity/sini@axon-01"}}
      patch__agenix_identity__sini_axon_02{{"agenix-identity/sini@axon-02"}}
      patch__agenix_identity__sini_axon_03{{"agenix-identity/sini@axon-03"}}
      patch__agenix_identity__sini_bitstream{{"agenix-identity/sini@bitstream"}}
      patch__agenix_identity__sini_blade{{"agenix-identity/sini@blade"}}
      patch__agenix_identity__sini_cortex{{"agenix-identity/sini@cortex"}}
      patch__agenix_identity__sini_uplink{{"agenix-identity/sini@uplink"}}
      patch__den__batteries__define_user__sini_patch{{"batteries/define-user/sini@patch"}}
      patch__den__batteries__primary_user_sini_axon_01_{{"batteries/primary-user(sini@axon-01)"}}
      patch__den__batteries__primary_user_sini_axon_02_{{"batteries/primary-user(sini@axon-02)"}}
      patch__den__batteries__primary_user_sini_axon_03_{{"batteries/primary-user(sini@axon-03)"}}
      patch__den__batteries__primary_user_sini_bitstream_{{"batteries/primary-user(sini@bitstream)"}}
      patch__den__batteries__primary_user_sini_blade_{{"batteries/primary-user(sini@blade)"}}
      patch__den__batteries__primary_user_sini_cortex_{{"batteries/primary-user(sini@cortex)"}}
      patch__den__batteries__primary_user_sini_patch_{{"batteries/primary-user(sini@patch)"}}
      patch__den__batteries__primary_user_sini_slab_{{"batteries/primary-user(sini@slab)"}}
      patch__den__batteries__primary_user_sini_uplink_{{"batteries/primary-user(sini@uplink)"}}
      patch__core__impermanence[/"core/impermanence"\]
      patch__core__nix[/"core/nix"\]
      patch__core__security[/"core/security"\]
      patch__core__systemd[/"core/systemd"\]
      patch__core__users[/"core/users"\]
      patch__core__utils[/"core/utils"\]
      patch__hardware__adb[/"hardware/adb"\]
      patch__host__resolve_darwin_workstation_["host/resolve(darwin-workstation)"]
      patch__core__impermanence__btrfs[/"impermanence/btrfs"\]
      patch__core__impermanence__persist_collector[/"impermanence/persist-collector"\]
      patch__core__impermanence__zfs[/"impermanence/zfs"\]
      patch__core__localization__i18n[/"localization/i18n"\]
      patch__core__network__firewall_collector[/"network/firewall-collector"\]
      patch__core__network__hostsfile[/"network/hostsfile"\]
      patch__core__network__networking[/"network/networking"\]
      patch__core__network__tailscale[/"network/tailscale"\]
      patch__core__nix__stateVersion[/"nix/stateVersion"\]
      patch__opkssh_authz__sini_axon_01{{"opkssh-authz/sini@axon-01"}}
      patch__opkssh_authz__sini_axon_02{{"opkssh-authz/sini@axon-02"}}
      patch__opkssh_authz__sini_axon_03{{"opkssh-authz/sini@axon-03"}}
      patch__opkssh_authz__sini_bitstream{{"opkssh-authz/sini@bitstream"}}
      patch__opkssh_authz__sini_blade{{"opkssh-authz/sini@blade"}}
      patch__opkssh_authz__sini_cortex{{"opkssh-authz/sini@cortex"}}
      patch__opkssh_authz__sini_patch{{"opkssh-authz/sini@patch"}}
      patch__opkssh_authz__sini_slab{{"opkssh-authz/sini@slab"}}
      patch__opkssh_authz__sini_uplink{{"opkssh-authz/sini@uplink"}}
      patch__core__perf__disable_docs[/"perf/disable-docs"\]
      patch__core__perf__ssd[/"perf/ssd"\]
      patch__core__perf__zram_swap[/"perf/zram-swap"\]
      patch__core__secrets__collector[/"secrets/collector"\]
      patch__core__security__openssh[/"security/openssh"\]
      patch__core__security__opkssh[/"security/opkssh"\]
      patch__core__security__sudo[/"security/sudo"\]
      patch__desktop__style__stylix[/"style/stylix"\]
      patch__core__network__syncthing__peer[/"syncthing/peer"\]
      patch__core__system__facter[/"system/facter"\]
      patch__core__system__firmware[/"system/firmware"\]
      patch__core__system__linux_kernel[/"system/linux-kernel"\]
      patch__core__systemd__boot[/"systemd/boot"\]
      patch__user_enrich__sini_axon_01{{"user-enrich/sini@axon-01"}}
      patch__user_enrich__sini_axon_02{{"user-enrich/sini@axon-02"}}
      patch__user_enrich__sini_axon_03{{"user-enrich/sini@axon-03"}}
      patch__user_enrich__sini_bitstream{{"user-enrich/sini@bitstream"}}
      patch__user_enrich__sini_blade{{"user-enrich/sini@blade"}}
      patch__user_enrich__sini_cortex{{"user-enrich/sini@cortex"}}
      patch__user_enrich__sini_patch{{"user-enrich/sini@patch"}}
      patch__user_enrich__sini_slab{{"user-enrich/sini@slab"}}
      patch__user_enrich__sini_uplink{{"user-enrich/sini@uplink"}}
      patch__core__users__deterministic_uids[/"users/deterministic-uids"\]
      patch__core__users__home_manager_shared[/"users/home-manager-shared"\]
      patch__core__users__shell[/"users/shell"\]
      patch__core__impermanence --> patch__core__impermanence__btrfs
      patch__core__impermanence --> patch__core__impermanence__persist_collector
      patch__core__impermanence --> patch__core__impermanence__zfs
    end
    subgraph host_slab["slab"]
      slab__agenix_identity__sini_axon_01{{"agenix-identity/sini@axon-01"}}
      slab__agenix_identity__sini_axon_02{{"agenix-identity/sini@axon-02"}}
      slab__agenix_identity__sini_axon_03{{"agenix-identity/sini@axon-03"}}
      slab__agenix_identity__sini_bitstream{{"agenix-identity/sini@bitstream"}}
      slab__agenix_identity__sini_blade{{"agenix-identity/sini@blade"}}
      slab__agenix_identity__sini_cortex{{"agenix-identity/sini@cortex"}}
      slab__agenix_identity__sini_uplink{{"agenix-identity/sini@uplink"}}
      slab__den__batteries__define_user__sini_slab{{"batteries/define-user/sini@slab"}}
      slab__den__batteries__primary_user_sini_axon_01_{{"batteries/primary-user(sini@axon-01)"}}
      slab__den__batteries__primary_user_sini_axon_02_{{"batteries/primary-user(sini@axon-02)"}}
      slab__den__batteries__primary_user_sini_axon_03_{{"batteries/primary-user(sini@axon-03)"}}
      slab__den__batteries__primary_user_sini_bitstream_{{"batteries/primary-user(sini@bitstream)"}}
      slab__den__batteries__primary_user_sini_blade_{{"batteries/primary-user(sini@blade)"}}
      slab__den__batteries__primary_user_sini_cortex_{{"batteries/primary-user(sini@cortex)"}}
      slab__den__batteries__primary_user_sini_patch_{{"batteries/primary-user(sini@patch)"}}
      slab__den__batteries__primary_user_sini_slab_{{"batteries/primary-user(sini@slab)"}}
      slab__den__batteries__primary_user_sini_uplink_{{"batteries/primary-user(sini@uplink)"}}
      slab__hardware__adb[/"hardware/adb"\]
      slab__core__network__firewall_collector[/"network/firewall-collector"\]
      slab__opkssh_authz__sini_axon_01{{"opkssh-authz/sini@axon-01"}}
      slab__opkssh_authz__sini_axon_02{{"opkssh-authz/sini@axon-02"}}
      slab__opkssh_authz__sini_axon_03{{"opkssh-authz/sini@axon-03"}}
      slab__opkssh_authz__sini_bitstream{{"opkssh-authz/sini@bitstream"}}
      slab__opkssh_authz__sini_blade{{"opkssh-authz/sini@blade"}}
      slab__opkssh_authz__sini_cortex{{"opkssh-authz/sini@cortex"}}
      slab__opkssh_authz__sini_patch{{"opkssh-authz/sini@patch"}}
      slab__opkssh_authz__sini_slab{{"opkssh-authz/sini@slab"}}
      slab__opkssh_authz__sini_uplink{{"opkssh-authz/sini@uplink"}}
      slab__core__secrets__collector[/"secrets/collector"\]
      slab__core__network__syncthing__peer[/"syncthing/peer"\]
      slab__user_enrich__sini_axon_01{{"user-enrich/sini@axon-01"}}
      slab__user_enrich__sini_axon_02{{"user-enrich/sini@axon-02"}}
      slab__user_enrich__sini_axon_03{{"user-enrich/sini@axon-03"}}
      slab__user_enrich__sini_bitstream{{"user-enrich/sini@bitstream"}}
      slab__user_enrich__sini_blade{{"user-enrich/sini@blade"}}
      slab__user_enrich__sini_cortex{{"user-enrich/sini@cortex"}}
      slab__user_enrich__sini_patch{{"user-enrich/sini@patch"}}
      slab__user_enrich__sini_slab{{"user-enrich/sini@slab"}}
      slab__user_enrich__sini_uplink{{"user-enrich/sini@uplink"}}
    end
  end
  subgraph env_prod["prod"]
    subgraph host_axon_01["axon-01"]
      axon_01__agenix_identity__dvicory_axon_01{{"agenix-identity/dvicory@axon-01"}}
      axon_01__agenix_identity__dvicory_axon_02{{"agenix-identity/dvicory@axon-02"}}
      axon_01__agenix_identity__dvicory_axon_03{{"agenix-identity/dvicory@axon-03"}}
      axon_01__agenix_identity__dvicory_bitstream{{"agenix-identity/dvicory@bitstream"}}
      axon_01__agenix_identity__dvicory_uplink{{"agenix-identity/dvicory@uplink"}}
      axon_01__agenix_identity__pol_axon_01{{"agenix-identity/pol@axon-01"}}
      axon_01__agenix_identity__pol_axon_02{{"agenix-identity/pol@axon-02"}}
      axon_01__agenix_identity__pol_axon_03{{"agenix-identity/pol@axon-03"}}
      axon_01__agenix_identity__pol_bitstream{{"agenix-identity/pol@bitstream"}}
      axon_01__agenix_identity__pol_uplink{{"agenix-identity/pol@uplink"}}
      axon_01__agenix_identity__sini_axon_01{{"agenix-identity/sini@axon-01"}}
      axon_01__agenix_identity__sini_axon_02{{"agenix-identity/sini@axon-02"}}
      axon_01__agenix_identity__sini_axon_03{{"agenix-identity/sini@axon-03"}}
      axon_01__agenix_identity__sini_bitstream{{"agenix-identity/sini@bitstream"}}
      axon_01__agenix_identity__sini_blade{{"agenix-identity/sini@blade"}}
      axon_01__agenix_identity__sini_cortex{{"agenix-identity/sini@cortex"}}
      axon_01__agenix_identity__sini_uplink{{"agenix-identity/sini@uplink"}}
      axon_01__agenix_identity__theutz_axon_01{{"agenix-identity/theutz@axon-01"}}
      axon_01__agenix_identity__theutz_axon_02{{"agenix-identity/theutz@axon-02"}}
      axon_01__agenix_identity__theutz_axon_03{{"agenix-identity/theutz@axon-03"}}
      axon_01__agenix_identity__theutz_bitstream{{"agenix-identity/theutz@bitstream"}}
      axon_01__agenix_identity__theutz_uplink{{"agenix-identity/theutz@uplink"}}
      axon_01__agenix_identity__vic_axon_01{{"agenix-identity/vic@axon-01"}}
      axon_01__agenix_identity__vic_axon_02{{"agenix-identity/vic@axon-02"}}
      axon_01__agenix_identity__vic_axon_03{{"agenix-identity/vic@axon-03"}}
      axon_01__agenix_identity__vic_bitstream{{"agenix-identity/vic@bitstream"}}
      axon_01__agenix_identity__vic_blade{{"agenix-identity/vic@blade"}}
      axon_01__agenix_identity__vic_cortex{{"agenix-identity/vic@cortex"}}
      axon_01__agenix_identity__vic_uplink{{"agenix-identity/vic@uplink"}}
      axon_01__agenix__axon_01{{"agenix/axon-01"}}
      axon_01__axon_01{{"axon-01"}}
      axon_01__den__batteries__define_user__dvicory_axon_01{{"batteries/define-user/dvicory@axon-01"}}
      axon_01__den__batteries__define_user__pol_axon_01{{"batteries/define-user/pol@axon-01"}}
      axon_01__den__batteries__define_user__sini_axon_01{{"batteries/define-user/sini@axon-01"}}
      axon_01__den__batteries__define_user__theutz_axon_01{{"batteries/define-user/theutz@axon-01"}}
      axon_01__den__batteries__define_user__vic_axon_01{{"batteries/define-user/vic@axon-01"}}
      axon_01__den__batteries__hostname__os{{"batteries/hostname/os"}}
      axon_01__den__batteries__inputs___os{{"batteries/inputs'/os"}}
      axon_01__den__batteries__primary_user_sini_axon_01_{{"batteries/primary-user(sini@axon-01)"}}
      axon_01__den__batteries__primary_user_sini_axon_02_{{"batteries/primary-user(sini@axon-02)"}}
      axon_01__den__batteries__primary_user_sini_axon_03_{{"batteries/primary-user(sini@axon-03)"}}
      axon_01__den__batteries__primary_user_sini_bitstream_{{"batteries/primary-user(sini@bitstream)"}}
      axon_01__den__batteries__primary_user_sini_blade_{{"batteries/primary-user(sini@blade)"}}
      axon_01__den__batteries__primary_user_sini_cortex_{{"batteries/primary-user(sini@cortex)"}}
      axon_01__den__batteries__primary_user_sini_patch_{{"batteries/primary-user(sini@patch)"}}
      axon_01__den__batteries__primary_user_sini_slab_{{"batteries/primary-user(sini@slab)"}}
      axon_01__den__batteries__primary_user_sini_uplink_{{"batteries/primary-user(sini@uplink)"}}
      axon_01__den__batteries__self___os{{"batteries/self'/os"}}
      axon_01__services__bgp__cilium_bgp[/"bgp/cilium-bgp"\]
      axon_01__core__boot__network_initrd[/"boot/network-initrd"\]
      axon_01__core__impermanence_user_dvicory[/"core/impermanence"\]
      axon_01__core__impermanence_user_pol[/"core/impermanence"\]
      axon_01__core__impermanence_user_theutz[/"core/impermanence"\]
      axon_01__core__impermanence_user_vic[/"core/impermanence"\]
      axon_01__core__impermanence_host_axon_01[/"core/impermanence"\]
      axon_01__core__impermanence__btrfs_user_dvicory[/"core/impermanence/btrfs"\]
      axon_01__core__impermanence__btrfs_user_pol[/"core/impermanence/btrfs"\]
      axon_01__core__impermanence__btrfs_user_theutz[/"core/impermanence/btrfs"\]
      axon_01__core__impermanence__btrfs_user_vic[/"core/impermanence/btrfs"\]
      axon_01__core__impermanence__btrfs_host_axon_01[/"core/impermanence/btrfs"\]
      axon_01__core__impermanence__persist_collector_user_dvicory[/"core/impermanence/persist-collector"\]
      axon_01__core__impermanence__persist_collector_user_pol[/"core/impermanence/persist-collector"\]
      axon_01__core__impermanence__persist_collector_user_theutz[/"core/impermanence/persist-collector"\]
      axon_01__core__impermanence__persist_collector_user_vic[/"core/impermanence/persist-collector"\]
      axon_01__core__impermanence__persist_collector_host_axon_01[/"core/impermanence/persist-collector"\]
      axon_01__core__impermanence__zfs_user_dvicory[/"core/impermanence/zfs"\]
      axon_01__core__impermanence__zfs_user_pol[/"core/impermanence/zfs"\]
      axon_01__core__impermanence__zfs_user_theutz[/"core/impermanence/zfs"\]
      axon_01__core__impermanence__zfs_user_vic[/"core/impermanence/zfs"\]
      axon_01__core__impermanence__zfs_host_axon_01[/"core/impermanence/zfs"\]
      axon_01__core__localization__i18n_user_dvicory[/"core/localization/i18n"\]
      axon_01__core__localization__i18n_user_pol[/"core/localization/i18n"\]
      axon_01__core__localization__i18n_user_theutz[/"core/localization/i18n"\]
      axon_01__core__localization__i18n_user_vic[/"core/localization/i18n"\]
      axon_01__core__localization__i18n_host_axon_01[/"core/localization/i18n"\]
      axon_01__core__network__hostsfile_user_dvicory[/"core/network/hostsfile"\]
      axon_01__core__network__hostsfile_user_pol[/"core/network/hostsfile"\]
      axon_01__core__network__hostsfile_user_theutz[/"core/network/hostsfile"\]
      axon_01__core__network__hostsfile_user_vic[/"core/network/hostsfile"\]
      axon_01__core__network__hostsfile_host_axon_01[/"core/network/hostsfile"\]
      axon_01__core__network__networking_user_dvicory[/"core/network/networking"\]
      axon_01__core__network__networking_user_pol[/"core/network/networking"\]
      axon_01__core__network__networking_user_theutz[/"core/network/networking"\]
      axon_01__core__network__networking_user_vic[/"core/network/networking"\]
      axon_01__core__network__networking_host_axon_01[/"core/network/networking"\]
      axon_01__core__network__syncthing__peer_user_sini[/"core/network/syncthing/peer"\]
      axon_01__core__network__syncthing__peer_user_dvicory[/"core/network/syncthing/peer"\]
      axon_01__core__network__syncthing__peer_user_pol[/"core/network/syncthing/peer"\]
      axon_01__core__network__syncthing__peer_user_theutz[/"core/network/syncthing/peer"\]
      axon_01__core__network__syncthing__peer_user_vic[/"core/network/syncthing/peer"\]
      axon_01__core__network__tailscale_user_dvicory[/"core/network/tailscale"\]
      axon_01__core__network__tailscale_user_pol[/"core/network/tailscale"\]
      axon_01__core__network__tailscale_user_theutz[/"core/network/tailscale"\]
      axon_01__core__network__tailscale_user_vic[/"core/network/tailscale"\]
      axon_01__core__network__tailscale_host_axon_01[/"core/network/tailscale"\]
      axon_01__core__nix_user_dvicory[/"core/nix"\]
      axon_01__core__nix_user_pol[/"core/nix"\]
      axon_01__core__nix_user_theutz[/"core/nix"\]
      axon_01__core__nix_user_vic[/"core/nix"\]
      axon_01__core__nix_host_axon_01[/"core/nix"\]
      axon_01__core__nix__stateVersion_user_dvicory[/"core/nix/stateVersion"\]
      axon_01__core__nix__stateVersion_user_pol[/"core/nix/stateVersion"\]
      axon_01__core__nix__stateVersion_user_theutz[/"core/nix/stateVersion"\]
      axon_01__core__nix__stateVersion_user_vic[/"core/nix/stateVersion"\]
      axon_01__core__nix__stateVersion_host_axon_01[/"core/nix/stateVersion"\]
      axon_01__core__perf__disable_docs_user_dvicory[/"core/perf/disable-docs"\]
      axon_01__core__perf__disable_docs_user_pol[/"core/perf/disable-docs"\]
      axon_01__core__perf__disable_docs_user_theutz[/"core/perf/disable-docs"\]
      axon_01__core__perf__disable_docs_user_vic[/"core/perf/disable-docs"\]
      axon_01__core__perf__disable_docs_host_axon_01[/"core/perf/disable-docs"\]
      axon_01__core__perf__ssd_user_dvicory[/"core/perf/ssd"\]
      axon_01__core__perf__ssd_user_pol[/"core/perf/ssd"\]
      axon_01__core__perf__ssd_user_theutz[/"core/perf/ssd"\]
      axon_01__core__perf__ssd_user_vic[/"core/perf/ssd"\]
      axon_01__core__perf__ssd_host_axon_01[/"core/perf/ssd"\]
      axon_01__core__perf__zram_swap_user_dvicory[/"core/perf/zram-swap"\]
      axon_01__core__perf__zram_swap_user_pol[/"core/perf/zram-swap"\]
      axon_01__core__perf__zram_swap_user_theutz[/"core/perf/zram-swap"\]
      axon_01__core__perf__zram_swap_user_vic[/"core/perf/zram-swap"\]
      axon_01__core__perf__zram_swap_host_axon_01[/"core/perf/zram-swap"\]
      axon_01__core__security_user_dvicory[/"core/security"\]
      axon_01__core__security_user_pol[/"core/security"\]
      axon_01__core__security_user_theutz[/"core/security"\]
      axon_01__core__security_user_vic[/"core/security"\]
      axon_01__core__security_host_axon_01[/"core/security"\]
      axon_01__core__security__openssh_user_dvicory[/"core/security/openssh"\]
      axon_01__core__security__openssh_user_pol[/"core/security/openssh"\]
      axon_01__core__security__openssh_user_theutz[/"core/security/openssh"\]
      axon_01__core__security__openssh_user_vic[/"core/security/openssh"\]
      axon_01__core__security__openssh_host_axon_01[/"core/security/openssh"\]
      axon_01__core__security__opkssh_user_dvicory[/"core/security/opkssh"\]
      axon_01__core__security__opkssh_user_pol[/"core/security/opkssh"\]
      axon_01__core__security__opkssh_user_theutz[/"core/security/opkssh"\]
      axon_01__core__security__opkssh_user_vic[/"core/security/opkssh"\]
      axon_01__core__security__opkssh_host_axon_01[/"core/security/opkssh"\]
      axon_01__core__security__sudo_user_dvicory[/"core/security/sudo"\]
      axon_01__core__security__sudo_user_pol[/"core/security/sudo"\]
      axon_01__core__security__sudo_user_theutz[/"core/security/sudo"\]
      axon_01__core__security__sudo_user_vic[/"core/security/sudo"\]
      axon_01__core__security__sudo_host_axon_01[/"core/security/sudo"\]
      axon_01__core__system__facter_user_dvicory[/"core/system/facter"\]
      axon_01__core__system__facter_user_pol[/"core/system/facter"\]
      axon_01__core__system__facter_user_theutz[/"core/system/facter"\]
      axon_01__core__system__facter_user_vic[/"core/system/facter"\]
      axon_01__core__system__facter_host_axon_01[/"core/system/facter"\]
      axon_01__core__system__firmware_user_dvicory[/"core/system/firmware"\]
      axon_01__core__system__firmware_user_pol[/"core/system/firmware"\]
      axon_01__core__system__firmware_user_theutz[/"core/system/firmware"\]
      axon_01__core__system__firmware_user_vic[/"core/system/firmware"\]
      axon_01__core__system__firmware_host_axon_01[/"core/system/firmware"\]
      axon_01__core__system__linux_kernel_user_dvicory[/"core/system/linux-kernel"\]
      axon_01__core__system__linux_kernel_user_pol[/"core/system/linux-kernel"\]
      axon_01__core__system__linux_kernel_user_theutz[/"core/system/linux-kernel"\]
      axon_01__core__system__linux_kernel_user_vic[/"core/system/linux-kernel"\]
      axon_01__core__system__linux_kernel_host_axon_01[/"core/system/linux-kernel"\]
      axon_01__core__systemd_user_dvicory[/"core/systemd"\]
      axon_01__core__systemd_user_pol[/"core/systemd"\]
      axon_01__core__systemd_user_theutz[/"core/systemd"\]
      axon_01__core__systemd_user_vic[/"core/systemd"\]
      axon_01__core__systemd_host_axon_01[/"core/systemd"\]
      axon_01__core__systemd__boot_user_dvicory[/"core/systemd/boot"\]
      axon_01__core__systemd__boot_user_pol[/"core/systemd/boot"\]
      axon_01__core__systemd__boot_user_theutz[/"core/systemd/boot"\]
      axon_01__core__systemd__boot_user_vic[/"core/systemd/boot"\]
      axon_01__core__systemd__boot_host_axon_01[/"core/systemd/boot"\]
      axon_01__core__users_user_dvicory[/"core/users"\]
      axon_01__core__users_user_pol[/"core/users"\]
      axon_01__core__users_user_theutz[/"core/users"\]
      axon_01__core__users_user_vic[/"core/users"\]
      axon_01__core__users_host_axon_01[/"core/users"\]
      axon_01__core__users__deterministic_uids_user_dvicory[/"core/users/deterministic-uids"\]
      axon_01__core__users__deterministic_uids_user_pol[/"core/users/deterministic-uids"\]
      axon_01__core__users__deterministic_uids_user_theutz[/"core/users/deterministic-uids"\]
      axon_01__core__users__deterministic_uids_user_vic[/"core/users/deterministic-uids"\]
      axon_01__core__users__deterministic_uids_host_axon_01[/"core/users/deterministic-uids"\]
      axon_01__core__users__home_manager_shared_user_dvicory[/"core/users/home-manager-shared"\]
      axon_01__core__users__home_manager_shared_user_pol[/"core/users/home-manager-shared"\]
      axon_01__core__users__home_manager_shared_user_theutz[/"core/users/home-manager-shared"\]
      axon_01__core__users__home_manager_shared_user_vic[/"core/users/home-manager-shared"\]
      axon_01__core__users__home_manager_shared_host_axon_01[/"core/users/home-manager-shared"\]
      axon_01__core__users__shell_user_dvicory[/"core/users/shell"\]
      axon_01__core__users__shell_user_pol[/"core/users/shell"\]
      axon_01__core__users__shell_user_theutz[/"core/users/shell"\]
      axon_01__core__users__shell_user_vic[/"core/users/shell"\]
      axon_01__core__users__shell_host_axon_01[/"core/users/shell"\]
      axon_01__core__utils_user_dvicory[/"core/utils"\]
      axon_01__core__utils_user_pol[/"core/utils"\]
      axon_01__core__utils_user_theutz[/"core/utils"\]
      axon_01__core__utils_user_vic[/"core/utils"\]
      axon_01__core__utils_host_axon_01[/"core/utils"\]
      axon_01__hardware__cpu__amd[/"cpu/amd"\]
      axon_01__disk__xfs_disk_longhorn[/"disk/xfs-disk-longhorn"\]
      axon_01__disk__zfs_diff[/"disk/zfs-diff"\]
      axon_01__disk__zfs_disk_single[/"disk/zfs-disk-single"\]
      axon_01__hardware__gpu__amd[/"gpu/amd"\]
      axon_01__hardware__thunderbolt_network[/"hardware/thunderbolt-network"\]
      axon_01__insecure_predicate__os{{"insecure-predicate/os"}}
      axon_01__services__k3s__bootstrap[/"k3s/bootstrap"\]
      axon_01__services__k3s__containerd[/"k3s/containerd"\]
      axon_01__services__k3s__node[/"k3s/node"\]
      axon_01__services__k3s__node_lifecycle[/"k3s/node-lifecycle"\]
      axon_01__services__monitoring__prometheus_exporter[/"monitoring/prometheus-exporter"\]
      axon_01__core__network__firewall_collector[/"network/firewall-collector"\]
      axon_01__services__networking__thunderbolt_mesh_of[/"networking/thunderbolt-mesh-of"\]
      axon_01__services__nix__remote_build_server[/"nix/remote-build-server"\]
      axon_01__opkssh_authz__dvicory_axon_01{{"opkssh-authz/dvicory@axon-01"}}
      axon_01__opkssh_authz__dvicory_axon_02{{"opkssh-authz/dvicory@axon-02"}}
      axon_01__opkssh_authz__dvicory_axon_03{{"opkssh-authz/dvicory@axon-03"}}
      axon_01__opkssh_authz__dvicory_bitstream{{"opkssh-authz/dvicory@bitstream"}}
      axon_01__opkssh_authz__dvicory_uplink{{"opkssh-authz/dvicory@uplink"}}
      axon_01__opkssh_authz__pol_axon_01{{"opkssh-authz/pol@axon-01"}}
      axon_01__opkssh_authz__pol_axon_02{{"opkssh-authz/pol@axon-02"}}
      axon_01__opkssh_authz__pol_axon_03{{"opkssh-authz/pol@axon-03"}}
      axon_01__opkssh_authz__pol_bitstream{{"opkssh-authz/pol@bitstream"}}
      axon_01__opkssh_authz__pol_uplink{{"opkssh-authz/pol@uplink"}}
      axon_01__opkssh_authz__sini_axon_01{{"opkssh-authz/sini@axon-01"}}
      axon_01__opkssh_authz__sini_axon_02{{"opkssh-authz/sini@axon-02"}}
      axon_01__opkssh_authz__sini_axon_03{{"opkssh-authz/sini@axon-03"}}
      axon_01__opkssh_authz__sini_bitstream{{"opkssh-authz/sini@bitstream"}}
      axon_01__opkssh_authz__sini_blade{{"opkssh-authz/sini@blade"}}
      axon_01__opkssh_authz__sini_cortex{{"opkssh-authz/sini@cortex"}}
      axon_01__opkssh_authz__sini_patch{{"opkssh-authz/sini@patch"}}
      axon_01__opkssh_authz__sini_slab{{"opkssh-authz/sini@slab"}}
      axon_01__opkssh_authz__sini_uplink{{"opkssh-authz/sini@uplink"}}
      axon_01__opkssh_authz__theutz_axon_01{{"opkssh-authz/theutz@axon-01"}}
      axon_01__opkssh_authz__theutz_axon_02{{"opkssh-authz/theutz@axon-02"}}
      axon_01__opkssh_authz__theutz_axon_03{{"opkssh-authz/theutz@axon-03"}}
      axon_01__opkssh_authz__theutz_bitstream{{"opkssh-authz/theutz@bitstream"}}
      axon_01__opkssh_authz__theutz_uplink{{"opkssh-authz/theutz@uplink"}}
      axon_01__opkssh_authz__vic_axon_01{{"opkssh-authz/vic@axon-01"}}
      axon_01__opkssh_authz__vic_axon_02{{"opkssh-authz/vic@axon-02"}}
      axon_01__opkssh_authz__vic_axon_03{{"opkssh-authz/vic@axon-03"}}
      axon_01__opkssh_authz__vic_bitstream{{"opkssh-authz/vic@bitstream"}}
      axon_01__opkssh_authz__vic_blade{{"opkssh-authz/vic@blade"}}
      axon_01__opkssh_authz__vic_cortex{{"opkssh-authz/vic@cortex"}}
      axon_01__opkssh_authz__vic_uplink{{"opkssh-authz/vic@uplink"}}
      axon_01__roles__server[/"roles/server"\]
      axon_01__core__secrets__collector[/"secrets/collector"\]
      axon_01__services__security__acme[/"security/acme"\]
      axon_01__services__security__tang[/"security/tang"\]
      axon_01__services__bgp[/"services/bgp"\]
      axon_01__services__k3s[/"services/k3s"\]
      axon_01__services__storage__media_data_share[/"storage/media-data-share"\]
      axon_01__services__storage__media_scratch[/"storage/media-scratch"\]
      axon_01__unfree_predicate__os{{"unfree-predicate/os"}}
      axon_01__user_enrich__dvicory_axon_01{{"user-enrich/dvicory@axon-01"}}
      axon_01__user_enrich__dvicory_axon_02{{"user-enrich/dvicory@axon-02"}}
      axon_01__user_enrich__dvicory_axon_03{{"user-enrich/dvicory@axon-03"}}
      axon_01__user_enrich__dvicory_bitstream{{"user-enrich/dvicory@bitstream"}}
      axon_01__user_enrich__dvicory_uplink{{"user-enrich/dvicory@uplink"}}
      axon_01__user_enrich__pol_axon_01{{"user-enrich/pol@axon-01"}}
      axon_01__user_enrich__pol_axon_02{{"user-enrich/pol@axon-02"}}
      axon_01__user_enrich__pol_axon_03{{"user-enrich/pol@axon-03"}}
      axon_01__user_enrich__pol_bitstream{{"user-enrich/pol@bitstream"}}
      axon_01__user_enrich__pol_uplink{{"user-enrich/pol@uplink"}}
      axon_01__user_enrich__sini_axon_01{{"user-enrich/sini@axon-01"}}
      axon_01__user_enrich__sini_axon_02{{"user-enrich/sini@axon-02"}}
      axon_01__user_enrich__sini_axon_03{{"user-enrich/sini@axon-03"}}
      axon_01__user_enrich__sini_bitstream{{"user-enrich/sini@bitstream"}}
      axon_01__user_enrich__sini_blade{{"user-enrich/sini@blade"}}
      axon_01__user_enrich__sini_cortex{{"user-enrich/sini@cortex"}}
      axon_01__user_enrich__sini_patch{{"user-enrich/sini@patch"}}
      axon_01__user_enrich__sini_slab{{"user-enrich/sini@slab"}}
      axon_01__user_enrich__sini_uplink{{"user-enrich/sini@uplink"}}
      axon_01__user_enrich__theutz_axon_01{{"user-enrich/theutz@axon-01"}}
      axon_01__user_enrich__theutz_axon_02{{"user-enrich/theutz@axon-02"}}
      axon_01__user_enrich__theutz_axon_03{{"user-enrich/theutz@axon-03"}}
      axon_01__user_enrich__theutz_bitstream{{"user-enrich/theutz@bitstream"}}
      axon_01__user_enrich__theutz_uplink{{"user-enrich/theutz@uplink"}}
      axon_01__user_enrich__vic_axon_01{{"user-enrich/vic@axon-01"}}
      axon_01__user_enrich__vic_axon_02{{"user-enrich/vic@axon-02"}}
      axon_01__user_enrich__vic_axon_03{{"user-enrich/vic@axon-03"}}
      axon_01__user_enrich__vic_bitstream{{"user-enrich/vic@bitstream"}}
      axon_01__user_enrich__vic_blade{{"user-enrich/vic@blade"}}
      axon_01__user_enrich__vic_cortex{{"user-enrich/vic@cortex"}}
      axon_01__user_enrich__vic_uplink{{"user-enrich/vic@uplink"}}
      axon_01__disk__zfs_disk_single__root[/"zfs-disk-single/root"\]
      axon_01__axon_01 --> axon_01__hardware__cpu__amd
      axon_01__axon_01 --> axon_01__hardware__gpu__amd
      axon_01__axon_01 --> axon_01__services__bgp__cilium_bgp
      axon_01__axon_01 --> axon_01__services__k3s
      axon_01__axon_01 --> axon_01__services__storage__media_scratch
      axon_01__axon_01 --> axon_01__core__boot__network_initrd
      axon_01__axon_01 --> axon_01__roles__server
      axon_01__axon_01 --> axon_01__services__networking__thunderbolt_mesh_of
      axon_01__axon_01 --> axon_01__disk__xfs_disk_longhorn
      axon_01__axon_01 --> axon_01__disk__zfs_disk_single
      axon_01__core__impermanence_user_dvicory --> axon_01__core__impermanence__btrfs_user_dvicory
      axon_01__core__impermanence_user_pol --> axon_01__core__impermanence__btrfs_user_pol
      axon_01__core__impermanence_user_theutz --> axon_01__core__impermanence__btrfs_user_theutz
      axon_01__core__impermanence_user_vic --> axon_01__core__impermanence__btrfs_user_vic
      axon_01__core__impermanence_host_axon_01 --> axon_01__core__impermanence__btrfs_host_axon_01
      axon_01__core__impermanence_user_dvicory --> axon_01__core__impermanence__persist_collector_user_dvicory
      axon_01__core__impermanence_user_pol --> axon_01__core__impermanence__persist_collector_user_pol
      axon_01__core__impermanence_user_theutz --> axon_01__core__impermanence__persist_collector_user_theutz
      axon_01__core__impermanence_user_vic --> axon_01__core__impermanence__persist_collector_user_vic
      axon_01__core__impermanence_host_axon_01 --> axon_01__core__impermanence__persist_collector_host_axon_01
      axon_01__core__impermanence_user_dvicory --> axon_01__core__impermanence__zfs_user_dvicory
      axon_01__core__impermanence_user_pol --> axon_01__core__impermanence__zfs_user_pol
      axon_01__core__impermanence_user_theutz --> axon_01__core__impermanence__zfs_user_theutz
      axon_01__core__impermanence_user_vic --> axon_01__core__impermanence__zfs_user_vic
      axon_01__core__impermanence_host_axon_01 --> axon_01__core__impermanence__zfs_host_axon_01
      axon_01__disk__zfs_disk_single --> axon_01__disk__zfs_disk_single__root
      axon_01__disk__zfs_disk_single__root --> axon_01__disk__zfs_diff
      axon_01__roles__server --> axon_01__services__security__acme
      axon_01__roles__server --> axon_01__services__storage__media_data_share
      axon_01__roles__server --> axon_01__services__monitoring__prometheus_exporter
      axon_01__roles__server --> axon_01__services__security__tang
      axon_01__services__k3s --> axon_01__services__k3s__bootstrap
      axon_01__services__k3s --> axon_01__services__k3s__containerd
      axon_01__services__k3s --> axon_01__services__k3s__node
      axon_01__services__k3s --> axon_01__services__k3s__node_lifecycle
      axon_01__services__networking__thunderbolt_mesh_of --> axon_01__hardware__thunderbolt_network
    end
    subgraph host_axon_02["axon-02"]
      axon_02__agenix_identity__dvicory_axon_01{{"agenix-identity/dvicory@axon-01"}}
      axon_02__agenix_identity__dvicory_axon_02{{"agenix-identity/dvicory@axon-02"}}
      axon_02__agenix_identity__dvicory_axon_03{{"agenix-identity/dvicory@axon-03"}}
      axon_02__agenix_identity__dvicory_bitstream{{"agenix-identity/dvicory@bitstream"}}
      axon_02__agenix_identity__dvicory_uplink{{"agenix-identity/dvicory@uplink"}}
      axon_02__agenix_identity__pol_axon_01{{"agenix-identity/pol@axon-01"}}
      axon_02__agenix_identity__pol_axon_02{{"agenix-identity/pol@axon-02"}}
      axon_02__agenix_identity__pol_axon_03{{"agenix-identity/pol@axon-03"}}
      axon_02__agenix_identity__pol_bitstream{{"agenix-identity/pol@bitstream"}}
      axon_02__agenix_identity__pol_uplink{{"agenix-identity/pol@uplink"}}
      axon_02__agenix_identity__sini_axon_01{{"agenix-identity/sini@axon-01"}}
      axon_02__agenix_identity__sini_axon_02{{"agenix-identity/sini@axon-02"}}
      axon_02__agenix_identity__sini_axon_03{{"agenix-identity/sini@axon-03"}}
      axon_02__agenix_identity__sini_bitstream{{"agenix-identity/sini@bitstream"}}
      axon_02__agenix_identity__sini_blade{{"agenix-identity/sini@blade"}}
      axon_02__agenix_identity__sini_cortex{{"agenix-identity/sini@cortex"}}
      axon_02__agenix_identity__sini_uplink{{"agenix-identity/sini@uplink"}}
      axon_02__agenix_identity__theutz_axon_01{{"agenix-identity/theutz@axon-01"}}
      axon_02__agenix_identity__theutz_axon_02{{"agenix-identity/theutz@axon-02"}}
      axon_02__agenix_identity__theutz_axon_03{{"agenix-identity/theutz@axon-03"}}
      axon_02__agenix_identity__theutz_bitstream{{"agenix-identity/theutz@bitstream"}}
      axon_02__agenix_identity__theutz_uplink{{"agenix-identity/theutz@uplink"}}
      axon_02__agenix_identity__vic_axon_01{{"agenix-identity/vic@axon-01"}}
      axon_02__agenix_identity__vic_axon_02{{"agenix-identity/vic@axon-02"}}
      axon_02__agenix_identity__vic_axon_03{{"agenix-identity/vic@axon-03"}}
      axon_02__agenix_identity__vic_bitstream{{"agenix-identity/vic@bitstream"}}
      axon_02__agenix_identity__vic_blade{{"agenix-identity/vic@blade"}}
      axon_02__agenix_identity__vic_cortex{{"agenix-identity/vic@cortex"}}
      axon_02__agenix_identity__vic_uplink{{"agenix-identity/vic@uplink"}}
      axon_02__agenix__axon_02{{"agenix/axon-02"}}
      axon_02__axon_02{{"axon-02"}}
      axon_02__den__batteries__define_user__dvicory_axon_02{{"batteries/define-user/dvicory@axon-02"}}
      axon_02__den__batteries__define_user__pol_axon_02{{"batteries/define-user/pol@axon-02"}}
      axon_02__den__batteries__define_user__sini_axon_02{{"batteries/define-user/sini@axon-02"}}
      axon_02__den__batteries__define_user__theutz_axon_02{{"batteries/define-user/theutz@axon-02"}}
      axon_02__den__batteries__define_user__vic_axon_02{{"batteries/define-user/vic@axon-02"}}
      axon_02__den__batteries__hostname__os{{"batteries/hostname/os"}}
      axon_02__den__batteries__inputs___os{{"batteries/inputs'/os"}}
      axon_02__den__batteries__primary_user_sini_axon_01_{{"batteries/primary-user(sini@axon-01)"}}
      axon_02__den__batteries__primary_user_sini_axon_02_{{"batteries/primary-user(sini@axon-02)"}}
      axon_02__den__batteries__primary_user_sini_axon_03_{{"batteries/primary-user(sini@axon-03)"}}
      axon_02__den__batteries__primary_user_sini_bitstream_{{"batteries/primary-user(sini@bitstream)"}}
      axon_02__den__batteries__primary_user_sini_blade_{{"batteries/primary-user(sini@blade)"}}
      axon_02__den__batteries__primary_user_sini_cortex_{{"batteries/primary-user(sini@cortex)"}}
      axon_02__den__batteries__primary_user_sini_patch_{{"batteries/primary-user(sini@patch)"}}
      axon_02__den__batteries__primary_user_sini_slab_{{"batteries/primary-user(sini@slab)"}}
      axon_02__den__batteries__primary_user_sini_uplink_{{"batteries/primary-user(sini@uplink)"}}
      axon_02__den__batteries__self___os{{"batteries/self'/os"}}
      axon_02__services__bgp__cilium_bgp[/"bgp/cilium-bgp"\]
      axon_02__core__boot__network_initrd[/"boot/network-initrd"\]
      axon_02__core__impermanence_user_dvicory[/"core/impermanence"\]
      axon_02__core__impermanence_user_pol[/"core/impermanence"\]
      axon_02__core__impermanence_user_theutz[/"core/impermanence"\]
      axon_02__core__impermanence_user_vic[/"core/impermanence"\]
      axon_02__core__impermanence_host_axon_02[/"core/impermanence"\]
      axon_02__core__impermanence__btrfs_user_dvicory[/"core/impermanence/btrfs"\]
      axon_02__core__impermanence__btrfs_user_pol[/"core/impermanence/btrfs"\]
      axon_02__core__impermanence__btrfs_user_theutz[/"core/impermanence/btrfs"\]
      axon_02__core__impermanence__btrfs_user_vic[/"core/impermanence/btrfs"\]
      axon_02__core__impermanence__btrfs_host_axon_02[/"core/impermanence/btrfs"\]
      axon_02__core__impermanence__persist_collector_user_dvicory[/"core/impermanence/persist-collector"\]
      axon_02__core__impermanence__persist_collector_user_pol[/"core/impermanence/persist-collector"\]
      axon_02__core__impermanence__persist_collector_user_theutz[/"core/impermanence/persist-collector"\]
      axon_02__core__impermanence__persist_collector_user_vic[/"core/impermanence/persist-collector"\]
      axon_02__core__impermanence__persist_collector_host_axon_02[/"core/impermanence/persist-collector"\]
      axon_02__core__impermanence__zfs_user_dvicory[/"core/impermanence/zfs"\]
      axon_02__core__impermanence__zfs_user_pol[/"core/impermanence/zfs"\]
      axon_02__core__impermanence__zfs_user_theutz[/"core/impermanence/zfs"\]
      axon_02__core__impermanence__zfs_user_vic[/"core/impermanence/zfs"\]
      axon_02__core__impermanence__zfs_host_axon_02[/"core/impermanence/zfs"\]
      axon_02__core__localization__i18n_user_dvicory[/"core/localization/i18n"\]
      axon_02__core__localization__i18n_user_pol[/"core/localization/i18n"\]
      axon_02__core__localization__i18n_user_theutz[/"core/localization/i18n"\]
      axon_02__core__localization__i18n_user_vic[/"core/localization/i18n"\]
      axon_02__core__localization__i18n_host_axon_02[/"core/localization/i18n"\]
      axon_02__core__network__hostsfile_user_dvicory[/"core/network/hostsfile"\]
      axon_02__core__network__hostsfile_user_pol[/"core/network/hostsfile"\]
      axon_02__core__network__hostsfile_user_theutz[/"core/network/hostsfile"\]
      axon_02__core__network__hostsfile_user_vic[/"core/network/hostsfile"\]
      axon_02__core__network__hostsfile_host_axon_02[/"core/network/hostsfile"\]
      axon_02__core__network__networking_user_dvicory[/"core/network/networking"\]
      axon_02__core__network__networking_user_pol[/"core/network/networking"\]
      axon_02__core__network__networking_user_theutz[/"core/network/networking"\]
      axon_02__core__network__networking_user_vic[/"core/network/networking"\]
      axon_02__core__network__networking_host_axon_02[/"core/network/networking"\]
      axon_02__core__network__syncthing__peer_user_sini[/"core/network/syncthing/peer"\]
      axon_02__core__network__syncthing__peer_user_dvicory[/"core/network/syncthing/peer"\]
      axon_02__core__network__syncthing__peer_user_pol[/"core/network/syncthing/peer"\]
      axon_02__core__network__syncthing__peer_user_theutz[/"core/network/syncthing/peer"\]
      axon_02__core__network__syncthing__peer_user_vic[/"core/network/syncthing/peer"\]
      axon_02__core__network__tailscale_user_dvicory[/"core/network/tailscale"\]
      axon_02__core__network__tailscale_user_pol[/"core/network/tailscale"\]
      axon_02__core__network__tailscale_user_theutz[/"core/network/tailscale"\]
      axon_02__core__network__tailscale_user_vic[/"core/network/tailscale"\]
      axon_02__core__network__tailscale_host_axon_02[/"core/network/tailscale"\]
      axon_02__core__nix_user_dvicory[/"core/nix"\]
      axon_02__core__nix_user_pol[/"core/nix"\]
      axon_02__core__nix_user_theutz[/"core/nix"\]
      axon_02__core__nix_user_vic[/"core/nix"\]
      axon_02__core__nix_host_axon_02[/"core/nix"\]
      axon_02__core__nix__stateVersion_user_dvicory[/"core/nix/stateVersion"\]
      axon_02__core__nix__stateVersion_user_pol[/"core/nix/stateVersion"\]
      axon_02__core__nix__stateVersion_user_theutz[/"core/nix/stateVersion"\]
      axon_02__core__nix__stateVersion_user_vic[/"core/nix/stateVersion"\]
      axon_02__core__nix__stateVersion_host_axon_02[/"core/nix/stateVersion"\]
      axon_02__core__perf__disable_docs_user_dvicory[/"core/perf/disable-docs"\]
      axon_02__core__perf__disable_docs_user_pol[/"core/perf/disable-docs"\]
      axon_02__core__perf__disable_docs_user_theutz[/"core/perf/disable-docs"\]
      axon_02__core__perf__disable_docs_user_vic[/"core/perf/disable-docs"\]
      axon_02__core__perf__disable_docs_host_axon_02[/"core/perf/disable-docs"\]
      axon_02__core__perf__ssd_user_dvicory[/"core/perf/ssd"\]
      axon_02__core__perf__ssd_user_pol[/"core/perf/ssd"\]
      axon_02__core__perf__ssd_user_theutz[/"core/perf/ssd"\]
      axon_02__core__perf__ssd_user_vic[/"core/perf/ssd"\]
      axon_02__core__perf__ssd_host_axon_02[/"core/perf/ssd"\]
      axon_02__core__perf__zram_swap_user_dvicory[/"core/perf/zram-swap"\]
      axon_02__core__perf__zram_swap_user_pol[/"core/perf/zram-swap"\]
      axon_02__core__perf__zram_swap_user_theutz[/"core/perf/zram-swap"\]
      axon_02__core__perf__zram_swap_user_vic[/"core/perf/zram-swap"\]
      axon_02__core__perf__zram_swap_host_axon_02[/"core/perf/zram-swap"\]
      axon_02__core__security_user_dvicory[/"core/security"\]
      axon_02__core__security_user_pol[/"core/security"\]
      axon_02__core__security_user_theutz[/"core/security"\]
      axon_02__core__security_user_vic[/"core/security"\]
      axon_02__core__security_host_axon_02[/"core/security"\]
      axon_02__core__security__openssh_user_dvicory[/"core/security/openssh"\]
      axon_02__core__security__openssh_user_pol[/"core/security/openssh"\]
      axon_02__core__security__openssh_user_theutz[/"core/security/openssh"\]
      axon_02__core__security__openssh_user_vic[/"core/security/openssh"\]
      axon_02__core__security__openssh_host_axon_02[/"core/security/openssh"\]
      axon_02__core__security__opkssh_user_dvicory[/"core/security/opkssh"\]
      axon_02__core__security__opkssh_user_pol[/"core/security/opkssh"\]
      axon_02__core__security__opkssh_user_theutz[/"core/security/opkssh"\]
      axon_02__core__security__opkssh_user_vic[/"core/security/opkssh"\]
      axon_02__core__security__opkssh_host_axon_02[/"core/security/opkssh"\]
      axon_02__core__security__sudo_user_dvicory[/"core/security/sudo"\]
      axon_02__core__security__sudo_user_pol[/"core/security/sudo"\]
      axon_02__core__security__sudo_user_theutz[/"core/security/sudo"\]
      axon_02__core__security__sudo_user_vic[/"core/security/sudo"\]
      axon_02__core__security__sudo_host_axon_02[/"core/security/sudo"\]
      axon_02__core__system__facter_user_dvicory[/"core/system/facter"\]
      axon_02__core__system__facter_user_pol[/"core/system/facter"\]
      axon_02__core__system__facter_user_theutz[/"core/system/facter"\]
      axon_02__core__system__facter_user_vic[/"core/system/facter"\]
      axon_02__core__system__facter_host_axon_02[/"core/system/facter"\]
      axon_02__core__system__firmware_user_dvicory[/"core/system/firmware"\]
      axon_02__core__system__firmware_user_pol[/"core/system/firmware"\]
      axon_02__core__system__firmware_user_theutz[/"core/system/firmware"\]
      axon_02__core__system__firmware_user_vic[/"core/system/firmware"\]
      axon_02__core__system__firmware_host_axon_02[/"core/system/firmware"\]
      axon_02__core__system__linux_kernel_user_dvicory[/"core/system/linux-kernel"\]
      axon_02__core__system__linux_kernel_user_pol[/"core/system/linux-kernel"\]
      axon_02__core__system__linux_kernel_user_theutz[/"core/system/linux-kernel"\]
      axon_02__core__system__linux_kernel_user_vic[/"core/system/linux-kernel"\]
      axon_02__core__system__linux_kernel_host_axon_02[/"core/system/linux-kernel"\]
      axon_02__core__systemd_user_dvicory[/"core/systemd"\]
      axon_02__core__systemd_user_pol[/"core/systemd"\]
      axon_02__core__systemd_user_theutz[/"core/systemd"\]
      axon_02__core__systemd_user_vic[/"core/systemd"\]
      axon_02__core__systemd_host_axon_02[/"core/systemd"\]
      axon_02__core__systemd__boot_user_dvicory[/"core/systemd/boot"\]
      axon_02__core__systemd__boot_user_pol[/"core/systemd/boot"\]
      axon_02__core__systemd__boot_user_theutz[/"core/systemd/boot"\]
      axon_02__core__systemd__boot_user_vic[/"core/systemd/boot"\]
      axon_02__core__systemd__boot_host_axon_02[/"core/systemd/boot"\]
      axon_02__core__users_user_dvicory[/"core/users"\]
      axon_02__core__users_user_pol[/"core/users"\]
      axon_02__core__users_user_theutz[/"core/users"\]
      axon_02__core__users_user_vic[/"core/users"\]
      axon_02__core__users_host_axon_02[/"core/users"\]
      axon_02__core__users__deterministic_uids_user_dvicory[/"core/users/deterministic-uids"\]
      axon_02__core__users__deterministic_uids_user_pol[/"core/users/deterministic-uids"\]
      axon_02__core__users__deterministic_uids_user_theutz[/"core/users/deterministic-uids"\]
      axon_02__core__users__deterministic_uids_user_vic[/"core/users/deterministic-uids"\]
      axon_02__core__users__deterministic_uids_host_axon_02[/"core/users/deterministic-uids"\]
      axon_02__core__users__home_manager_shared_user_dvicory[/"core/users/home-manager-shared"\]
      axon_02__core__users__home_manager_shared_user_pol[/"core/users/home-manager-shared"\]
      axon_02__core__users__home_manager_shared_user_theutz[/"core/users/home-manager-shared"\]
      axon_02__core__users__home_manager_shared_user_vic[/"core/users/home-manager-shared"\]
      axon_02__core__users__home_manager_shared_host_axon_02[/"core/users/home-manager-shared"\]
      axon_02__core__users__shell_user_dvicory[/"core/users/shell"\]
      axon_02__core__users__shell_user_pol[/"core/users/shell"\]
      axon_02__core__users__shell_user_theutz[/"core/users/shell"\]
      axon_02__core__users__shell_user_vic[/"core/users/shell"\]
      axon_02__core__users__shell_host_axon_02[/"core/users/shell"\]
      axon_02__core__utils_user_dvicory[/"core/utils"\]
      axon_02__core__utils_user_pol[/"core/utils"\]
      axon_02__core__utils_user_theutz[/"core/utils"\]
      axon_02__core__utils_user_vic[/"core/utils"\]
      axon_02__core__utils_host_axon_02[/"core/utils"\]
      axon_02__hardware__cpu__amd[/"cpu/amd"\]
      axon_02__disk__xfs_disk_longhorn[/"disk/xfs-disk-longhorn"\]
      axon_02__disk__zfs_diff[/"disk/zfs-diff"\]
      axon_02__disk__zfs_disk_single[/"disk/zfs-disk-single"\]
      axon_02__hardware__gpu__amd[/"gpu/amd"\]
      axon_02__hardware__thunderbolt_network[/"hardware/thunderbolt-network"\]
      axon_02__insecure_predicate__os{{"insecure-predicate/os"}}
      axon_02__services__k3s__bootstrap[/"k3s/bootstrap"\]
      axon_02__services__k3s__containerd[/"k3s/containerd"\]
      axon_02__services__k3s__node[/"k3s/node"\]
      axon_02__services__k3s__node_lifecycle[/"k3s/node-lifecycle"\]
      axon_02__services__monitoring__prometheus_exporter[/"monitoring/prometheus-exporter"\]
      axon_02__core__network__firewall_collector[/"network/firewall-collector"\]
      axon_02__services__networking__thunderbolt_mesh_of[/"networking/thunderbolt-mesh-of"\]
      axon_02__services__nix__remote_build_server[/"nix/remote-build-server"\]
      axon_02__opkssh_authz__dvicory_axon_01{{"opkssh-authz/dvicory@axon-01"}}
      axon_02__opkssh_authz__dvicory_axon_02{{"opkssh-authz/dvicory@axon-02"}}
      axon_02__opkssh_authz__dvicory_axon_03{{"opkssh-authz/dvicory@axon-03"}}
      axon_02__opkssh_authz__dvicory_bitstream{{"opkssh-authz/dvicory@bitstream"}}
      axon_02__opkssh_authz__dvicory_uplink{{"opkssh-authz/dvicory@uplink"}}
      axon_02__opkssh_authz__pol_axon_01{{"opkssh-authz/pol@axon-01"}}
      axon_02__opkssh_authz__pol_axon_02{{"opkssh-authz/pol@axon-02"}}
      axon_02__opkssh_authz__pol_axon_03{{"opkssh-authz/pol@axon-03"}}
      axon_02__opkssh_authz__pol_bitstream{{"opkssh-authz/pol@bitstream"}}
      axon_02__opkssh_authz__pol_uplink{{"opkssh-authz/pol@uplink"}}
      axon_02__opkssh_authz__sini_axon_01{{"opkssh-authz/sini@axon-01"}}
      axon_02__opkssh_authz__sini_axon_02{{"opkssh-authz/sini@axon-02"}}
      axon_02__opkssh_authz__sini_axon_03{{"opkssh-authz/sini@axon-03"}}
      axon_02__opkssh_authz__sini_bitstream{{"opkssh-authz/sini@bitstream"}}
      axon_02__opkssh_authz__sini_blade{{"opkssh-authz/sini@blade"}}
      axon_02__opkssh_authz__sini_cortex{{"opkssh-authz/sini@cortex"}}
      axon_02__opkssh_authz__sini_patch{{"opkssh-authz/sini@patch"}}
      axon_02__opkssh_authz__sini_slab{{"opkssh-authz/sini@slab"}}
      axon_02__opkssh_authz__sini_uplink{{"opkssh-authz/sini@uplink"}}
      axon_02__opkssh_authz__theutz_axon_01{{"opkssh-authz/theutz@axon-01"}}
      axon_02__opkssh_authz__theutz_axon_02{{"opkssh-authz/theutz@axon-02"}}
      axon_02__opkssh_authz__theutz_axon_03{{"opkssh-authz/theutz@axon-03"}}
      axon_02__opkssh_authz__theutz_bitstream{{"opkssh-authz/theutz@bitstream"}}
      axon_02__opkssh_authz__theutz_uplink{{"opkssh-authz/theutz@uplink"}}
      axon_02__opkssh_authz__vic_axon_01{{"opkssh-authz/vic@axon-01"}}
      axon_02__opkssh_authz__vic_axon_02{{"opkssh-authz/vic@axon-02"}}
      axon_02__opkssh_authz__vic_axon_03{{"opkssh-authz/vic@axon-03"}}
      axon_02__opkssh_authz__vic_bitstream{{"opkssh-authz/vic@bitstream"}}
      axon_02__opkssh_authz__vic_blade{{"opkssh-authz/vic@blade"}}
      axon_02__opkssh_authz__vic_cortex{{"opkssh-authz/vic@cortex"}}
      axon_02__opkssh_authz__vic_uplink{{"opkssh-authz/vic@uplink"}}
      axon_02__roles__server[/"roles/server"\]
      axon_02__core__secrets__collector[/"secrets/collector"\]
      axon_02__services__security__acme[/"security/acme"\]
      axon_02__services__security__tang[/"security/tang"\]
      axon_02__services__bgp[/"services/bgp"\]
      axon_02__services__k3s[/"services/k3s"\]
      axon_02__services__storage__media_data_share[/"storage/media-data-share"\]
      axon_02__unfree_predicate__os{{"unfree-predicate/os"}}
      axon_02__user_enrich__dvicory_axon_01{{"user-enrich/dvicory@axon-01"}}
      axon_02__user_enrich__dvicory_axon_02{{"user-enrich/dvicory@axon-02"}}
      axon_02__user_enrich__dvicory_axon_03{{"user-enrich/dvicory@axon-03"}}
      axon_02__user_enrich__dvicory_bitstream{{"user-enrich/dvicory@bitstream"}}
      axon_02__user_enrich__dvicory_uplink{{"user-enrich/dvicory@uplink"}}
      axon_02__user_enrich__pol_axon_01{{"user-enrich/pol@axon-01"}}
      axon_02__user_enrich__pol_axon_02{{"user-enrich/pol@axon-02"}}
      axon_02__user_enrich__pol_axon_03{{"user-enrich/pol@axon-03"}}
      axon_02__user_enrich__pol_bitstream{{"user-enrich/pol@bitstream"}}
      axon_02__user_enrich__pol_uplink{{"user-enrich/pol@uplink"}}
      axon_02__user_enrich__sini_axon_01{{"user-enrich/sini@axon-01"}}
      axon_02__user_enrich__sini_axon_02{{"user-enrich/sini@axon-02"}}
      axon_02__user_enrich__sini_axon_03{{"user-enrich/sini@axon-03"}}
      axon_02__user_enrich__sini_bitstream{{"user-enrich/sini@bitstream"}}
      axon_02__user_enrich__sini_blade{{"user-enrich/sini@blade"}}
      axon_02__user_enrich__sini_cortex{{"user-enrich/sini@cortex"}}
      axon_02__user_enrich__sini_patch{{"user-enrich/sini@patch"}}
      axon_02__user_enrich__sini_slab{{"user-enrich/sini@slab"}}
      axon_02__user_enrich__sini_uplink{{"user-enrich/sini@uplink"}}
      axon_02__user_enrich__theutz_axon_01{{"user-enrich/theutz@axon-01"}}
      axon_02__user_enrich__theutz_axon_02{{"user-enrich/theutz@axon-02"}}
      axon_02__user_enrich__theutz_axon_03{{"user-enrich/theutz@axon-03"}}
      axon_02__user_enrich__theutz_bitstream{{"user-enrich/theutz@bitstream"}}
      axon_02__user_enrich__theutz_uplink{{"user-enrich/theutz@uplink"}}
      axon_02__user_enrich__vic_axon_01{{"user-enrich/vic@axon-01"}}
      axon_02__user_enrich__vic_axon_02{{"user-enrich/vic@axon-02"}}
      axon_02__user_enrich__vic_axon_03{{"user-enrich/vic@axon-03"}}
      axon_02__user_enrich__vic_bitstream{{"user-enrich/vic@bitstream"}}
      axon_02__user_enrich__vic_blade{{"user-enrich/vic@blade"}}
      axon_02__user_enrich__vic_cortex{{"user-enrich/vic@cortex"}}
      axon_02__user_enrich__vic_uplink{{"user-enrich/vic@uplink"}}
      axon_02__disk__zfs_disk_single__root[/"zfs-disk-single/root"\]
      axon_02__axon_02 --> axon_02__hardware__cpu__amd
      axon_02__axon_02 --> axon_02__hardware__gpu__amd
      axon_02__axon_02 --> axon_02__services__bgp__cilium_bgp
      axon_02__axon_02 --> axon_02__services__k3s
      axon_02__axon_02 --> axon_02__core__boot__network_initrd
      axon_02__axon_02 --> axon_02__roles__server
      axon_02__axon_02 --> axon_02__services__networking__thunderbolt_mesh_of
      axon_02__axon_02 --> axon_02__disk__xfs_disk_longhorn
      axon_02__axon_02 --> axon_02__disk__zfs_disk_single
      axon_02__core__impermanence_user_dvicory --> axon_02__core__impermanence__btrfs_user_dvicory
      axon_02__core__impermanence_user_pol --> axon_02__core__impermanence__btrfs_user_pol
      axon_02__core__impermanence_user_theutz --> axon_02__core__impermanence__btrfs_user_theutz
      axon_02__core__impermanence_user_vic --> axon_02__core__impermanence__btrfs_user_vic
      axon_02__core__impermanence_host_axon_02 --> axon_02__core__impermanence__btrfs_host_axon_02
      axon_02__core__impermanence_user_dvicory --> axon_02__core__impermanence__persist_collector_user_dvicory
      axon_02__core__impermanence_user_pol --> axon_02__core__impermanence__persist_collector_user_pol
      axon_02__core__impermanence_user_theutz --> axon_02__core__impermanence__persist_collector_user_theutz
      axon_02__core__impermanence_user_vic --> axon_02__core__impermanence__persist_collector_user_vic
      axon_02__core__impermanence_host_axon_02 --> axon_02__core__impermanence__persist_collector_host_axon_02
      axon_02__core__impermanence_user_dvicory --> axon_02__core__impermanence__zfs_user_dvicory
      axon_02__core__impermanence_user_pol --> axon_02__core__impermanence__zfs_user_pol
      axon_02__core__impermanence_user_theutz --> axon_02__core__impermanence__zfs_user_theutz
      axon_02__core__impermanence_user_vic --> axon_02__core__impermanence__zfs_user_vic
      axon_02__core__impermanence_host_axon_02 --> axon_02__core__impermanence__zfs_host_axon_02
      axon_02__disk__zfs_disk_single --> axon_02__disk__zfs_disk_single__root
      axon_02__disk__zfs_disk_single__root --> axon_02__disk__zfs_diff
      axon_02__roles__server --> axon_02__services__security__acme
      axon_02__roles__server --> axon_02__services__storage__media_data_share
      axon_02__roles__server --> axon_02__services__monitoring__prometheus_exporter
      axon_02__roles__server --> axon_02__services__security__tang
      axon_02__services__k3s --> axon_02__services__k3s__bootstrap
      axon_02__services__k3s --> axon_02__services__k3s__containerd
      axon_02__services__k3s --> axon_02__services__k3s__node
      axon_02__services__k3s --> axon_02__services__k3s__node_lifecycle
      axon_02__services__networking__thunderbolt_mesh_of --> axon_02__hardware__thunderbolt_network
    end
    subgraph host_axon_03["axon-03"]
      axon_03__agenix_identity__dvicory_axon_01{{"agenix-identity/dvicory@axon-01"}}
      axon_03__agenix_identity__dvicory_axon_02{{"agenix-identity/dvicory@axon-02"}}
      axon_03__agenix_identity__dvicory_axon_03{{"agenix-identity/dvicory@axon-03"}}
      axon_03__agenix_identity__dvicory_bitstream{{"agenix-identity/dvicory@bitstream"}}
      axon_03__agenix_identity__dvicory_uplink{{"agenix-identity/dvicory@uplink"}}
      axon_03__agenix_identity__pol_axon_01{{"agenix-identity/pol@axon-01"}}
      axon_03__agenix_identity__pol_axon_02{{"agenix-identity/pol@axon-02"}}
      axon_03__agenix_identity__pol_axon_03{{"agenix-identity/pol@axon-03"}}
      axon_03__agenix_identity__pol_bitstream{{"agenix-identity/pol@bitstream"}}
      axon_03__agenix_identity__pol_uplink{{"agenix-identity/pol@uplink"}}
      axon_03__agenix_identity__sini_axon_01{{"agenix-identity/sini@axon-01"}}
      axon_03__agenix_identity__sini_axon_02{{"agenix-identity/sini@axon-02"}}
      axon_03__agenix_identity__sini_axon_03{{"agenix-identity/sini@axon-03"}}
      axon_03__agenix_identity__sini_bitstream{{"agenix-identity/sini@bitstream"}}
      axon_03__agenix_identity__sini_blade{{"agenix-identity/sini@blade"}}
      axon_03__agenix_identity__sini_cortex{{"agenix-identity/sini@cortex"}}
      axon_03__agenix_identity__sini_uplink{{"agenix-identity/sini@uplink"}}
      axon_03__agenix_identity__theutz_axon_01{{"agenix-identity/theutz@axon-01"}}
      axon_03__agenix_identity__theutz_axon_02{{"agenix-identity/theutz@axon-02"}}
      axon_03__agenix_identity__theutz_axon_03{{"agenix-identity/theutz@axon-03"}}
      axon_03__agenix_identity__theutz_bitstream{{"agenix-identity/theutz@bitstream"}}
      axon_03__agenix_identity__theutz_uplink{{"agenix-identity/theutz@uplink"}}
      axon_03__agenix_identity__vic_axon_01{{"agenix-identity/vic@axon-01"}}
      axon_03__agenix_identity__vic_axon_02{{"agenix-identity/vic@axon-02"}}
      axon_03__agenix_identity__vic_axon_03{{"agenix-identity/vic@axon-03"}}
      axon_03__agenix_identity__vic_bitstream{{"agenix-identity/vic@bitstream"}}
      axon_03__agenix_identity__vic_blade{{"agenix-identity/vic@blade"}}
      axon_03__agenix_identity__vic_cortex{{"agenix-identity/vic@cortex"}}
      axon_03__agenix_identity__vic_uplink{{"agenix-identity/vic@uplink"}}
      axon_03__agenix__axon_03{{"agenix/axon-03"}}
      axon_03__axon_03{{"axon-03"}}
      axon_03__den__batteries__define_user__dvicory_axon_03{{"batteries/define-user/dvicory@axon-03"}}
      axon_03__den__batteries__define_user__pol_axon_03{{"batteries/define-user/pol@axon-03"}}
      axon_03__den__batteries__define_user__sini_axon_03{{"batteries/define-user/sini@axon-03"}}
      axon_03__den__batteries__define_user__theutz_axon_03{{"batteries/define-user/theutz@axon-03"}}
      axon_03__den__batteries__define_user__vic_axon_03{{"batteries/define-user/vic@axon-03"}}
      axon_03__den__batteries__hostname__os{{"batteries/hostname/os"}}
      axon_03__den__batteries__inputs___os{{"batteries/inputs'/os"}}
      axon_03__den__batteries__primary_user_sini_axon_01_{{"batteries/primary-user(sini@axon-01)"}}
      axon_03__den__batteries__primary_user_sini_axon_02_{{"batteries/primary-user(sini@axon-02)"}}
      axon_03__den__batteries__primary_user_sini_axon_03_{{"batteries/primary-user(sini@axon-03)"}}
      axon_03__den__batteries__primary_user_sini_bitstream_{{"batteries/primary-user(sini@bitstream)"}}
      axon_03__den__batteries__primary_user_sini_blade_{{"batteries/primary-user(sini@blade)"}}
      axon_03__den__batteries__primary_user_sini_cortex_{{"batteries/primary-user(sini@cortex)"}}
      axon_03__den__batteries__primary_user_sini_patch_{{"batteries/primary-user(sini@patch)"}}
      axon_03__den__batteries__primary_user_sini_slab_{{"batteries/primary-user(sini@slab)"}}
      axon_03__den__batteries__primary_user_sini_uplink_{{"batteries/primary-user(sini@uplink)"}}
      axon_03__den__batteries__self___os{{"batteries/self'/os"}}
      axon_03__services__bgp__cilium_bgp[/"bgp/cilium-bgp"\]
      axon_03__core__boot__network_initrd[/"boot/network-initrd"\]
      axon_03__core__impermanence_user_dvicory[/"core/impermanence"\]
      axon_03__core__impermanence_user_pol[/"core/impermanence"\]
      axon_03__core__impermanence_user_theutz[/"core/impermanence"\]
      axon_03__core__impermanence_user_vic[/"core/impermanence"\]
      axon_03__core__impermanence_host_axon_03[/"core/impermanence"\]
      axon_03__core__impermanence__btrfs_user_dvicory[/"core/impermanence/btrfs"\]
      axon_03__core__impermanence__btrfs_user_pol[/"core/impermanence/btrfs"\]
      axon_03__core__impermanence__btrfs_user_theutz[/"core/impermanence/btrfs"\]
      axon_03__core__impermanence__btrfs_user_vic[/"core/impermanence/btrfs"\]
      axon_03__core__impermanence__btrfs_host_axon_03[/"core/impermanence/btrfs"\]
      axon_03__core__impermanence__persist_collector_user_dvicory[/"core/impermanence/persist-collector"\]
      axon_03__core__impermanence__persist_collector_user_pol[/"core/impermanence/persist-collector"\]
      axon_03__core__impermanence__persist_collector_user_theutz[/"core/impermanence/persist-collector"\]
      axon_03__core__impermanence__persist_collector_user_vic[/"core/impermanence/persist-collector"\]
      axon_03__core__impermanence__persist_collector_host_axon_03[/"core/impermanence/persist-collector"\]
      axon_03__core__impermanence__zfs_user_dvicory[/"core/impermanence/zfs"\]
      axon_03__core__impermanence__zfs_user_pol[/"core/impermanence/zfs"\]
      axon_03__core__impermanence__zfs_user_theutz[/"core/impermanence/zfs"\]
      axon_03__core__impermanence__zfs_user_vic[/"core/impermanence/zfs"\]
      axon_03__core__impermanence__zfs_host_axon_03[/"core/impermanence/zfs"\]
      axon_03__core__localization__i18n_user_dvicory[/"core/localization/i18n"\]
      axon_03__core__localization__i18n_user_pol[/"core/localization/i18n"\]
      axon_03__core__localization__i18n_user_theutz[/"core/localization/i18n"\]
      axon_03__core__localization__i18n_user_vic[/"core/localization/i18n"\]
      axon_03__core__localization__i18n_host_axon_03[/"core/localization/i18n"\]
      axon_03__core__network__hostsfile_user_dvicory[/"core/network/hostsfile"\]
      axon_03__core__network__hostsfile_user_pol[/"core/network/hostsfile"\]
      axon_03__core__network__hostsfile_user_theutz[/"core/network/hostsfile"\]
      axon_03__core__network__hostsfile_user_vic[/"core/network/hostsfile"\]
      axon_03__core__network__hostsfile_host_axon_03[/"core/network/hostsfile"\]
      axon_03__core__network__networking_user_dvicory[/"core/network/networking"\]
      axon_03__core__network__networking_user_pol[/"core/network/networking"\]
      axon_03__core__network__networking_user_theutz[/"core/network/networking"\]
      axon_03__core__network__networking_user_vic[/"core/network/networking"\]
      axon_03__core__network__networking_host_axon_03[/"core/network/networking"\]
      axon_03__core__network__syncthing__peer_user_sini[/"core/network/syncthing/peer"\]
      axon_03__core__network__syncthing__peer_user_dvicory[/"core/network/syncthing/peer"\]
      axon_03__core__network__syncthing__peer_user_pol[/"core/network/syncthing/peer"\]
      axon_03__core__network__syncthing__peer_user_theutz[/"core/network/syncthing/peer"\]
      axon_03__core__network__syncthing__peer_user_vic[/"core/network/syncthing/peer"\]
      axon_03__core__network__tailscale_user_dvicory[/"core/network/tailscale"\]
      axon_03__core__network__tailscale_user_pol[/"core/network/tailscale"\]
      axon_03__core__network__tailscale_user_theutz[/"core/network/tailscale"\]
      axon_03__core__network__tailscale_user_vic[/"core/network/tailscale"\]
      axon_03__core__network__tailscale_host_axon_03[/"core/network/tailscale"\]
      axon_03__core__nix_user_dvicory[/"core/nix"\]
      axon_03__core__nix_user_pol[/"core/nix"\]
      axon_03__core__nix_user_theutz[/"core/nix"\]
      axon_03__core__nix_user_vic[/"core/nix"\]
      axon_03__core__nix_host_axon_03[/"core/nix"\]
      axon_03__core__nix__stateVersion_user_dvicory[/"core/nix/stateVersion"\]
      axon_03__core__nix__stateVersion_user_pol[/"core/nix/stateVersion"\]
      axon_03__core__nix__stateVersion_user_theutz[/"core/nix/stateVersion"\]
      axon_03__core__nix__stateVersion_user_vic[/"core/nix/stateVersion"\]
      axon_03__core__nix__stateVersion_host_axon_03[/"core/nix/stateVersion"\]
      axon_03__core__perf__disable_docs_user_dvicory[/"core/perf/disable-docs"\]
      axon_03__core__perf__disable_docs_user_pol[/"core/perf/disable-docs"\]
      axon_03__core__perf__disable_docs_user_theutz[/"core/perf/disable-docs"\]
      axon_03__core__perf__disable_docs_user_vic[/"core/perf/disable-docs"\]
      axon_03__core__perf__disable_docs_host_axon_03[/"core/perf/disable-docs"\]
      axon_03__core__perf__ssd_user_dvicory[/"core/perf/ssd"\]
      axon_03__core__perf__ssd_user_pol[/"core/perf/ssd"\]
      axon_03__core__perf__ssd_user_theutz[/"core/perf/ssd"\]
      axon_03__core__perf__ssd_user_vic[/"core/perf/ssd"\]
      axon_03__core__perf__ssd_host_axon_03[/"core/perf/ssd"\]
      axon_03__core__perf__zram_swap_user_dvicory[/"core/perf/zram-swap"\]
      axon_03__core__perf__zram_swap_user_pol[/"core/perf/zram-swap"\]
      axon_03__core__perf__zram_swap_user_theutz[/"core/perf/zram-swap"\]
      axon_03__core__perf__zram_swap_user_vic[/"core/perf/zram-swap"\]
      axon_03__core__perf__zram_swap_host_axon_03[/"core/perf/zram-swap"\]
      axon_03__core__security_user_dvicory[/"core/security"\]
      axon_03__core__security_user_pol[/"core/security"\]
      axon_03__core__security_user_theutz[/"core/security"\]
      axon_03__core__security_user_vic[/"core/security"\]
      axon_03__core__security_host_axon_03[/"core/security"\]
      axon_03__core__security__openssh_user_dvicory[/"core/security/openssh"\]
      axon_03__core__security__openssh_user_pol[/"core/security/openssh"\]
      axon_03__core__security__openssh_user_theutz[/"core/security/openssh"\]
      axon_03__core__security__openssh_user_vic[/"core/security/openssh"\]
      axon_03__core__security__openssh_host_axon_03[/"core/security/openssh"\]
      axon_03__core__security__opkssh_user_dvicory[/"core/security/opkssh"\]
      axon_03__core__security__opkssh_user_pol[/"core/security/opkssh"\]
      axon_03__core__security__opkssh_user_theutz[/"core/security/opkssh"\]
      axon_03__core__security__opkssh_user_vic[/"core/security/opkssh"\]
      axon_03__core__security__opkssh_host_axon_03[/"core/security/opkssh"\]
      axon_03__core__security__sudo_user_dvicory[/"core/security/sudo"\]
      axon_03__core__security__sudo_user_pol[/"core/security/sudo"\]
      axon_03__core__security__sudo_user_theutz[/"core/security/sudo"\]
      axon_03__core__security__sudo_user_vic[/"core/security/sudo"\]
      axon_03__core__security__sudo_host_axon_03[/"core/security/sudo"\]
      axon_03__core__system__facter_user_dvicory[/"core/system/facter"\]
      axon_03__core__system__facter_user_pol[/"core/system/facter"\]
      axon_03__core__system__facter_user_theutz[/"core/system/facter"\]
      axon_03__core__system__facter_user_vic[/"core/system/facter"\]
      axon_03__core__system__facter_host_axon_03[/"core/system/facter"\]
      axon_03__core__system__firmware_user_dvicory[/"core/system/firmware"\]
      axon_03__core__system__firmware_user_pol[/"core/system/firmware"\]
      axon_03__core__system__firmware_user_theutz[/"core/system/firmware"\]
      axon_03__core__system__firmware_user_vic[/"core/system/firmware"\]
      axon_03__core__system__firmware_host_axon_03[/"core/system/firmware"\]
      axon_03__core__system__linux_kernel_user_dvicory[/"core/system/linux-kernel"\]
      axon_03__core__system__linux_kernel_user_pol[/"core/system/linux-kernel"\]
      axon_03__core__system__linux_kernel_user_theutz[/"core/system/linux-kernel"\]
      axon_03__core__system__linux_kernel_user_vic[/"core/system/linux-kernel"\]
      axon_03__core__system__linux_kernel_host_axon_03[/"core/system/linux-kernel"\]
      axon_03__core__systemd_user_dvicory[/"core/systemd"\]
      axon_03__core__systemd_user_pol[/"core/systemd"\]
      axon_03__core__systemd_user_theutz[/"core/systemd"\]
      axon_03__core__systemd_user_vic[/"core/systemd"\]
      axon_03__core__systemd_host_axon_03[/"core/systemd"\]
      axon_03__core__systemd__boot_user_dvicory[/"core/systemd/boot"\]
      axon_03__core__systemd__boot_user_pol[/"core/systemd/boot"\]
      axon_03__core__systemd__boot_user_theutz[/"core/systemd/boot"\]
      axon_03__core__systemd__boot_user_vic[/"core/systemd/boot"\]
      axon_03__core__systemd__boot_host_axon_03[/"core/systemd/boot"\]
      axon_03__core__users_user_dvicory[/"core/users"\]
      axon_03__core__users_user_pol[/"core/users"\]
      axon_03__core__users_user_theutz[/"core/users"\]
      axon_03__core__users_user_vic[/"core/users"\]
      axon_03__core__users_host_axon_03[/"core/users"\]
      axon_03__core__users__deterministic_uids_user_dvicory[/"core/users/deterministic-uids"\]
      axon_03__core__users__deterministic_uids_user_pol[/"core/users/deterministic-uids"\]
      axon_03__core__users__deterministic_uids_user_theutz[/"core/users/deterministic-uids"\]
      axon_03__core__users__deterministic_uids_user_vic[/"core/users/deterministic-uids"\]
      axon_03__core__users__deterministic_uids_host_axon_03[/"core/users/deterministic-uids"\]
      axon_03__core__users__home_manager_shared_user_dvicory[/"core/users/home-manager-shared"\]
      axon_03__core__users__home_manager_shared_user_pol[/"core/users/home-manager-shared"\]
      axon_03__core__users__home_manager_shared_user_theutz[/"core/users/home-manager-shared"\]
      axon_03__core__users__home_manager_shared_user_vic[/"core/users/home-manager-shared"\]
      axon_03__core__users__home_manager_shared_host_axon_03[/"core/users/home-manager-shared"\]
      axon_03__core__users__shell_user_dvicory[/"core/users/shell"\]
      axon_03__core__users__shell_user_pol[/"core/users/shell"\]
      axon_03__core__users__shell_user_theutz[/"core/users/shell"\]
      axon_03__core__users__shell_user_vic[/"core/users/shell"\]
      axon_03__core__users__shell_host_axon_03[/"core/users/shell"\]
      axon_03__core__utils_user_dvicory[/"core/utils"\]
      axon_03__core__utils_user_pol[/"core/utils"\]
      axon_03__core__utils_user_theutz[/"core/utils"\]
      axon_03__core__utils_user_vic[/"core/utils"\]
      axon_03__core__utils_host_axon_03[/"core/utils"\]
      axon_03__hardware__cpu__amd[/"cpu/amd"\]
      axon_03__disk__xfs_disk_longhorn[/"disk/xfs-disk-longhorn"\]
      axon_03__disk__zfs_diff[/"disk/zfs-diff"\]
      axon_03__disk__zfs_disk_single[/"disk/zfs-disk-single"\]
      axon_03__hardware__gpu__amd[/"gpu/amd"\]
      axon_03__hardware__thunderbolt_network[/"hardware/thunderbolt-network"\]
      axon_03__insecure_predicate__os{{"insecure-predicate/os"}}
      axon_03__services__k3s__bootstrap[/"k3s/bootstrap"\]
      axon_03__services__k3s__containerd[/"k3s/containerd"\]
      axon_03__services__k3s__node[/"k3s/node"\]
      axon_03__services__k3s__node_lifecycle[/"k3s/node-lifecycle"\]
      axon_03__services__monitoring__prometheus_exporter[/"monitoring/prometheus-exporter"\]
      axon_03__core__network__firewall_collector[/"network/firewall-collector"\]
      axon_03__services__networking__thunderbolt_mesh_of[/"networking/thunderbolt-mesh-of"\]
      axon_03__services__nix__remote_build_server[/"nix/remote-build-server"\]
      axon_03__opkssh_authz__dvicory_axon_01{{"opkssh-authz/dvicory@axon-01"}}
      axon_03__opkssh_authz__dvicory_axon_02{{"opkssh-authz/dvicory@axon-02"}}
      axon_03__opkssh_authz__dvicory_axon_03{{"opkssh-authz/dvicory@axon-03"}}
      axon_03__opkssh_authz__dvicory_bitstream{{"opkssh-authz/dvicory@bitstream"}}
      axon_03__opkssh_authz__dvicory_uplink{{"opkssh-authz/dvicory@uplink"}}
      axon_03__opkssh_authz__pol_axon_01{{"opkssh-authz/pol@axon-01"}}
      axon_03__opkssh_authz__pol_axon_02{{"opkssh-authz/pol@axon-02"}}
      axon_03__opkssh_authz__pol_axon_03{{"opkssh-authz/pol@axon-03"}}
      axon_03__opkssh_authz__pol_bitstream{{"opkssh-authz/pol@bitstream"}}
      axon_03__opkssh_authz__pol_uplink{{"opkssh-authz/pol@uplink"}}
      axon_03__opkssh_authz__sini_axon_01{{"opkssh-authz/sini@axon-01"}}
      axon_03__opkssh_authz__sini_axon_02{{"opkssh-authz/sini@axon-02"}}
      axon_03__opkssh_authz__sini_axon_03{{"opkssh-authz/sini@axon-03"}}
      axon_03__opkssh_authz__sini_bitstream{{"opkssh-authz/sini@bitstream"}}
      axon_03__opkssh_authz__sini_blade{{"opkssh-authz/sini@blade"}}
      axon_03__opkssh_authz__sini_cortex{{"opkssh-authz/sini@cortex"}}
      axon_03__opkssh_authz__sini_patch{{"opkssh-authz/sini@patch"}}
      axon_03__opkssh_authz__sini_slab{{"opkssh-authz/sini@slab"}}
      axon_03__opkssh_authz__sini_uplink{{"opkssh-authz/sini@uplink"}}
      axon_03__opkssh_authz__theutz_axon_01{{"opkssh-authz/theutz@axon-01"}}
      axon_03__opkssh_authz__theutz_axon_02{{"opkssh-authz/theutz@axon-02"}}
      axon_03__opkssh_authz__theutz_axon_03{{"opkssh-authz/theutz@axon-03"}}
      axon_03__opkssh_authz__theutz_bitstream{{"opkssh-authz/theutz@bitstream"}}
      axon_03__opkssh_authz__theutz_uplink{{"opkssh-authz/theutz@uplink"}}
      axon_03__opkssh_authz__vic_axon_01{{"opkssh-authz/vic@axon-01"}}
      axon_03__opkssh_authz__vic_axon_02{{"opkssh-authz/vic@axon-02"}}
      axon_03__opkssh_authz__vic_axon_03{{"opkssh-authz/vic@axon-03"}}
      axon_03__opkssh_authz__vic_bitstream{{"opkssh-authz/vic@bitstream"}}
      axon_03__opkssh_authz__vic_blade{{"opkssh-authz/vic@blade"}}
      axon_03__opkssh_authz__vic_cortex{{"opkssh-authz/vic@cortex"}}
      axon_03__opkssh_authz__vic_uplink{{"opkssh-authz/vic@uplink"}}
      axon_03__roles__server[/"roles/server"\]
      axon_03__core__secrets__collector[/"secrets/collector"\]
      axon_03__services__security__acme[/"security/acme"\]
      axon_03__services__security__tang[/"security/tang"\]
      axon_03__services__bgp[/"services/bgp"\]
      axon_03__services__k3s[/"services/k3s"\]
      axon_03__services__storage__media_data_share[/"storage/media-data-share"\]
      axon_03__unfree_predicate__os{{"unfree-predicate/os"}}
      axon_03__user_enrich__dvicory_axon_01{{"user-enrich/dvicory@axon-01"}}
      axon_03__user_enrich__dvicory_axon_02{{"user-enrich/dvicory@axon-02"}}
      axon_03__user_enrich__dvicory_axon_03{{"user-enrich/dvicory@axon-03"}}
      axon_03__user_enrich__dvicory_bitstream{{"user-enrich/dvicory@bitstream"}}
      axon_03__user_enrich__dvicory_uplink{{"user-enrich/dvicory@uplink"}}
      axon_03__user_enrich__pol_axon_01{{"user-enrich/pol@axon-01"}}
      axon_03__user_enrich__pol_axon_02{{"user-enrich/pol@axon-02"}}
      axon_03__user_enrich__pol_axon_03{{"user-enrich/pol@axon-03"}}
      axon_03__user_enrich__pol_bitstream{{"user-enrich/pol@bitstream"}}
      axon_03__user_enrich__pol_uplink{{"user-enrich/pol@uplink"}}
      axon_03__user_enrich__sini_axon_01{{"user-enrich/sini@axon-01"}}
      axon_03__user_enrich__sini_axon_02{{"user-enrich/sini@axon-02"}}
      axon_03__user_enrich__sini_axon_03{{"user-enrich/sini@axon-03"}}
      axon_03__user_enrich__sini_bitstream{{"user-enrich/sini@bitstream"}}
      axon_03__user_enrich__sini_blade{{"user-enrich/sini@blade"}}
      axon_03__user_enrich__sini_cortex{{"user-enrich/sini@cortex"}}
      axon_03__user_enrich__sini_patch{{"user-enrich/sini@patch"}}
      axon_03__user_enrich__sini_slab{{"user-enrich/sini@slab"}}
      axon_03__user_enrich__sini_uplink{{"user-enrich/sini@uplink"}}
      axon_03__user_enrich__theutz_axon_01{{"user-enrich/theutz@axon-01"}}
      axon_03__user_enrich__theutz_axon_02{{"user-enrich/theutz@axon-02"}}
      axon_03__user_enrich__theutz_axon_03{{"user-enrich/theutz@axon-03"}}
      axon_03__user_enrich__theutz_bitstream{{"user-enrich/theutz@bitstream"}}
      axon_03__user_enrich__theutz_uplink{{"user-enrich/theutz@uplink"}}
      axon_03__user_enrich__vic_axon_01{{"user-enrich/vic@axon-01"}}
      axon_03__user_enrich__vic_axon_02{{"user-enrich/vic@axon-02"}}
      axon_03__user_enrich__vic_axon_03{{"user-enrich/vic@axon-03"}}
      axon_03__user_enrich__vic_bitstream{{"user-enrich/vic@bitstream"}}
      axon_03__user_enrich__vic_blade{{"user-enrich/vic@blade"}}
      axon_03__user_enrich__vic_cortex{{"user-enrich/vic@cortex"}}
      axon_03__user_enrich__vic_uplink{{"user-enrich/vic@uplink"}}
      axon_03__disk__zfs_disk_single__root[/"zfs-disk-single/root"\]
      axon_03__axon_03 --> axon_03__hardware__cpu__amd
      axon_03__axon_03 --> axon_03__hardware__gpu__amd
      axon_03__axon_03 --> axon_03__services__bgp__cilium_bgp
      axon_03__axon_03 --> axon_03__services__k3s
      axon_03__axon_03 --> axon_03__core__boot__network_initrd
      axon_03__axon_03 --> axon_03__roles__server
      axon_03__axon_03 --> axon_03__services__networking__thunderbolt_mesh_of
      axon_03__axon_03 --> axon_03__disk__xfs_disk_longhorn
      axon_03__axon_03 --> axon_03__disk__zfs_disk_single
      axon_03__core__impermanence_user_dvicory --> axon_03__core__impermanence__btrfs_user_dvicory
      axon_03__core__impermanence_user_pol --> axon_03__core__impermanence__btrfs_user_pol
      axon_03__core__impermanence_user_theutz --> axon_03__core__impermanence__btrfs_user_theutz
      axon_03__core__impermanence_user_vic --> axon_03__core__impermanence__btrfs_user_vic
      axon_03__core__impermanence_host_axon_03 --> axon_03__core__impermanence__btrfs_host_axon_03
      axon_03__core__impermanence_user_dvicory --> axon_03__core__impermanence__persist_collector_user_dvicory
      axon_03__core__impermanence_user_pol --> axon_03__core__impermanence__persist_collector_user_pol
      axon_03__core__impermanence_user_theutz --> axon_03__core__impermanence__persist_collector_user_theutz
      axon_03__core__impermanence_user_vic --> axon_03__core__impermanence__persist_collector_user_vic
      axon_03__core__impermanence_host_axon_03 --> axon_03__core__impermanence__persist_collector_host_axon_03
      axon_03__core__impermanence_user_dvicory --> axon_03__core__impermanence__zfs_user_dvicory
      axon_03__core__impermanence_user_pol --> axon_03__core__impermanence__zfs_user_pol
      axon_03__core__impermanence_user_theutz --> axon_03__core__impermanence__zfs_user_theutz
      axon_03__core__impermanence_user_vic --> axon_03__core__impermanence__zfs_user_vic
      axon_03__core__impermanence_host_axon_03 --> axon_03__core__impermanence__zfs_host_axon_03
      axon_03__disk__zfs_disk_single --> axon_03__disk__zfs_disk_single__root
      axon_03__disk__zfs_disk_single__root --> axon_03__disk__zfs_diff
      axon_03__roles__server --> axon_03__services__security__acme
      axon_03__roles__server --> axon_03__services__storage__media_data_share
      axon_03__roles__server --> axon_03__services__monitoring__prometheus_exporter
      axon_03__roles__server --> axon_03__services__security__tang
      axon_03__services__k3s --> axon_03__services__k3s__bootstrap
      axon_03__services__k3s --> axon_03__services__k3s__containerd
      axon_03__services__k3s --> axon_03__services__k3s__node
      axon_03__services__k3s --> axon_03__services__k3s__node_lifecycle
      axon_03__services__networking__thunderbolt_mesh_of --> axon_03__hardware__thunderbolt_network
    end
    subgraph host_uplink["uplink"]
      uplink__agenix_identity__dvicory_axon_01{{"agenix-identity/dvicory@axon-01"}}
      uplink__agenix_identity__dvicory_axon_02{{"agenix-identity/dvicory@axon-02"}}
      uplink__agenix_identity__dvicory_axon_03{{"agenix-identity/dvicory@axon-03"}}
      uplink__agenix_identity__dvicory_bitstream{{"agenix-identity/dvicory@bitstream"}}
      uplink__agenix_identity__dvicory_uplink{{"agenix-identity/dvicory@uplink"}}
      uplink__agenix_identity__pol_axon_01{{"agenix-identity/pol@axon-01"}}
      uplink__agenix_identity__pol_axon_02{{"agenix-identity/pol@axon-02"}}
      uplink__agenix_identity__pol_axon_03{{"agenix-identity/pol@axon-03"}}
      uplink__agenix_identity__pol_bitstream{{"agenix-identity/pol@bitstream"}}
      uplink__agenix_identity__pol_uplink{{"agenix-identity/pol@uplink"}}
      uplink__agenix_identity__sini_axon_01{{"agenix-identity/sini@axon-01"}}
      uplink__agenix_identity__sini_axon_02{{"agenix-identity/sini@axon-02"}}
      uplink__agenix_identity__sini_axon_03{{"agenix-identity/sini@axon-03"}}
      uplink__agenix_identity__sini_bitstream{{"agenix-identity/sini@bitstream"}}
      uplink__agenix_identity__sini_blade{{"agenix-identity/sini@blade"}}
      uplink__agenix_identity__sini_cortex{{"agenix-identity/sini@cortex"}}
      uplink__agenix_identity__sini_uplink{{"agenix-identity/sini@uplink"}}
      uplink__agenix_identity__theutz_axon_01{{"agenix-identity/theutz@axon-01"}}
      uplink__agenix_identity__theutz_axon_02{{"agenix-identity/theutz@axon-02"}}
      uplink__agenix_identity__theutz_axon_03{{"agenix-identity/theutz@axon-03"}}
      uplink__agenix_identity__theutz_bitstream{{"agenix-identity/theutz@bitstream"}}
      uplink__agenix_identity__theutz_uplink{{"agenix-identity/theutz@uplink"}}
      uplink__agenix_identity__vic_axon_01{{"agenix-identity/vic@axon-01"}}
      uplink__agenix_identity__vic_axon_02{{"agenix-identity/vic@axon-02"}}
      uplink__agenix_identity__vic_axon_03{{"agenix-identity/vic@axon-03"}}
      uplink__agenix_identity__vic_bitstream{{"agenix-identity/vic@bitstream"}}
      uplink__agenix_identity__vic_blade{{"agenix-identity/vic@blade"}}
      uplink__agenix_identity__vic_cortex{{"agenix-identity/vic@cortex"}}
      uplink__agenix_identity__vic_uplink{{"agenix-identity/vic@uplink"}}
      uplink__agenix__uplink{{"agenix/uplink"}}
      uplink__services__ai__ollama[/"ai/ollama"\]
      uplink__services__ai__open_webui[/"ai/open-webui"\]
      uplink__den__batteries__define_user__dvicory_uplink{{"batteries/define-user/dvicory@uplink"}}
      uplink__den__batteries__define_user__pol_uplink{{"batteries/define-user/pol@uplink"}}
      uplink__den__batteries__define_user__sini_uplink{{"batteries/define-user/sini@uplink"}}
      uplink__den__batteries__define_user__theutz_uplink{{"batteries/define-user/theutz@uplink"}}
      uplink__den__batteries__define_user__vic_uplink{{"batteries/define-user/vic@uplink"}}
      uplink__den__batteries__hostname__os{{"batteries/hostname/os"}}
      uplink__den__batteries__inputs___os{{"batteries/inputs'/os"}}
      uplink__den__batteries__primary_user_sini_axon_01_{{"batteries/primary-user(sini@axon-01)"}}
      uplink__den__batteries__primary_user_sini_axon_02_{{"batteries/primary-user(sini@axon-02)"}}
      uplink__den__batteries__primary_user_sini_axon_03_{{"batteries/primary-user(sini@axon-03)"}}
      uplink__den__batteries__primary_user_sini_bitstream_{{"batteries/primary-user(sini@bitstream)"}}
      uplink__den__batteries__primary_user_sini_blade_{{"batteries/primary-user(sini@blade)"}}
      uplink__den__batteries__primary_user_sini_cortex_{{"batteries/primary-user(sini@cortex)"}}
      uplink__den__batteries__primary_user_sini_patch_{{"batteries/primary-user(sini@patch)"}}
      uplink__den__batteries__primary_user_sini_slab_{{"batteries/primary-user(sini@slab)"}}
      uplink__den__batteries__primary_user_sini_uplink_{{"batteries/primary-user(sini@uplink)"}}
      uplink__den__batteries__self___os{{"batteries/self'/os"}}
      uplink__services__bgp__hub[/"bgp/hub"\]
      uplink__core__boot__network_initrd[/"boot/network-initrd"\]
      uplink__core__impermanence_user_dvicory[/"core/impermanence"\]
      uplink__core__impermanence_user_pol[/"core/impermanence"\]
      uplink__core__impermanence_user_theutz[/"core/impermanence"\]
      uplink__core__impermanence_user_vic[/"core/impermanence"\]
      uplink__core__impermanence_host_uplink[/"core/impermanence"\]
      uplink__core__impermanence__btrfs_user_dvicory[/"core/impermanence/btrfs"\]
      uplink__core__impermanence__btrfs_user_pol[/"core/impermanence/btrfs"\]
      uplink__core__impermanence__btrfs_user_theutz[/"core/impermanence/btrfs"\]
      uplink__core__impermanence__btrfs_user_vic[/"core/impermanence/btrfs"\]
      uplink__core__impermanence__btrfs_host_uplink[/"core/impermanence/btrfs"\]
      uplink__core__impermanence__persist_collector_user_dvicory[/"core/impermanence/persist-collector"\]
      uplink__core__impermanence__persist_collector_user_pol[/"core/impermanence/persist-collector"\]
      uplink__core__impermanence__persist_collector_user_theutz[/"core/impermanence/persist-collector"\]
      uplink__core__impermanence__persist_collector_user_vic[/"core/impermanence/persist-collector"\]
      uplink__core__impermanence__persist_collector_host_uplink[/"core/impermanence/persist-collector"\]
      uplink__core__impermanence__zfs_user_dvicory[/"core/impermanence/zfs"\]
      uplink__core__impermanence__zfs_user_pol[/"core/impermanence/zfs"\]
      uplink__core__impermanence__zfs_user_theutz[/"core/impermanence/zfs"\]
      uplink__core__impermanence__zfs_user_vic[/"core/impermanence/zfs"\]
      uplink__core__impermanence__zfs_host_uplink[/"core/impermanence/zfs"\]
      uplink__core__localization__i18n_user_dvicory[/"core/localization/i18n"\]
      uplink__core__localization__i18n_user_pol[/"core/localization/i18n"\]
      uplink__core__localization__i18n_user_theutz[/"core/localization/i18n"\]
      uplink__core__localization__i18n_user_vic[/"core/localization/i18n"\]
      uplink__core__localization__i18n_host_uplink[/"core/localization/i18n"\]
      uplink__core__network__hostsfile_user_dvicory[/"core/network/hostsfile"\]
      uplink__core__network__hostsfile_user_pol[/"core/network/hostsfile"\]
      uplink__core__network__hostsfile_user_theutz[/"core/network/hostsfile"\]
      uplink__core__network__hostsfile_user_vic[/"core/network/hostsfile"\]
      uplink__core__network__hostsfile_host_uplink[/"core/network/hostsfile"\]
      uplink__core__network__networking_user_dvicory[/"core/network/networking"\]
      uplink__core__network__networking_user_pol[/"core/network/networking"\]
      uplink__core__network__networking_user_theutz[/"core/network/networking"\]
      uplink__core__network__networking_user_vic[/"core/network/networking"\]
      uplink__core__network__networking_host_uplink[/"core/network/networking"\]
      uplink__core__network__syncthing__peer_user_sini[/"core/network/syncthing/peer"\]
      uplink__core__network__syncthing__peer_user_dvicory[/"core/network/syncthing/peer"\]
      uplink__core__network__syncthing__peer_user_pol[/"core/network/syncthing/peer"\]
      uplink__core__network__syncthing__peer_user_theutz[/"core/network/syncthing/peer"\]
      uplink__core__network__syncthing__peer_user_vic[/"core/network/syncthing/peer"\]
      uplink__core__network__tailscale_user_dvicory[/"core/network/tailscale"\]
      uplink__core__network__tailscale_user_pol[/"core/network/tailscale"\]
      uplink__core__network__tailscale_user_theutz[/"core/network/tailscale"\]
      uplink__core__network__tailscale_user_vic[/"core/network/tailscale"\]
      uplink__core__network__tailscale_host_uplink[/"core/network/tailscale"\]
      uplink__core__nix_user_dvicory[/"core/nix"\]
      uplink__core__nix_user_pol[/"core/nix"\]
      uplink__core__nix_user_theutz[/"core/nix"\]
      uplink__core__nix_user_vic[/"core/nix"\]
      uplink__core__nix_host_uplink[/"core/nix"\]
      uplink__core__nix__stateVersion_user_dvicory[/"core/nix/stateVersion"\]
      uplink__core__nix__stateVersion_user_pol[/"core/nix/stateVersion"\]
      uplink__core__nix__stateVersion_user_theutz[/"core/nix/stateVersion"\]
      uplink__core__nix__stateVersion_user_vic[/"core/nix/stateVersion"\]
      uplink__core__nix__stateVersion_host_uplink[/"core/nix/stateVersion"\]
      uplink__core__perf__disable_docs_user_dvicory[/"core/perf/disable-docs"\]
      uplink__core__perf__disable_docs_user_pol[/"core/perf/disable-docs"\]
      uplink__core__perf__disable_docs_user_theutz[/"core/perf/disable-docs"\]
      uplink__core__perf__disable_docs_user_vic[/"core/perf/disable-docs"\]
      uplink__core__perf__disable_docs_host_uplink[/"core/perf/disable-docs"\]
      uplink__core__perf__ssd_user_dvicory[/"core/perf/ssd"\]
      uplink__core__perf__ssd_user_pol[/"core/perf/ssd"\]
      uplink__core__perf__ssd_user_theutz[/"core/perf/ssd"\]
      uplink__core__perf__ssd_user_vic[/"core/perf/ssd"\]
      uplink__core__perf__ssd_host_uplink[/"core/perf/ssd"\]
      uplink__core__perf__zram_swap_user_dvicory[/"core/perf/zram-swap"\]
      uplink__core__perf__zram_swap_user_pol[/"core/perf/zram-swap"\]
      uplink__core__perf__zram_swap_user_theutz[/"core/perf/zram-swap"\]
      uplink__core__perf__zram_swap_user_vic[/"core/perf/zram-swap"\]
      uplink__core__perf__zram_swap_host_uplink[/"core/perf/zram-swap"\]
      uplink__core__security_user_dvicory[/"core/security"\]
      uplink__core__security_user_pol[/"core/security"\]
      uplink__core__security_user_theutz[/"core/security"\]
      uplink__core__security_user_vic[/"core/security"\]
      uplink__core__security_host_uplink[/"core/security"\]
      uplink__core__security__openssh_user_dvicory[/"core/security/openssh"\]
      uplink__core__security__openssh_user_pol[/"core/security/openssh"\]
      uplink__core__security__openssh_user_theutz[/"core/security/openssh"\]
      uplink__core__security__openssh_user_vic[/"core/security/openssh"\]
      uplink__core__security__openssh_host_uplink[/"core/security/openssh"\]
      uplink__core__security__opkssh_user_dvicory[/"core/security/opkssh"\]
      uplink__core__security__opkssh_user_pol[/"core/security/opkssh"\]
      uplink__core__security__opkssh_user_theutz[/"core/security/opkssh"\]
      uplink__core__security__opkssh_user_vic[/"core/security/opkssh"\]
      uplink__core__security__opkssh_host_uplink[/"core/security/opkssh"\]
      uplink__core__security__sudo_user_dvicory[/"core/security/sudo"\]
      uplink__core__security__sudo_user_pol[/"core/security/sudo"\]
      uplink__core__security__sudo_user_theutz[/"core/security/sudo"\]
      uplink__core__security__sudo_user_vic[/"core/security/sudo"\]
      uplink__core__security__sudo_host_uplink[/"core/security/sudo"\]
      uplink__core__system__facter_user_dvicory[/"core/system/facter"\]
      uplink__core__system__facter_user_pol[/"core/system/facter"\]
      uplink__core__system__facter_user_theutz[/"core/system/facter"\]
      uplink__core__system__facter_user_vic[/"core/system/facter"\]
      uplink__core__system__facter_host_uplink[/"core/system/facter"\]
      uplink__core__system__firmware_user_dvicory[/"core/system/firmware"\]
      uplink__core__system__firmware_user_pol[/"core/system/firmware"\]
      uplink__core__system__firmware_user_theutz[/"core/system/firmware"\]
      uplink__core__system__firmware_user_vic[/"core/system/firmware"\]
      uplink__core__system__firmware_host_uplink[/"core/system/firmware"\]
      uplink__core__system__linux_kernel_user_dvicory[/"core/system/linux-kernel"\]
      uplink__core__system__linux_kernel_user_pol[/"core/system/linux-kernel"\]
      uplink__core__system__linux_kernel_user_theutz[/"core/system/linux-kernel"\]
      uplink__core__system__linux_kernel_user_vic[/"core/system/linux-kernel"\]
      uplink__core__system__linux_kernel_host_uplink[/"core/system/linux-kernel"\]
      uplink__core__systemd_user_dvicory[/"core/systemd"\]
      uplink__core__systemd_user_pol[/"core/systemd"\]
      uplink__core__systemd_user_theutz[/"core/systemd"\]
      uplink__core__systemd_user_vic[/"core/systemd"\]
      uplink__core__systemd_host_uplink[/"core/systemd"\]
      uplink__core__systemd__boot_user_dvicory[/"core/systemd/boot"\]
      uplink__core__systemd__boot_user_pol[/"core/systemd/boot"\]
      uplink__core__systemd__boot_user_theutz[/"core/systemd/boot"\]
      uplink__core__systemd__boot_user_vic[/"core/systemd/boot"\]
      uplink__core__systemd__boot_host_uplink[/"core/systemd/boot"\]
      uplink__core__users_user_dvicory[/"core/users"\]
      uplink__core__users_user_pol[/"core/users"\]
      uplink__core__users_user_theutz[/"core/users"\]
      uplink__core__users_user_vic[/"core/users"\]
      uplink__core__users_host_uplink[/"core/users"\]
      uplink__core__users__deterministic_uids_user_dvicory[/"core/users/deterministic-uids"\]
      uplink__core__users__deterministic_uids_user_pol[/"core/users/deterministic-uids"\]
      uplink__core__users__deterministic_uids_user_theutz[/"core/users/deterministic-uids"\]
      uplink__core__users__deterministic_uids_user_vic[/"core/users/deterministic-uids"\]
      uplink__core__users__deterministic_uids_host_uplink[/"core/users/deterministic-uids"\]
      uplink__core__users__home_manager_shared_user_dvicory[/"core/users/home-manager-shared"\]
      uplink__core__users__home_manager_shared_user_pol[/"core/users/home-manager-shared"\]
      uplink__core__users__home_manager_shared_user_theutz[/"core/users/home-manager-shared"\]
      uplink__core__users__home_manager_shared_user_vic[/"core/users/home-manager-shared"\]
      uplink__core__users__home_manager_shared_host_uplink[/"core/users/home-manager-shared"\]
      uplink__core__users__shell_user_dvicory[/"core/users/shell"\]
      uplink__core__users__shell_user_pol[/"core/users/shell"\]
      uplink__core__users__shell_user_theutz[/"core/users/shell"\]
      uplink__core__users__shell_user_vic[/"core/users/shell"\]
      uplink__core__users__shell_host_uplink[/"core/users/shell"\]
      uplink__core__utils_user_dvicory[/"core/utils"\]
      uplink__core__utils_user_pol[/"core/utils"\]
      uplink__core__utils_user_theutz[/"core/utils"\]
      uplink__core__utils_user_vic[/"core/utils"\]
      uplink__core__utils_host_uplink[/"core/utils"\]
      uplink__hardware__cpu__amd[/"cpu/amd"\]
      uplink__disk__zfs_diff[/"disk/zfs-diff"\]
      uplink__disk__zfs_disk_single[/"disk/zfs-disk-single"\]
      uplink__hardware__gpu__intel[/"gpu/intel"\]
      uplink__insecure_predicate__os{{"insecure-predicate/os"}}
      uplink__services__media__jellyfin[/"media/jellyfin"\]
      uplink__services__monitoring__grafana[/"monitoring/grafana"\]
      uplink__services__monitoring__loki[/"monitoring/loki"\]
      uplink__services__monitoring__prometheus[/"monitoring/prometheus"\]
      uplink__services__monitoring__prometheus_exporter[/"monitoring/prometheus-exporter"\]
      uplink__core__network__firewall_collector[/"network/firewall-collector"\]
      uplink__services__networking__haproxy[/"networking/haproxy"\]
      uplink__services__networking__headscale[/"networking/headscale"\]
      uplink__services__networking__nginx[/"networking/nginx"\]
      uplink__services__nix__attic[/"nix/attic"\]
      uplink__services__nix__remote_build_server[/"nix/remote-build-server"\]
      uplink__opkssh_authz__dvicory_axon_01{{"opkssh-authz/dvicory@axon-01"}}
      uplink__opkssh_authz__dvicory_axon_02{{"opkssh-authz/dvicory@axon-02"}}
      uplink__opkssh_authz__dvicory_axon_03{{"opkssh-authz/dvicory@axon-03"}}
      uplink__opkssh_authz__dvicory_bitstream{{"opkssh-authz/dvicory@bitstream"}}
      uplink__opkssh_authz__dvicory_uplink{{"opkssh-authz/dvicory@uplink"}}
      uplink__opkssh_authz__pol_axon_01{{"opkssh-authz/pol@axon-01"}}
      uplink__opkssh_authz__pol_axon_02{{"opkssh-authz/pol@axon-02"}}
      uplink__opkssh_authz__pol_axon_03{{"opkssh-authz/pol@axon-03"}}
      uplink__opkssh_authz__pol_bitstream{{"opkssh-authz/pol@bitstream"}}
      uplink__opkssh_authz__pol_uplink{{"opkssh-authz/pol@uplink"}}
      uplink__opkssh_authz__sini_axon_01{{"opkssh-authz/sini@axon-01"}}
      uplink__opkssh_authz__sini_axon_02{{"opkssh-authz/sini@axon-02"}}
      uplink__opkssh_authz__sini_axon_03{{"opkssh-authz/sini@axon-03"}}
      uplink__opkssh_authz__sini_bitstream{{"opkssh-authz/sini@bitstream"}}
      uplink__opkssh_authz__sini_blade{{"opkssh-authz/sini@blade"}}
      uplink__opkssh_authz__sini_cortex{{"opkssh-authz/sini@cortex"}}
      uplink__opkssh_authz__sini_patch{{"opkssh-authz/sini@patch"}}
      uplink__opkssh_authz__sini_slab{{"opkssh-authz/sini@slab"}}
      uplink__opkssh_authz__sini_uplink{{"opkssh-authz/sini@uplink"}}
      uplink__opkssh_authz__theutz_axon_01{{"opkssh-authz/theutz@axon-01"}}
      uplink__opkssh_authz__theutz_axon_02{{"opkssh-authz/theutz@axon-02"}}
      uplink__opkssh_authz__theutz_axon_03{{"opkssh-authz/theutz@axon-03"}}
      uplink__opkssh_authz__theutz_bitstream{{"opkssh-authz/theutz@bitstream"}}
      uplink__opkssh_authz__theutz_uplink{{"opkssh-authz/theutz@uplink"}}
      uplink__opkssh_authz__vic_axon_01{{"opkssh-authz/vic@axon-01"}}
      uplink__opkssh_authz__vic_axon_02{{"opkssh-authz/vic@axon-02"}}
      uplink__opkssh_authz__vic_axon_03{{"opkssh-authz/vic@axon-03"}}
      uplink__opkssh_authz__vic_bitstream{{"opkssh-authz/vic@bitstream"}}
      uplink__opkssh_authz__vic_blade{{"opkssh-authz/vic@blade"}}
      uplink__opkssh_authz__vic_cortex{{"opkssh-authz/vic@cortex"}}
      uplink__opkssh_authz__vic_uplink{{"opkssh-authz/vic@uplink"}}
      uplink__roles__server[/"roles/server"\]
      uplink__core__secrets__collector[/"secrets/collector"\]
      uplink__services__security__acme[/"security/acme"\]
      uplink__services__security__kanidm[/"security/kanidm"\]
      uplink__services__security__oauth2_proxy[/"security/oauth2-proxy"\]
      uplink__services__security__tang[/"security/tang"\]
      uplink__services__bgp[/"services/bgp"\]
      uplink__services__storage__media_data_share[/"storage/media-data-share"\]
      uplink__core__network__syncthing__hub[/"syncthing/hub"\]
      uplink__unfree_predicate__os{{"unfree-predicate/os"}}
      uplink__uplink{{"uplink"}}
      uplink__user_enrich__dvicory_axon_01{{"user-enrich/dvicory@axon-01"}}
      uplink__user_enrich__dvicory_axon_02{{"user-enrich/dvicory@axon-02"}}
      uplink__user_enrich__dvicory_axon_03{{"user-enrich/dvicory@axon-03"}}
      uplink__user_enrich__dvicory_bitstream{{"user-enrich/dvicory@bitstream"}}
      uplink__user_enrich__dvicory_uplink{{"user-enrich/dvicory@uplink"}}
      uplink__user_enrich__pol_axon_01{{"user-enrich/pol@axon-01"}}
      uplink__user_enrich__pol_axon_02{{"user-enrich/pol@axon-02"}}
      uplink__user_enrich__pol_axon_03{{"user-enrich/pol@axon-03"}}
      uplink__user_enrich__pol_bitstream{{"user-enrich/pol@bitstream"}}
      uplink__user_enrich__pol_uplink{{"user-enrich/pol@uplink"}}
      uplink__user_enrich__sini_axon_01{{"user-enrich/sini@axon-01"}}
      uplink__user_enrich__sini_axon_02{{"user-enrich/sini@axon-02"}}
      uplink__user_enrich__sini_axon_03{{"user-enrich/sini@axon-03"}}
      uplink__user_enrich__sini_bitstream{{"user-enrich/sini@bitstream"}}
      uplink__user_enrich__sini_blade{{"user-enrich/sini@blade"}}
      uplink__user_enrich__sini_cortex{{"user-enrich/sini@cortex"}}
      uplink__user_enrich__sini_patch{{"user-enrich/sini@patch"}}
      uplink__user_enrich__sini_slab{{"user-enrich/sini@slab"}}
      uplink__user_enrich__sini_uplink{{"user-enrich/sini@uplink"}}
      uplink__user_enrich__theutz_axon_01{{"user-enrich/theutz@axon-01"}}
      uplink__user_enrich__theutz_axon_02{{"user-enrich/theutz@axon-02"}}
      uplink__user_enrich__theutz_axon_03{{"user-enrich/theutz@axon-03"}}
      uplink__user_enrich__theutz_bitstream{{"user-enrich/theutz@bitstream"}}
      uplink__user_enrich__theutz_uplink{{"user-enrich/theutz@uplink"}}
      uplink__user_enrich__vic_axon_01{{"user-enrich/vic@axon-01"}}
      uplink__user_enrich__vic_axon_02{{"user-enrich/vic@axon-02"}}
      uplink__user_enrich__vic_axon_03{{"user-enrich/vic@axon-03"}}
      uplink__user_enrich__vic_bitstream{{"user-enrich/vic@bitstream"}}
      uplink__user_enrich__vic_blade{{"user-enrich/vic@blade"}}
      uplink__user_enrich__vic_cortex{{"user-enrich/vic@cortex"}}
      uplink__user_enrich__vic_uplink{{"user-enrich/vic@uplink"}}
      uplink__virtualization__podman[/"virtualization/podman"\]
      uplink__services__web__container_registry[/"web/container-registry"\]
      uplink__services__web__den_docs_mirror[/"web/den-docs-mirror"\]
      uplink__services__web__homepage[/"web/homepage"\]
      uplink__disk__zfs_disk_single__root[/"zfs-disk-single/root"\]
      uplink__core__impermanence_user_dvicory --> uplink__core__impermanence__btrfs_user_dvicory
      uplink__core__impermanence_user_pol --> uplink__core__impermanence__btrfs_user_pol
      uplink__core__impermanence_user_theutz --> uplink__core__impermanence__btrfs_user_theutz
      uplink__core__impermanence_user_vic --> uplink__core__impermanence__btrfs_user_vic
      uplink__core__impermanence_host_uplink --> uplink__core__impermanence__btrfs_host_uplink
      uplink__core__impermanence_user_dvicory --> uplink__core__impermanence__persist_collector_user_dvicory
      uplink__core__impermanence_user_pol --> uplink__core__impermanence__persist_collector_user_pol
      uplink__core__impermanence_user_theutz --> uplink__core__impermanence__persist_collector_user_theutz
      uplink__core__impermanence_user_vic --> uplink__core__impermanence__persist_collector_user_vic
      uplink__core__impermanence_host_uplink --> uplink__core__impermanence__persist_collector_host_uplink
      uplink__core__impermanence_user_dvicory --> uplink__core__impermanence__zfs_user_dvicory
      uplink__core__impermanence_user_pol --> uplink__core__impermanence__zfs_user_pol
      uplink__core__impermanence_user_theutz --> uplink__core__impermanence__zfs_user_theutz
      uplink__core__impermanence_user_vic --> uplink__core__impermanence__zfs_user_vic
      uplink__core__impermanence_host_uplink --> uplink__core__impermanence__zfs_host_uplink
      uplink__disk__zfs_disk_single --> uplink__disk__zfs_disk_single__root
      uplink__disk__zfs_disk_single__root --> uplink__disk__zfs_diff
      uplink__roles__server --> uplink__services__security__acme
      uplink__roles__server --> uplink__services__storage__media_data_share
      uplink__roles__server --> uplink__services__monitoring__prometheus_exporter
      uplink__roles__server --> uplink__services__security__tang
      uplink__services__bgp__hub --> uplink__services__bgp
      uplink__services__networking__headscale --> uplink__services__networking__nginx
      uplink__services__web__homepage --> uplink__services__security__oauth2_proxy
      uplink__uplink --> uplink__hardware__cpu__amd
      uplink__uplink --> uplink__services__nix__attic
      uplink__uplink --> uplink__services__web__container_registry
      uplink__uplink --> uplink__services__web__den_docs_mirror
      uplink__uplink --> uplink__services__networking__haproxy
      uplink__uplink --> uplink__services__networking__headscale
      uplink__uplink --> uplink__services__web__homepage
      uplink__uplink --> uplink__services__bgp__hub
      uplink__uplink --> uplink__core__network__syncthing__hub
      uplink__uplink --> uplink__hardware__gpu__intel
      uplink__uplink --> uplink__services__media__jellyfin
      uplink__uplink --> uplink__services__security__kanidm
      uplink__uplink --> uplink__core__boot__network_initrd
      uplink__uplink --> uplink__services__ai__ollama
      uplink__uplink --> uplink__services__ai__open_webui
      uplink__uplink --> uplink__virtualization__podman
      uplink__uplink --> uplink__roles__server
      uplink__uplink --> uplink__disk__zfs_disk_single
    end
  end

  host_cortex -->|ollama-endpoints| host_bitstream
  host_cortex -->|ollama-endpoints| host_blade
  host_cortex -->|ollama-endpoints| host_patch
  host_cortex -->|ollama-endpoints| host_slab
  host_axon_02 -->|bgp-peers| host_axon_01
  host_axon_03 -->|bgp-peers| host_axon_01
  host_uplink -->|bgp-peers| host_axon_01
  host_axon_01 -->|bgp-peers| host_axon_02
  host_axon_03 -->|bgp-peers| host_axon_02
  host_uplink -->|bgp-peers| host_axon_02
  host_axon_01 -->|bgp-peers| host_axon_03
  host_axon_02 -->|bgp-peers| host_axon_03
  host_uplink -->|bgp-peers| host_axon_03
  host_axon_01 -->|bgp-peers| host_uplink
  host_axon_02 -->|bgp-peers| host_uplink
  host_axon_03 -->|bgp-peers| host_uplink
  host_uplink -->|container-registries| host_axon_01
  host_uplink -->|container-registries| host_axon_02
  host_uplink -->|container-registries| host_axon_03
  host_axon_01 -->|k3s-nodes| host_uplink
  host_axon_02 -->|k3s-nodes| host_uplink
  host_axon_03 -->|k3s-nodes| host_uplink
  host_uplink -->|ollama-endpoints| host_axon_01
  host_uplink -->|ollama-endpoints| host_axon_02
  host_uplink -->|ollama-endpoints| host_axon_03
  host_uplink -->|prometheus-targets| host_axon_01
  host_uplink -->|prometheus-targets| host_axon_02
  host_uplink -->|prometheus-targets| host_axon_03
  host_axon_01 -->|thunderbolt-mesh-peers| host_uplink
  host_axon_02 -->|thunderbolt-mesh-peers| host_uplink
  host_axon_03 -->|thunderbolt-mesh-peers| host_uplink

  style host_bitstream fill:#313244,stroke:#a6adc8,stroke-width:1px
  style host_blade fill:#313244,stroke:#a6adc8,stroke-width:1px
  style host_cortex fill:#313244,stroke:#a6adc8,stroke-width:1px
  style host_patch fill:#313244,stroke:#a6adc8,stroke-width:1px
  style host_slab fill:#313244,stroke:#a6adc8,stroke-width:1px
  style host_axon_01 fill:#313244,stroke:#a6adc8,stroke-width:1px
  style host_axon_02 fill:#313244,stroke:#a6adc8,stroke-width:1px
  style host_axon_03 fill:#313244,stroke:#a6adc8,stroke-width:1px
  style host_uplink fill:#313244,stroke:#a6adc8,stroke-width:1px
  style env_dev fill:#313244,stroke:#6c7086,stroke-width:2px
  style env_prod fill:#313244,stroke:#6c7086,stroke-width:2px
```
