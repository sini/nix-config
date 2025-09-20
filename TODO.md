- Add laptop power management via systemd, agnostic to gnome, hyprland, etc...

- Add yubikey unlock/lock

- Setup kanidm ssh login

- move kanidm to axon cluster, add redundancy

- setup a keepalive vip for axon services (vault, kanidm) maybe look at https://github.com/geraldwuhoo/homelab-iac

- longhorn zfs volume: https://scvalex.net/posts/49/

- setup distributed vault unlocking to remove local secrets, reference: https://gitlab.com/usmcamp0811/dotfiles/-/tree/nixos/modules/nixos/services/vault?ref_type=heads

- setup tailscale

- setup terranix w/ unifi + cloudflare providers

- setup kubenix + argocd

- Restore nvidia persistenced ; NixOS/nixpkgs#437066

- Migrate from btrfs to ZFS

- setup impermenance

- setup snapshot backup

- reference: https://yomaq.github.io/posts/zfs-encryption-backups-and-convenience/
