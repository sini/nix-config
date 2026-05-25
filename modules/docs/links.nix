{ dag, ... }:
{
  flake.readme.links = dag.entryAfter [ "disallow-warnings" ] (
    # markdown
    ''
      ## Notable Links

      ### Other dendritic users:

      - [GaetanLepage/nix-config](https://github.com/GaetanLepage/nix-config/)
      - [vic/vix](https://github.com/vic/vix)
      - [drupol/infra](https://github.com/drupol/infra/tree/master)

      ### Other inspirational nix configs:

      - [oddlama/nix-config](https://github.com/oddlama/nix-config/)
      - [JManch/nixos](https://github.com/JManch/nixos)
      - [akirak/homelab](https://github.com/akirak/nix-config/)
      - [pim/nix-config](https://git.kun.is/pim/nixos-configs) & [pim's kubernetes configs](https://git.kun.is/home/kubernetes-deployments)

      ### Notable References:

      - [colmena](https://github.com/zhaofengli/colmena)
      - [agenix](https://github.com/ryantm/agenix) & [agenix-rekey](https://github.com/oddlama/agenix-rekey)
      - [flake-parts](https://flake.parts/)
    ''
  );
}
