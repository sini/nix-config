- setup impermenance

- Add laptop power management via systemd, agnostic to gnome, hyprland, etc...

- allow laptop to close

- Add yubikey unlock/lock

- setup niri + locking

- https://scvalex.net/posts/55/ https://gitlab.com/scvalex/generating-secrets-flake

- Setup kanidm ssh login

- move kanidm to axon cluster, add redundancy

- setup a keepalive vip for axon services (vault, kanidm) maybe look at https://github.com/geraldwuhoo/homelab-iac

- longhorn zfs volume: https://scvalex.net/posts/49/

- maybe do ceph instead...

- setup distributed vault unlocking to remove local secrets, reference: https://gitlab.com/usmcamp0811/dotfiles/-/tree/nixos/modules/nixos/services/vault?ref_type=heads

- setup tailscale

- setup terranix w/ unifi + cloudflare providers

- setup kubenix + argocd

- Restore nvidia persistenced ; NixOS/nixpkgs#437066

- Migrate from btrfs to ZFS

- setup snapshot backup

- reference: https://yomaq.github.io/posts/zfs-encryption-backups-and-convenience/

- rust: https://scvalex.net/posts/63/

- kubernetes:
  - https://github.com/Zebradil/cloudflare-dynamic-dns

- terraform:
  - vault resources
  - cloudflare dns

- colmena
  - darwin deployment...

- libvirt / quemu / kvm / windows virtualization...

- setup unifi cloud gateway, add terraform integration

- audio resources: https://github.com/polygon/audio.nix/tree/master

- sinden: https://www.sindenwiki.org/wiki/2_player https://sindenlightgun.com/drivers/
