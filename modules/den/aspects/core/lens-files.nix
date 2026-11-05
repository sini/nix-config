# lens-files: project declared settings INTO a file the program also writes, instead of
# replacing it with a read-only store symlink. Each activation applies the managed keys
# through an Augeas lens (a bidirectional parser), so every key, table and comment the
# program or the user owns survives untouched, and a managed key is reset to its declared
# value whatever was written over it in between.
#
# Removal is three-way, as `kubectl apply` does it: the paths applied last time are kept
# beside the target, and a path that leaves the declaration is removed from the file.
#
# Contributors merge through the HM module system, so several modules may set keys in one
# file. Augeas refuses a save the lens cannot render and the load is checked before any
# edit, so a file the lens cannot parse is reported and left as it was.
{
  den.aspects.core.lens-files = {
    homeManager =
      {
        config,
        lib,
        pkgs,
        ...
      }:
      let
        augtool = lib.getExe' pkgs.augeas "augtool";
        toml = pkgs.formats.toml { };

        quoteKey = k: if builtins.match "[A-Za-z0-9_-]+" k != null then k else builtins.toJSON k;
        # JSON string escapes are TOML basic-string escapes; the lens stores the escaped form.
        tomlEsc =
          s:
          let
            j = builtins.toJSON s;
          in
          builtins.substring 1 (builtins.stringLength j - 2) j;
        augStr = s: "\"" + builtins.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] s + "\"";
        # Path-predicate literals take no escapes: a label carrying `"` is single-quoted.
        pred = s: if lib.hasInfix "\"" s then "'${s}'" else "\"${s}\"";

        scalar =
          v:
          if builtins.isBool v then
            {
              t = "bool";
              s = if v then "true" else "false";
            }
          else if builtins.isInt v then
            {
              t = "integer";
              s = toString v;
            }
          else if builtins.isFloat v then
            {
              t = "float";
              s = toString v;
            }
          else if builtins.isString v || builtins.isPath v then
            {
              t = "string";
              s = tomlEsc (toString v);
            }
          else
            throw "lens-files: unsupported TOML value ${builtins.typeOf v}";

        valueOps =
          node: v:
          if builtins.isList v then
            let
              items = map scalar v;
              t = (builtins.head items).t;
            in
            if v == [ ] then
              [ "set ${node}/array" ]
            else if lib.any (i: i.t != t) items then
              throw "lens-files: mixed-type arrays are unsupported"
            else
              lib.imap1 (n: i: "set ${node}/array/${t}[${toString n}] ${augStr i.s}") items
          else
            let
              i = scalar v;
            in
            [ "set ${node}/${i.t} ${augStr i.s}" ];

        mkFile =
          name: file:
          let
            abs = "${config.home.homeDirectory}/${file.target}";
            state = "${dirOf abs}/.${baseNameOf abs}.hm-lens";

            leaves =
              let
                walk =
                  segs: attrs:
                  lib.concatLists (
                    lib.mapAttrsToList (
                      k: v:
                      if builtins.isAttrs v && !lib.isDerivation v then
                        walk (segs ++ [ k ]) v
                      else
                        [
                          {
                            inherit segs;
                            key = k;
                            value = v;
                          }
                        ]
                    ) attrs
                  );
              in
              walk [ ] file.settings;

            tableOf = segs: "$f/table[. = ${pred (lib.concatMapStringsSep "." quoteKey segs)}]";
            parentOf = l: if l.segs == [ ] then "$f" else tableOf l.segs;
            entryOf = l: "${parentOf l}/entry[. = ${pred (quoteKey l.key)}]";

            rootLeaves = lib.filter (l: l.segs == [ ]) leaves;
            tableLeaves = lib.filter (l: l.segs != [ ]) leaves;
            tables = lib.unique (map (l: l.segs) tableLeaves);

            # Tables first: a new root key is inserted before table[1], which must exist.
            ops =
              map (segs: "set ${tableOf segs} ${augStr (lib.concatMapStringsSep "." quoteKey segs)}") tables
              ++ lib.concatMap (
                l:
                [
                  "set ${entryOf l} ${augStr (quoteKey l.key)}"
                  "rm ${entryOf l}/*"
                ]
                ++ valueOps (entryOf l) l.value
              ) tableLeaves
              ++ lib.concatMap (
                l:
                [
                  "rm ${entryOf l}"
                  "ins entry before $f/table[1]"
                  "set $f/entry[last()] ${augStr (quoteKey l.key)}"
                ]
                ++ valueOps (entryOf l) l.value
              ) rootLeaves;

            paths = pkgs.writeText "${name}-lens-paths" (
              lib.concatMapStrings (l: "entry ${entryOf l}\n") leaves
              + lib.concatMapStrings (segs: "table ${tableOf segs}\n") tables
            );
            script = pkgs.writeText "${name}-lens.augtool" (lib.concatLines ops);

            apply = pkgs.writeShellScript "lens-apply-${name}" ''
              set -euo pipefail
              target=${lib.escapeShellArg abs}
              state=${lib.escapeShellArg state}
              mkdir -p "$(dirname "$target")"
              # A store symlink left by a previous owner of this path becomes a plain file.
              if [ -L "$target" ]; then
                cp --remove-destination "$(readlink -f "$target")" "$target"
                chmod u+w "$target"
              fi
              [ -e "$target" ] || : > "$target"

              header() {
                printf 'set /augeas/load/Toml/lens Toml.lns\nset /augeas/load/Toml/incl %s\nload\ndefvar f /files%s\n' \
                  "$target" "$target"
              }
              errs=$({ header; echo 'print /augeas//error'; } | ${augtool} --noautoload 2>&1)
              if [ -n "$errs" ]; then
                echo "lens-files: $target does not parse; left unchanged:" >&2
                printf '%s\n' "$errs" >&2
                exit 0
              fi

              stale() {
                [ -e "$state" ] || return 0
                grep -vxF -f ${paths} "$state" | while read -r kind path; do
                  case "$kind" in
                    entry) printf 'rm %s\n' "$path" ;;
                    table) printf 'rm %s[count(entry) = 0]\n' "$path" ;;
                  esac
                done
              }
              # The state lists entries before tables, so a table is emptied before its rm.
              out=$({ header; stale; cat ${script}; echo save; echo 'print /augeas//error'; } \
                | ${augtool} --noautoload 2>&1 | grep -v -e '^rm : ' -e '^Saved ' || true)
              if [ -n "$out" ]; then
                echo "lens-files: applying to $target failed; left unchanged:" >&2
                printf '%s\n' "$out" >&2
                exit 0
              fi
              install -m 0644 ${paths} "$state"
            '';
          in
          {
            assertion = rootLeaves == [ ] || tables != [ ];
            inherit apply;
          };

        files = lib.mapAttrs mkFile config.lens.files;
      in
      {
        options.lens.files = lib.mkOption {
          default = { };
          description = "Mutable files whose declared keys are projected in on every activation.";
          type = lib.types.attrsOf (
            lib.types.submodule {
              options = {
                target = lib.mkOption {
                  type = lib.types.str;
                  description = "Path relative to the home directory.";
                };
                settings = lib.mkOption {
                  inherit (toml) type;
                  default = { };
                  description = "Keys owned by Home Manager; everything else in the file is left alone.";
                };
              };
            }
          );
        };

        config = lib.mkIf (config.lens.files != { }) {
          assertions = lib.mapAttrsToList (name: f: {
            inherit (f) assertion;
            message = "lens-files.${name}: a root key needs at least one managed table to be inserted before.";
          }) files;

          home.activation.lensFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] (
            lib.concatMapStrings (f: "run ${f.apply}\n") (lib.attrValues files)
          );
        };
      };
  };
}
