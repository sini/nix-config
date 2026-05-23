# Copies SSH authorized_keys from all wheel-group users to root.
{ lib, ... }:
{
  den.aspects.core.root-user = {
    nixos =
      { config, ... }:
      let
        inherit (config) users;
        wheelUsers = lib.filterAttrs (_name: u: builtins.elem "wheel" (u.extraGroups or [ ])) users.users;
        sshKeys = lib.concatMap (u: u.openssh.authorizedKeys.keys or [ ]) (lib.attrValues wheelUsers);
      in
      {
        users.users.root.openssh.authorizedKeys.keys = sshKeys;
      };
  };
}
