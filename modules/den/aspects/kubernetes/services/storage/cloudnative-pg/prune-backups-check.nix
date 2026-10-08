# The backup pruner's retention plan (prune-backups.py) on fixed data:
#   nix build .#checks.x86_64-linux.cnpg-prune-backups
{
  perSystem =
    { pkgs, ... }:
    {
      checks.cnpg-prune-backups = pkgs.runCommand "cnpg-prune-backups" { } ''
        ${pkgs.python3}/bin/python3 -I ${./prune-backups.py} --self-test
        touch $out
      '';
    };
}
