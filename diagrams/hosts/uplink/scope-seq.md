# Scope Sequence: uplink

![Scope sequence](./scope-seq.mmd.svg)

```mermaid
%%{init: {"theme":"base","themeVariables":{"activationBkgColor":"#313244","activationBorderColor":"#6c7086","actorBkg":"#313244","actorBorder":"#a6adc8","actorLineColor":"#a6adc8","actorTextColor":"#cdd6f4","background":"#1e1e2e","classText":"#cdd6f4","clusterBkg":"#313244","clusterBorder":"#6c7086","edgeLabelBackground":"#1e1e2e","labelBoxBkgColor":"#313244","labelBoxBorderColor":"#a6adc8","labelTextColor":"#cdd6f4","lineColor":"#a6adc8","loopTextColor":"#cdd6f4","mainBkg":"#313244","nodeBkg":"#313244","nodeBorder":"#a6adc8","nodeTextColor":"#cdd6f4","noteBkgColor":"#313244","noteBorderColor":"#6c7086","noteTextColor":"#cdd6f4","pie1":"#f38ba8","pie2":"#fab387","pie3":"#f9e2af","pie4":"#a6e3a1","pie5":"#94e2d5","pie6":"#89b4fa","pie7":"#cba6f7","pie8":"#f2cdcd","pieLegendTextColor":"#cdd6f4","pieOuterStrokeColor":"#6c7086","pieSectionTextColor":"#cdd6f4","pieStrokeColor":"#6c7086","pieTitleTextColor":"#cdd6f4","primaryBorderColor":"#a6adc8","primaryColor":"#313244","primaryTextColor":"#cdd6f4","secondBkg":"#313244","secondaryBorderColor":"#6c7086","secondaryColor":"#313244","secondaryTextColor":"#cdd6f4","sequenceNumberColor":"#1e1e2e","signalColor":"#a6adc8","signalTextColor":"#cdd6f4","tertiaryBorderColor":"#6c7086","tertiaryColor":"#313244","tertiaryTextColor":"#cdd6f4","textColor":"#cdd6f4","titleColor":"#cdd6f4"}}}%%
sequenceDiagram
    participant host as host { host }


    activate host
    host ->> host: batteries/hostname/os(host)
    host ->> host: insecure-predicate/os(host)
    host ->> host: unfree-predicate/os(host)
    host ->> host: uplink(host)
    deactivate host
    Note over host: services/acme, secrets/agenix, services/attic, services/bgp<br/>hardware/cpu-amd, core/default, default, batteries/define-user<br/>services/den-docs-mirror, core/deterministic-uids, core/facter, core/firewall-collector<br/>core/firmware, hardware/gpu-intel, services/grafana, services/haproxy<br/>services/headscale, core/home-manager, services/homepage, host<br/>batteries/host/resolve(define-user):den/batteries, host/resolve(host), host/resolve(insecure-predicate), host/resolve(unfree-predicate)<br/>batteries/hostname, network/hosts, bgp/hub, core/i18n<br/>disk/impermanence, insecure-predicate, services/jellyfin, services/kanidm<br/>core/linux-kernel, core/lix, services/loki, services/media-data-share<br/>roles/metrics-ingester, network/network-boot, network/networking, services/nginx<br/>core/nix, roles/nix-builder, core/nix-remote-build-client, services/nix-remote-build-server<br/>core/nixpkgs, services/oauth2-proxy, services/ollama, services/open-webui<br/>network/openssh, core/persist-collector, core/persist-home-collector, virtualization/podman<br/>batteries/primary-user, services/prometheus, services/prometheus-exporter, zfs-disk-single/root<br/>core/secrets-collector, core/security, roles/server, core/shell<br/>core/ssd, core/stateVersion, core/sudo, core/systemd<br/>core/systemd-boot, services/tailscale, services/tang, core/time<br/>unfree-predicate, roles/unlock, core/users, core/utils<br/>disk/zfs-diff, disk/zfs-disk-single, apps/zsh
```
