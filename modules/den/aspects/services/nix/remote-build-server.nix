{ self, ... }:
{
  den.aspects.services.nix.remote-build-server = {
    nixos =
      {
        config,
        pkgs,
        lib,
        resolved-users,
        ...
      }:
      {
        # nix-serve-ng links pkgs.lix (2.95), which rejects the -Dmimalloc flag
        # nixos-unstable passes it; drop once NixOS/nixpkgs#573942 reaches the channel.
        nixpkgs.overlays = [
          (_: prev: {
            lix = prev.lix.overrideAttrs (old: {
              mesonFlags = lib.filter (f: !lib.hasPrefix "-Dmimalloc=" f) old.mesonFlags;
            });
          })
        ];

        services.nix-serve = {
          enable = true;
          package = pkgs.nix-serve-ng;
          secretKeyFile = config.age.secrets.nix_store_signing_key.path;
          port = 16893;
          openFirewall = true;
        };

        # nix-serve keeps one nix-daemon connection open for days, and its daemon
        # worker holds the store's shared lock. A Nix that upgrades the store
        # schema needs that lock exclusively, so the switch's bootloader step
        # (`nix-env --list-generations` from the new Nix) waited forever: cortex,
        # uplink and bitstream hung for hours on 2.34.9 -> 2.35.6 (2026-11-18/19).
        # When the new system's Nix differs from the running daemon's, stop
        # nix-serve before the switch; the restart trigger starts it again after
        # nix-daemon restarts, connected to the new daemon.
        system.preSwitchChecks.nix-serve-release-store-lock = ''
          case "$2" in switch | boot | test) ;; *) exit 0 ;; esac
          pid=$(${pkgs.systemd}/bin/systemctl show -p MainPID --value nix-daemon.service)
          [ -n "$pid" ] && [ "$pid" != 0 ] || exit 0
          running=$(${pkgs.coreutils}/bin/readlink -f "/proc/$pid/exe")
          next=$(${pkgs.coreutils}/bin/readlink -f "$1/sw/bin/nix")
          if [ "''${running%/bin/*}" != "''${next%/bin/*}" ] \
            && ${pkgs.systemd}/bin/systemctl -q is-active nix-serve.service; then
            echo "nix-serve: stopping across the Nix change (''${running%/bin/*} -> ''${next%/bin/*})" >&2
            ${pkgs.systemd}/bin/systemctl stop nix-serve.service
          fi
        '';
        systemd.services.nix-serve.restartTriggers = [ config.nix.package ];

        nix.settings = {
          trusted-users = [ "nix-remote-build" ];
          allowed-users = [ "nix-remote-build" ];
        };

        users = {
          groups.nix-remote-build.name = "nix-remote-build";

          users.nix-remote-build = {
            group = "nix-remote-build";
            isSystemUser = true;
            useDefaultShell = true;
            description = "nix-remote-build";
            openssh.authorizedKeys.keys =
              let
                buildKey = builtins.readFile (self + "/.secrets/users/nix-remote-build/id_ed25519.pub");
                userSshKeys = lib.concatMap (u: u.sshKeys or [ ]) resolved-users;
              in
              lib.map (key: ''command="nix-store --serve --write",restrict '' + key) (
                [ buildKey ] ++ userSshKeys
              );
          };
        };
      };

    firewall = {
      networking.firewall.allowedTCPPorts = [ 16893 ];
    };

    age-secrets = {
      # nix-serve now runs under systemd DynamicUser and consumes the key via
      # LoadCredential (read as root), so there is no static nix-serve user to
      # own the secret — keep it root-owned and root-readable.
      age.secrets.nix_store_signing_key = {
        generator.script = "binary-cache-key";
        owner = "root";
        mode = "0400";
      };
    };
  };
}
