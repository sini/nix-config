{ lib, ... }:
{
  den.aspects.core.network.syncthing.member.nixos =
    {
      user,
      host,
      replicateHome ? [ ],
      lib,
      ...
    }:
    let
      dirs = lib.unique (lib.concatMap (e: e.directories or [ ]) replicateHome);
    in
    {
      system.activationScripts."syncthingS2Probe-${user.name}".text =
        "true # ${user.name}@${host.name} dirs=${toString (builtins.length dirs)}";
    };
}
