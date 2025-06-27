This uses a hack to dual boot on the same drive. Install Windows first, resize partitons, capture cylinder info with parted....

Install linux with nixos-anywhere via:
https://github.com/nix-community/nixos-anywhere/blob/main/docs/howtos/disko-modes.mdnix

`# run github:nix-community/nixos-anywhere -- --disko-mode mount --flake <path to configuration>#<configuration name> --target-host root@<ip address>`

Formatting:
see scripts/format.sh for modified disko script...

```
Model: Samsung SSD 990 PRO 2TB (nvme)
Disk /dev/nvme1n1: 7660841cyl
Sector size (logical/physical): 512B/512B
BIOS cylinder,head,sector geometry: 7660841,255,2.  Each cylinder is 261kB.
Partition Table: gpt
Disk Flags:

Number  Start       End         Size        File system  Name                  Flags
 1      4cyl        4019cyl     4015cyl     fat32        boot                  boot, esp, no_automount
 2      4019cyl     4083cyl     64cyl                                          msftres, no_automount
 3      4083cyl     4044133cyl  4040049cyl  ntfs         Basic data partition  msftdata, no_automount
 4      4044133cyl  4046719cyl  2586cyl     ntfs                               hidden, diag, no_automount
 5      4046719cyl  7660841cyl  3614121cyl               luks
```
