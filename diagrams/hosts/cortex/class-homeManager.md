# Class Slice: homeManager: cortex

![homeManager slice](./class-homeManager.mmd.svg)

```mermaid
%%{init: {"elk":{"mergeEdges":true,"nodePlacementStrategy":"BRANDES_KOEPF"},"flowchart":{"wrappingWidth":600},"layout":"elk","theme":"base","themeVariables":{"activationBkgColor":"#d0d7de","activationBorderColor":"#8c959f","actorBkg":"#d0d7de","actorBorder":"#6e7781","actorLineColor":"#6e7781","actorTextColor":"#424a53","background":"#eaeef2","classText":"#424a53","clusterBkg":"#d0d7de","clusterBorder":"#8c959f","edgeLabelBackground":"#eaeef2","labelBoxBkgColor":"#d0d7de","labelBoxBorderColor":"#6e7781","labelTextColor":"#424a53","lineColor":"#6e7781","loopTextColor":"#424a53","mainBkg":"#d0d7de","nodeBkg":"#d0d7de","nodeBorder":"#6e7781","nodeTextColor":"#424a53","noteBkgColor":"#d0d7de","noteBorderColor":"#8c959f","noteTextColor":"#424a53","pie1":"#fa4549","pie2":"#e16f24","pie3":"#bf8700","pie4":"#2da44e","pie5":"#339D9B","pie6":"#218bff","pie7":"#a475f9","pie8":"#4d2d00","pieLegendTextColor":"#424a53","pieOuterStrokeColor":"#8c959f","pieSectionTextColor":"#424a53","pieStrokeColor":"#8c959f","pieTitleTextColor":"#424a53","primaryBorderColor":"#6e7781","primaryColor":"#d0d7de","primaryTextColor":"#424a53","secondBkg":"#d0d7de","secondaryBorderColor":"#8c959f","secondaryColor":"#d0d7de","secondaryTextColor":"#424a53","sequenceNumberColor":"#eaeef2","signalColor":"#6e7781","signalTextColor":"#424a53","tertiaryBorderColor":"#8c959f","tertiaryColor":"#d0d7de","tertiaryTextColor":"#424a53","textColor":"#424a53","titleColor":"#424a53"}}}%%
graph LR
  cortex([cortex]):::root

  subgraph ctx_host_cortex["host: cortex"]
  apps__alacritty[/"apps/alacritty"\]:::apps__alacritty_c
  hardware__audio[/"hardware/audio"\]:::hardware__audio_c
  apps__bat[/"apps/bat"\]:::apps__bat_c
  hardware__bluetooth[/"hardware/bluetooth"\]:::hardware__bluetooth_c
  apps__claude[/"apps/claude"\]:::apps__claude_c
  core__default[/"core/default"\]:::core__default_c
  roles__dev[/"roles/dev"\]:::roles__dev_c
  roles__dev_gui[/"roles/dev-gui"\]:::roles__dev_gui_c
  apps__direnv[/"apps/direnv"\]:::apps__direnv_c
  apps__discord[/"apps/discord"\]:::apps__discord_c
  apps__easyeffects[/"apps/easyeffects"\]:::apps__easyeffects_c
  apps__emulation[/"apps/emulation"\]:::apps__emulation_c
  apps__eza[/"apps/eza"\]:::apps__eza_c
  apps__firefox[/"apps/firefox"\]:::apps__firefox_c
  desktop__fonts[/"desktop/fonts"\]:::desktop__fonts_c
  roles__gaming[/"roles/gaming"\]:::roles__gaming_c
  apps__git[/"apps/git"\]:::apps__git_c
  apps__gitkraken[/"apps/gitkraken"\]:::apps__gitkraken_c
  desktop__gnome[/"desktop/gnome"\]:::desktop__gnome_c
  apps__gpg[/"apps/gpg"\]:::apps__gpg_c
  desktop__hyprland[/"desktop/hyprland"\]:::desktop__hyprland_c
  disk__impermanence[/"disk/impermanence"\]:::disk__impermanence_c
  apps__jellyfin_client[/"apps/jellyfin-client"\]:::apps__jellyfin_client_c
  apps__k9s[/"apps/k9s"\]:::apps__k9s_c
  apps__kdeconnect[/"apps/kdeconnect"\]:::apps__kdeconnect_c
  apps__kitty[/"apps/kitty"\]:::apps__kitty_c
  apps__kube_tools[/"apps/kube-tools"\]:::apps__kube_tools_c
  virtualization__libvirt[/"virtualization/libvirt"\]:::virtualization__libvirt_c
  apps__mangohud[/"apps/mangohud"\]:::apps__mangohud_c
  roles__media[/"roles/media"\]:::roles__media_c
  roles__messaging[/"roles/messaging"\]:::roles__messaging_c
  apps__misc_tools[/"apps/misc-tools"\]:::apps__misc_tools_c
  apps__mpv[/"apps/mpv"\]:::apps__mpv_c
  apps__nix_index[/"apps/nix-index"\]:::apps__nix_index_c
  apps__nvf[/"apps/nvf"\]:::apps__nvf_c
  apps__obs_studio[/"apps/obs-studio"\]:::apps__obs_studio_c
  apps__obsidian[/"apps/obsidian"\]:::apps__obsidian_c
  core__persist_home_collector[/"core/persist-home-collector"\]:::core__persist_home_collector_c
  apps__python[/"apps/python"\]:::apps__python_c
  apps__qbittorrent[/"apps/qbittorrent"\]:::apps__qbittorrent_c
  apps__spicetify[/"apps/spicetify"\]:::apps__spicetify_c
  apps__ssh[/"apps/ssh"\]:::apps__ssh_c
  apps__starship[/"apps/starship"\]:::apps__starship_c
  apps__steam[/"apps/steam"\]:::apps__steam_c
  desktop__stylix[/"desktop/stylix"\]:::desktop__stylix_c
  apps__sunshine[/"apps/sunshine"\]:::apps__sunshine_c
  apps__sysmon[/"apps/sysmon"\]:::apps__sysmon_c
  apps__telegram[/"apps/telegram"\]:::apps__telegram_c
  hardware__vr_amd[/"hardware/vr-amd"\]:::hardware__vr_amd_c
  apps__vscode[/"apps/vscode"\]:::apps__vscode_c
  apps__wireshark[/"apps/wireshark"\]:::apps__wireshark_c
  roles__workstation[/"roles/workstation"\]:::roles__workstation_c
  apps__yazi[/"apps/yazi"\]:::apps__yazi_c
  apps__youtube_music[/"apps/youtube-music"\]:::apps__youtube_music_c
  apps__yt_dlp[/"apps/yt-dlp"\]:::apps__yt_dlp_c
  apps__zathura[/"apps/zathura"\]:::apps__zathura_c
  apps__zellij[/"apps/zellij"\]:::apps__zellij_c
  apps__zoom[/"apps/zoom"\]:::apps__zoom_c
  apps__zoxide[/"apps/zoxide"\]:::apps__zoxide_c
  apps__zsh[/"apps/zsh"\]:::apps__zsh_c
  core__default --> apps__zsh
  cortex --> core__default
  cortex --> roles__dev
  cortex --> roles__dev_gui
  cortex --> apps__easyeffects
  cortex --> roles__gaming
  cortex --> desktop__hyprland
  cortex --> disk__impermanence
  cortex --> roles__media
  cortex --> roles__messaging
  cortex --> hardware__vr_amd
  cortex --> roles__workstation
  disk__impermanence --> core__persist_home_collector
  roles__dev --> apps__bat
  roles__dev --> apps__claude
  roles__dev --> apps__direnv
  roles__dev --> apps__eza
  roles__dev --> apps__git
  roles__dev --> apps__gpg
  roles__dev --> apps__k9s
  roles__dev --> apps__misc_tools
  roles__dev --> apps__nix_index
  roles__dev --> apps__nvf
  roles__dev --> apps__python
  roles__dev --> apps__ssh
  roles__dev --> apps__starship
  roles__dev --> apps__sysmon
  roles__dev --> apps__yazi
  roles__dev --> apps__zoxide
  roles__dev_gui --> apps__gitkraken
  roles__dev_gui --> apps__kube_tools
  roles__dev_gui --> apps__vscode
  roles__dev_gui --> apps__wireshark
  roles__dev_gui --> apps__zellij
  roles__gaming --> apps__emulation
  roles__gaming --> apps__mangohud
  roles__gaming --> apps__steam
  roles__gaming --> apps__sunshine
  roles__media --> apps__jellyfin_client
  roles__media --> apps__mpv
  roles__media --> apps__qbittorrent
  roles__media --> apps__spicetify
  roles__media --> apps__youtube_music
  roles__media --> apps__yt_dlp
  roles__messaging --> apps__discord
  roles__messaging --> apps__kdeconnect
  roles__messaging --> apps__telegram
  roles__messaging --> apps__zoom
  roles__workstation --> apps__alacritty
  roles__workstation --> hardware__audio
  roles__workstation --> hardware__bluetooth
  roles__workstation --> apps__firefox
  roles__workstation --> desktop__fonts
  roles__workstation --> desktop__gnome
  roles__workstation --> apps__kitty
  roles__workstation --> virtualization__libvirt
  roles__workstation --> apps__obs_studio
  roles__workstation --> apps__obsidian
  roles__workstation --> desktop__stylix
  roles__workstation --> apps__zathura
  end


  classDef root fill:#218bff,stroke:#218bff,color:#1f2328,font-weight:bold
  classDef apps__alacritty_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef apps_c fill:#2da44e,stroke:#2da44e,color:#1f2328,stroke-dasharray: 3 3,stroke-width:1px
  classDef hardware__audio_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef apps__bat_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef hardware__bluetooth_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef apps__claude_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef core_c fill:#bf8700,stroke:#bf8700,color:#1f2328,stroke-dasharray: 3 3,stroke-width:1px
  classDef cortex_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef core__default_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef desktop_c fill:#2da44e,stroke:#2da44e,color:#1f2328,stroke-dasharray: 3 3,stroke-width:1px
  classDef roles__dev_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef roles__dev_gui_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef apps__direnv_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef apps__discord_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef disk_c fill:#2da44e,stroke:#2da44e,color:#1f2328,stroke-dasharray: 3 3,stroke-width:1px
  classDef apps__easyeffects_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef apps__emulation_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef apps__eza_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef apps__firefox_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef desktop__fonts_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef roles__gaming_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef apps__git_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef apps__gitkraken_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef desktop__gnome_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef apps__gpg_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef hardware_c fill:#2da44e,stroke:#2da44e,color:#1f2328,stroke-dasharray: 3 3,stroke-width:1px
  classDef desktop__hyprland_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef disk__impermanence_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef apps__jellyfin_client_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef apps__k9s_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef apps__kdeconnect_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef apps__kitty_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef apps__kube_tools_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef virtualization__libvirt_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef apps__mangohud_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef roles__media_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef roles__messaging_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef apps__misc_tools_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef apps__mpv_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef apps__nix_index_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef apps__nvf_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef apps__obs_studio_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef apps__obsidian_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef core__persist_home_collector_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef apps__python_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef apps__qbittorrent_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef roles_c fill:#2da44e,stroke:#2da44e,color:#1f2328,stroke-dasharray: 3 3,stroke-width:1px
  classDef apps__spicetify_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef apps__ssh_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef apps__starship_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef apps__steam_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef desktop__stylix_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef apps__sunshine_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef apps__sysmon_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef apps__telegram_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef virtualization_c fill:#e16f24,stroke:#e16f24,color:#1f2328,stroke-dasharray: 3 3,stroke-width:1px
  classDef hardware__vr_amd_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef apps__vscode_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef apps__wireshark_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef roles__workstation_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef apps__yazi_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef apps__youtube_music_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
  classDef apps__yt_dlp_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef apps__zathura_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef apps__zellij_c fill:#218bff,stroke:#218bff,color:#1f2328,stroke-width:3px
  classDef apps__zoom_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef apps__zoxide_c fill:#a475f9,stroke:#a475f9,color:#1f2328,stroke-width:3px
  classDef apps__zsh_c fill:#4d2d00,stroke:#4d2d00,color:#1f2328,stroke-width:3px
style ctx_host_cortex fill:#d0d7de,stroke:#8c959f,stroke-width:2px
```
