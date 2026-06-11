# K3s node host setup — kernel modules, sysctls, firewall and tooling that are
# independent of cluster membership. Split out of the main k3s aspect (which
# includes it) so the membership-dependent config (keepalived, k3s flags,
# bootstrap) stays separate from the static node plumbing.
{ den, lib, ... }:
let
  inherit (lib) flatten mkForce;
in
{
  den.aspects.services.k3s.node = {
    nixos =
      { pkgs, ... }:
      {
        environment.systemPackages = [
          pkgs.k3s
          pkgs.k9s
          pkgs.kubectl
          pkgs.istioctl
          pkgs.kubernetes-helm
          pkgs.cilium-cli

          pkgs.clusterctl
          pkgs.nerdctl

          pkgs.skopeo
          pkgs.go-containerregistry
          pkgs.dive

          pkgs.openiscsi
          pkgs.nfs-utils

          pkgs.util-linux
          pkgs.parted
          pkgs.gptfdisk
          pkgs.lvm2

          # Host iptables/nftables on PATH. networking.nftables is enabled but
          # with the firewall disabled NixOS installs no iptables wrapper, so
          # k3s falls back to its bundled binaries for kubelet's iptables
          # canaries — leaving tables on a backend Cilium's nft iptables-wrapper
          # then rejects ("table `mangle' is incompatible, use 'nft' tool"),
          # crashing the agent. Providing the host iptables-nft + nft keeps the
          # whole stack (k3s, kubelet, Cilium) on one compatible nft backend.
          pkgs.iptables
          pkgs.nftables
        ];

        boot = {
          kernelModules = [
            # Filesystem
            "ceph"
            "rbd"
            "nfs"
            "overlay"
            # Networking / eBPF
            "bpf"
            "ip_tables"
            "br_netfilter"
            "nft-expr-counter"
            "iptable_nat"
            "iptable_filter"
            "nft_counter"
            "ip6_tables"
            "ip6table_mangle"
            "ip6table_raw"
            "ip6table_filter"
            "ip_conntrack"
            "ip_vs"
            "ip_vs_rr"
            "ip_vs_wrr"
            "ip_vs_sh"
            "iscsi_tcp"
          ];

          kernel.sysctl = {
            "net.bridge.bridge-nf-call-iptables" = 1;
            "net.bridge.bridge-nf-call-ip6tables" = 1;
            "net.core.bpf_jit_enable" = 1;
            "net.core.bpf_jit_harden" = 0;
          };

          blacklistedKernelModules = [ "nbd" ];
        };

        networking.firewall = {
          enable = mkForce false;

          allowedTCPPorts = flatten [
            179 # BGP
            6443 # Kubernetes API
            6444
            6081
            10250 # Kubelet metrics
            2379 # etcd
            2380 # etcd
            4240 # Cilium healthcheck
            4244 # Hubble API
            8080
            443
            9500 # Longhorn Manager
          ];

          allowedUDPPorts = [
            8472 # Cilium VXLAN
            4789 # Cilium VXLAN fallback
            51820 # WireGuard
          ];

          trustedInterfaces = [
            "lo"
            "cni+"
            "cilium+"
            "lxc+"
            "enp199s0f5"
            "enp199s0f6"
          ];

          extraCommands = ''
            iptables -A nixos-fw -p vrrp -j ACCEPT
          '';
        };

        # Stop tailscale managing netfilter on k3s nodes. Its nftables mode
        # writes raw-nft chains into the shared mangle/nat/filter tables
        # (connmark mark save/restore, ts-* chains), which Cilium's iptables-nft
        # then refuses ("table `mangle' is incompatible, use 'nft' tool"),
        # crashing the agent's IPv6 iptables probe. Cilium owns node/pod
        # firewalling and the host firewall is disabled, so tailscale needs no
        # netfilter rules here; the tailscale0 interface still routes.
        # extraSetFlags (tailscale set) is used rather than extraUpFlags because
        # the autoconnect only runs `tailscale up` on first auth — on
        # already-connected nodes only `tailscale set` re-applies the mode and
        # tears down the rules tailscale previously installed.
        #
        # --accept-dns=false: MagicDNS pushes `search ts.json64.dev` into
        # systemd-resolved; kubelet copies node search domains into every pod
        # sandbox, where ndots:5 search-expands ~every external hostname
        # through the CF-proxied `*.ts.json64.dev` wildcard — hijacking pod
        # TLS cluster-wide (SNI-mismatch handshake_failure at the CF edge,
        # OIDC/ACME timeouts). k3s nodes must never inherit MagicDNS resolver
        # config; tailscale0 still routes by IP. Takes effect in pods after a
        # k3s restart (kubelet re-reads resolv.conf) + pod recreation.
        services.tailscale.extraSetFlags = [
          "--netfilter-mode=off"
          "--accept-dns=false"
        ];
      };
  };
}
