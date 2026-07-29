# herdr-pair — grant guests attach-only access to a host account's live herdr
# session (e.g. that account's claude-code session).
#
# Why this shape: herdr binds its control socket 0600 (owner-only —
# SOCKET_PERMISSION_MODE is a hardcoded 0o600 that herdr chmod's onto the socket
# after every bind), so a *second* unix user cannot attach another account's
# session through a shared-group socket. Group perms are irrelevant against a
# 0600 file. The only way to join a running session is to authenticate AS that
# account. This installs each guest's SSH key on the target account, pinned to a
# single forced command that attaches the named herdr session and nothing else:
# no shell, no scp, no port/agent/X11 forwarding.
#
# Trust (Model A): while attached the guest co-drives *as the target account* —
# herdr panes are that account's shells, and herdr has no read-only client. That
# is inherent to sharing one live multiplexer, not a gap in this aspect.
#
# The target account must be running the session first:
#   herdr session attach <session>   (then launch claude-code inside it)
# A guest attaching a not-yet-running session just gets a fresh empty one owned
# by the target account.
{ lib, ... }:
{
  den.aspects.applications.dev.mux.herdr-pair = {
    settings = {
      session = lib.mkOption {
        type = lib.types.str;
        default = "pair";
        description = "herdr session name guests attach. Each owner runs their shared claude-code session under this name (resolved per-account, so every owner has their own).";
      };
      pairs = lib.mkOption {
        type = lib.types.attrsOf (lib.types.listOf lib.types.str);
        default = { };
        example = {
          sini = [ "vic" ];
        };
        description = ''
          Map of host account owner -> guest registry usernames. Each guest's
          identity.sshKeys are installed on the owner's account behind a forced
          herdr-attach command, granting attach-only access to the owner's
          `session`. Owners not resolved onto this host are ignored.
        '';
      };
    };

    nixos =
      {
        host,
        inputs',
        resolved-users,
        ...
      }:
      let
        cfg = host.settings.applications.dev.mux.herdr-pair;
        herdr = "${inputs'.nix-ai-tools.packages.herdr}/bin/herdr";

        resolvedNames = map (u: u.name) resolved-users;

        # Guest key strings, sourced from the guest's own registry entry
        # (single source of truth — no duplicated pubkeys).
        keysFor = guest: lib.concatMap (u: u.sshKeys) (builtins.filter (u: u.name == guest) resolved-users);

        # restrict = drop pty + all forwarding + exec; pty re-enables the tty
        # herdr's TUI needs; command pins the one allowed action.
        forcedKey = key: ''restrict,pty,command="${herdr} session attach ${cfg.session}" ${key}'';

        # Only wire owners that actually exist on this host.
        activePairs = lib.filterAttrs (owner: _: builtins.elem owner resolvedNames) cfg.pairs;
      in
      lib.mkIf (activePairs != { }) {
        users.users = lib.mapAttrs (_owner: guests: {
          openssh.authorizedKeys.keys = map forcedKey (lib.concatMap keysFor guests);
        }) activePairs;
      };
  };
}
