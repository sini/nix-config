# persist-migrate: move a path's existing data into persistent storage the first time it is
# persisted, so adding a persist entry on a live host never hides data. impermanence alone
# bind-mounts the (new, empty) persistent copy over a non-empty directory, and refuses a
# non-empty file.
#
# Runs as an activation script before impermanence creates its storage directories, so before
# any of its mounts or file links start, on switch and at boot alike. A path is moved only when
# its persistent copy does not exist yet and the live path holds real data (not a mount, not a
# link, not empty), so it is idempotent: after a home or root wipe there is nothing to move.
# The copy reflinks (instant on a pool with block cloning) into a staging name, is renamed into
# place, and only then is the live path removed; a failed copy leaves the live data untouched.
#
# On a live switch, a database a running service holds open (sqlite, an index) is copied
# mid-write and the service keeps writing to the removed original until it restarts. Persist
# such paths with `colmena apply boot` and a reboot: stage-2 activation migrates them with
# /home and the stores mounted (neededForBoot) and before any user service starts. The same goes
# for a path holding a listening unix socket (herdr keeps its sockets in ~/.config/herdr): the
# server keeps the old inode and is unreachable until it restarts, so the script warns, naming them.
{
  den.aspects.core.impermanence.migrate = {
    nixos =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        entries = import ./_entries.nix { inherit lib config; };

        migrate = pkgs.writeShellApplication {
          name = "persist-migrate";
          runtimeInputs = [
            pkgs.coreutils
            pkgs.gawk
            pkgs.util-linux
          ];
          text = ''
            # usage: persist-migrate LIVE STORAGE_ROOT
            live=$1
            src=''${2%/}$live

            # Storage not mounted: a "move" would land on the wiped root, and delete the original.
            mountpoint -q -- "$2" || exit 0
            [[ -e $src || -L $src ]] && exit 0
            [[ -L $live || ! -e $live ]] && exit 0
            mountpoint -q -- "$live" && exit 0
            if [[ -d $live ]]; then
              [[ -z $(ls -A -- "$live") ]] && exit 0
              # Something beneath it is already mounted (a persisted child): moving the parent
              # would copy through that mount and then delete what it holds. Left for a person.
              if findmnt -rn -o TARGET | grep -qF -- "$live/"; then
                echo "persist-migrate: $live has mounts beneath it, not moved" >&2
                exit 1
              fi
            else
              [[ -s $live ]] || exit 0
            fi

            # Mirror each missing parent's owner and mode, as impermanence does for its own.
            parent=$(dirname -- "$live")
            missing=()
            while [[ ! -e ''${2%/}$parent ]]; do
              missing=("$parent" "''${missing[@]}")
              parent=$(dirname -- "$parent")
            done
            for p in "''${missing[@]}"; do
              mkdir -- "''${2%/}$p"
              chown --reference="$p" -- "''${2%/}$p"
              chmod --reference="$p" -- "''${2%/}$p"
            done

            stage="$src.persist-migrate"
            rm -rf -- "$stage"
            cp -a -x --reflink=auto -- "$live" "$stage" || {
              rm -rf --one-file-system -- "$stage"
              exit 1
            }
            mv -T -- "$stage" "$src"
            # A listening socket's inode stays on the old dataset: its server is unreachable at
            # this path until it restarts (and clients may start a second, empty one).
            listeners=$(awk -v p="$live/" 'index($NF, p) == 1 { print $NF }' /proc/net/unix | sort -u)
            rm -rf --one-file-system -- "$live"
            echo "persist-migrate: moved $live into $2"
            if [[ -n $listeners ]]; then
              echo "persist-migrate: WARNING: $live held listening sockets; restart their servers (or migrate with a boot deploy):" >&2
              printf '  %s\n' "$listeners" >&2
            fi
          '';
        };
      in
      {
        system.activationScripts.persist-migrate = {
          deps = [
            "users"
            "groups"
          ];
          text = lib.concatMapStrings (
            e:
            "${lib.getExe migrate} ${
              lib.escapeShellArgs [
                e.live
                e.store
              ]
            } || echo 'persist-migrate: failed for ${e.live}' >&2\n"
          ) entries;
        };
        system.activationScripts.createPersistentStorageDirs.deps = [ "persist-migrate" ];
      };
  };
}
