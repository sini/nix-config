# Policy Sequence: patch

![Policy sequence](./policy-seq.mmd.svg)

```mermaid
%%{init: {"theme":"base","themeVariables":{"activationBkgColor":"#313244","activationBorderColor":"#6c7086","actorBkg":"#313244","actorBorder":"#a6adc8","actorLineColor":"#a6adc8","actorTextColor":"#cdd6f4","background":"#1e1e2e","classText":"#cdd6f4","clusterBkg":"#313244","clusterBorder":"#6c7086","edgeLabelBackground":"#1e1e2e","labelBoxBkgColor":"#313244","labelBoxBorderColor":"#a6adc8","labelTextColor":"#cdd6f4","lineColor":"#a6adc8","loopTextColor":"#cdd6f4","mainBkg":"#313244","nodeBkg":"#313244","nodeBorder":"#a6adc8","nodeTextColor":"#cdd6f4","noteBkgColor":"#313244","noteBorderColor":"#6c7086","noteTextColor":"#cdd6f4","pie1":"#f38ba8","pie2":"#fab387","pie3":"#f9e2af","pie4":"#a6e3a1","pie5":"#94e2d5","pie6":"#89b4fa","pie7":"#cba6f7","pie8":"#f2cdcd","pieLegendTextColor":"#cdd6f4","pieOuterStrokeColor":"#6c7086","pieSectionTextColor":"#cdd6f4","pieStrokeColor":"#6c7086","pieTitleTextColor":"#cdd6f4","primaryBorderColor":"#a6adc8","primaryColor":"#313244","primaryTextColor":"#cdd6f4","secondBkg":"#313244","secondaryBorderColor":"#6c7086","secondaryColor":"#313244","secondaryTextColor":"#cdd6f4","sequenceNumberColor":"#1e1e2e","signalColor":"#a6adc8","signalTextColor":"#cdd6f4","tertiaryBorderColor":"#6c7086","tertiaryColor":"#313244","tertiaryTextColor":"#cdd6f4","textColor":"#cdd6f4","titleColor":"#cdd6f4"}}}%%
sequenceDiagram
    participant root as patch
    participant collect_bgp_peers as collect-bgp-peers
    participant collect_host_addrs as collect-host-addrs
    participant collect_k3s_nodes as collect-k3s-nodes
    participant collect_ollama_endpoints as collect-ollama-endpoints
    participant collect_prometheus_targets as collect-prometheus-targets
    participant collect_thunderbolt_mesh_peers as collect-thunderbolt-mesh-peers
    participant collect_vault_peers as collect-vault-peers
    participant host_to_hm_users as host-to-hm-users
    participant os_to_host as os-to-host
    participant hm_user_detect as hm-user-detect
    participant homeAarch64_to_hm as homeAarch64-to-hm
    participant homeDarwin_to_hm as homeDarwin-to-hm
    participant os_to_host as os-to-host
    participant user_to_host as user-to-host

    root ->> collect_bgp_peers: dispatch
    activate collect_bgp_peers
    deactivate collect_bgp_peers

    root ->> collect_host_addrs: dispatch

    root ->> collect_k3s_nodes: dispatch

    root ->> collect_ollama_endpoints: dispatch

    root ->> collect_prometheus_targets: dispatch

    root ->> collect_thunderbolt_mesh_peers: dispatch

    root ->> collect_vault_peers: dispatch

    root ->> host_to_hm_users: dispatch

    root ->> os_to_host: dispatch

    root ->> hm_user_detect: dispatch

    root ->> homeAarch64_to_hm: dispatch

    root ->> homeDarwin_to_hm: dispatch

    root ->> os_to_host: dispatch

    root ->> user_to_host: dispatch
```
