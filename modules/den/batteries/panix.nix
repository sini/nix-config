# Panix battery: a panix.yml fleet generated from den host entities.
#
# Site-neutral: it reads only den-generic host fields (name, system, intoAttr,
# aspects); everything site-specific is a den.panix.* option. Settings are
# typed by ./_panix-options.nix and merged with module semantics from:
#   1. derived defaults (mkDefault, each at its own panix level):
#        flags        local_machine_hostname (sentinel), runtime.max_concurrency
#        fleet        ssh hardening, bootstrap.disable_nix_install, auto_rollback
#        flake        url
#        installable  nix.build_mode  (remote when host.system != deployer)
#        machine      ssh.hostname, ssh.username, tags (hostTags ++ aspect tags)
#      One installable per host at its flake output (host.intoAttr, e.g.
#      nixosConfigurations.<name>); hosts without one (intoAttr = [ ]) are skipped.
#   2. den.panix.settings: a settings module (flags, output_types, fleet/flake).
#   3. opt-in (enableClass): each fleet host's `panix` class fragments, i.e.
#      settings modules from its aspects. Module args: `host` (den) and
#      `panixPath host` -> { flake, outputType, installable, machine }.
# Nothing else is set, so panix's fleet -> flake -> installable -> machine
# inheritance stays in charge. With `hardened` (default) the merged settings
# are checked against the panix review 2026-10-16 (commit 414806c) rules.
#
# Enable with den.panix.enable; this also adds the devshell `panix` command.
# Usage and options: docs/panix.md.
#
#   nix build .#panix-config      # the rendered panix.yml (deployer = .#<system>)
#   nix run .#panix -- deploy -t <host|tag>
{
  den,
  lib,
  config,
  withSystem,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.den.panix;

  # Filled in by the wrapper with git+file://<repo root> when flakeUrl is null.
  urlSentinel = "@PANIX_FLAKE_URL@";
  # Never a machine's ssh.hostname, so no machine is treated as local: panix
  # decides "local" by comparing hostname strings.
  localSentinel = "panix-no-local-machine.invalid";

  hosts = lib.filterAttrs (_: h: cfg.hosts h && lib.length (h.intoAttr or [ ]) == 2) (
    lib.foldl' (acc: system: acc // (config.den.hosts.${system} or { })) { } (
      builtins.attrNames (config.den.hosts or { })
    )
  );

  panixPath = host: {
    flake = cfg.flakeName;
    outputType = builtins.elemAt host.intoAttr 0;
    installable = builtins.elemAt host.intoAttr 1;
    machine = host.name;
  };

  # Same derivation as colmena.nix's aspectTags (duplicated, it is one line).
  aspectTags =
    host:
    lib.sort (a: b: a < b) (lib.unique (map (a: a.identity) (lib.filter (a: a.isNamed) host.aspects)));

  # mkDefault on every leaf, not the tree: a fragment that sets one field must
  # not discard the defaults beside it.
  mkDefaults = v: if builtins.isAttrs v then lib.mapAttrs (_: mkDefaults) v else lib.mkDefault v;

  globalDefaults = {
    flags = {
      local_machine_hostname = localSentinel;
      runtime.max_concurrency = cfg.maxConcurrency;
    };
    fleet = {
      ssh = {
        # Without this panix adds StrictHostKeyChecking=accept-new ahead of
        # extra_flags, and ssh takes the first value given.
        disable_auto_add_host_key = true;
        extra_flags = [
          "-o"
          "StrictHostKeyChecking=yes"
          "-o"
          "BatchMode=yes"
          "-o"
          "ConnectTimeout=10"
          "-o"
          "ServerAliveInterval=15"
        ];
      }
      // lib.optionalAttrs (cfg.knownHostsFile != null) { known_hosts_file = cfg.knownHostsFile; };
      bootstrap.disable_nix_install = true;
      auto_rollback = false;
    };
    fleet.flakes.${cfg.flakeName}.url = if cfg.flakeUrl == null then urlSentinel else cfg.flakeUrl;
  };

  hostDefaults =
    deployerSystem: host:
    let
      p = panixPath host;
    in
    {
      fleet.flakes.${p.flake}.installables.${p.outputType}.${p.installable} = {
        # panix takes build_mode at installable level at the closest.
        nix.build_mode = if host.system == deployerSystem then "local" else "remote";
        machines.${p.machine} = {
          ssh = {
            hostname = cfg.hostAddress host;
            username = cfg.hostUser host;
          };
          tags = cfg.hostTags host ++ aspectTags host;
        };
      };
    };

  evalFor =
    system: pkgs:
    lib.evalModules {
      specialArgs = {
        inherit pkgs;
        # specialArgs, not _module.args: fragments build attr names from it.
        settingsArgs = { inherit panixPath; };
      };
      modules = [
        ./_panix-options.nix
        {
          # A function, so `imports`/`_module` are module keys, not settings
          # (submodule attrset definitions are config-only shorthand).
          panix.settings = _: {
            imports = [
              cfg.settings
              {
                # den wraps class modules that take `host` with a validator that
                # sets `warnings`; declare it so it is not freeform YAML (which
                # recurses), print the warnings, and render nothing.
                options.warnings = mkOption {
                  type = types.listOf types.str;
                  default = [ ];
                  internal = true;
                  apply = lib.foldr lib.warn null;
                };
              }
              (mkDefaults globalDefaults)
            ]
            ++ lib.mapAttrsToList (_: host: mkDefaults (hostDefaults system host)) hosts
            ++ lib.optionals cfg.enableClass (
              lib.concatMap (name: config.flake.panixModules.${name} or [ ]) (builtins.attrNames hosts)
            );
          };
        }
      ];
    };

  # Hardened checks over the merged settings (panix review 2026-10-16, commit
  # 414806c). Each returns a list of messages.
  violations =
    s:
    let
      on = v: v == true;
      walk =
        f: path: v:
        if builtins.isAttrs v then
          lib.concatLists (lib.mapAttrsToList (k: x: f (path ++ [ k ]) k x ++ walk f (path ++ [ k ]) x) v)
        else if builtins.isList v then
          lib.concatLists (lib.imap0 (i: x: walk f (path ++ [ (toString i) ]) x) v)
        else
          [ ];
      at = path: lib.concatStringsSep "." path;
      # Every key and string value, so templating syntax is caught in both.
      strings =
        path: v:
        if builtins.isAttrs v then
          lib.concatLists (
            lib.mapAttrsToList (k: x: [ (lib.nameValuePair (at path) k) ] ++ strings (path ++ [ k ]) x) v
          )
        else if builtins.isList v then
          lib.concatLists (lib.imap0 (i: strings (path ++ [ (toString i) ])) v)
        else if builtins.isString v then
          [ (lib.nameValuePair (at path) v) ]
        else
          [ ];
      badName = n: builtins.match "[a-z0-9-]+" n == null;
      looseSsh = [
        "StrictHostKeyChecking=no"
        "StrictHostKeyChecking=accept-new"
        "UserKnownHostsFile=/dev/null"
      ];
      fleet = s.fleet or { };
      flakes = fleet.flakes or { };
      # Levels above machine: fleet, each flake, each installable.
      upper = [
        {
          path = [ "fleet" ];
          v = fleet;
        }
      ]
      ++ lib.concatLists (
        lib.mapAttrsToList (
          fn: f:
          [
            {
              path = [
                "fleet"
                "flakes"
                fn
              ];
              v = f;
            }
          ]
          ++ lib.concatLists (
            lib.mapAttrsToList (
              ot: insts:
              lib.mapAttrsToList (n: i: {
                path = [
                  "fleet"
                  "flakes"
                  fn
                  "installables"
                  ot
                  n
                ];
                v = i;
                flakeV = f;
              }) insts
            ) (f.installables or { })
          )
        ) flakes
      );
      installables = lib.filter (l: l ? flakeV) upper;
    in
    walk (
      path: k: v:
      lib.optional (
        k == "disable_strict_key_checking" && on v
      ) "${at path}: strict host key checking must stay on"
      ++ lib.optional (
        k == "extra_flags" && builtins.isList v && lib.any (f: builtins.elem f looseSsh) v
      ) "${at path}: must not loosen host key checking (${lib.concatStringsSep ", " looseSsh})"
      ++ lib.optional (
        k == "ssh" && lib.elem "bootstrap" path
      ) "${at path}: bootstrap ssh does not belong in the everyday config"
      ++ lib.optional (
        k == "hardware_config_path"
      ) "${at path}: hardware_config_path writes target output into the flake"
    ) [ ] s
    ++ lib.optional (lib.elem "inspect" (
      s.flags.skip_phases or [ ]
    )) "flags.skip_phases: skipping inspect makes live hosts look unprovisioned"
    ++ lib.concatMap (
      l:
      lib.concatMap
        (
          k:
          lib.optional (on (
            l.v.bootstrap.${k} or null
          )) "${at l.path}.bootstrap.${k}: destructive flags only at machine level"
        )
        [
          "force_bootstrap"
          "force_bootstrap_kexec"
          "allow_destructive_actions"
        ]
    ) upper
    ++ lib.concatMap (
      l:
      let
        mode = l.v.nix.build_mode or l.flakeV.nix.build_mode or fleet.nix.build_mode or "local";
      in
      lib.optional (mode == "remote" && lib.length (builtins.attrNames (l.v.machines or { })) > 1)
        "${at l.path}: build_mode remote needs exactly one machine (it builds on the first and copies peer to peer)"
    ) installables
    ++ map (x: "${x.name}: literal '{{' would be read as a panix template: ${x.value}") (
      lib.filter (x: lib.hasInfix "{{" x.value) (strings [ ] s)
    )
    ++ lib.concatMap (
      l:
      let
        name = lib.last l.path;
      in
      lib.optional (badName name) "${at l.path}: name '${name}' is outside [a-z0-9-]"
      ++ lib.optionals (l ? flakeV) (
        map (m: "${at l.path}.machines.${m}: name is outside [a-z0-9-]") (
          lib.filter badName (builtins.attrNames (l.v.machines or { }))
        )
      )
    ) (lib.tail upper);

  configFileFor =
    system: pkgs:
    let
      ev = evalFor system pkgs;
      clean =
        v:
        if builtins.isAttrs v then
          lib.mapAttrs (_: clean) (lib.filterAttrs (_: x: x != null) v)
        else if builtins.isList v then
          map clean v
        else
          v;
      # JSON round-trip to plain data, nulls (unset) dropped, as rendered.
      errs = violations (clean (builtins.fromJSON (builtins.toJSON ev.config.panix.settings)));
    in
    lib.throwIf (cfg.hardened && errs != [ ]) ''
      den.panix (hardened): the panix settings break these rules (see docs/panix.md, or set den.panix.hardened = false):
        - ${lib.concatStringsSep "\n  - " errs}'' ev.config.panix.configFile;
in
{
  options.den.panix = {
    enable = lib.mkEnableOption "the panix battery (panix.yml, `panix` package and devshell command)";
    flakeName = mkOption {
      type = types.strMatching "[a-z0-9-]+";
      default = "self";
      description = "Key under fleet.flakes (also a panix tag).";
    };
    flakeUrl = mkOption {
      type = types.nullOr types.str;
      default = null;
      example = "github:owner/repo";
      description = "fleet.flakes.<flakeName>.url. null: the wrapper fills in git+file://<repo root> ($PRJ_ROOT, else git's toplevel).";
    };
    hosts = mkOption {
      type = types.functionTo types.bool;
      # den's own host classes; both are built-in panix output types.
      default =
        host:
        builtins.elem (host.class or "nixos") [
          "nixos"
          "darwin"
        ];
      defaultText = lib.literalExpression ''host: builtins.elem host.class [ "nixos" "darwin" ]'';
      description = "Host entity -> whether it is in the panix fleet, e.g. `host: host.hasAspect den.aspects.panix`.";
    };
    hostAddress = mkOption {
      type = types.functionTo types.str;
      default = host: host.name;
      defaultText = lib.literalExpression "host: host.name";
      description = "Host entity -> machine ssh.hostname.";
    };
    hostUser = mkOption {
      type = types.functionTo types.str;
      example = lib.literalExpression ''host: "deploy"'';
      description = "Host entity -> machine ssh.username. Required: panix would otherwise default to root.";
    };
    hostTags = mkOption {
      type = types.functionTo (types.listOf types.str);
      default = _: [ ];
      description = "Host entity -> machine tags, prepended to the aspect tags.";
    };
    knownHostsFile = mkOption {
      type = types.nullOr (types.strMatching "/.*");
      default = null;
      example = "/etc/ssh/ssh_known_hosts";
      description = "Absolute fleet ssh.known_hosts_file; it should hold the `@cert-authority` line for your host CA. null: ssh's own known_hosts.";
    };
    maxConcurrency = mkOption {
      type = types.ints.positive;
      default = 4;
      description = "flags.runtime.max_concurrency (panix's default 0 is unlimited).";
    };
    hardened = mkOption {
      type = types.bool;
      default = true;
      description = "Fail eval when the merged settings break the review rules listed in docs/panix.md.";
    };
    settings = mkOption {
      type = types.deferredModule;
      default = { };
      description = "Settings module merged into panix.settings (flags, output_types, fleet- or flake-level settings).";
    };
    enableClass = mkOption {
      type = types.bool;
      default = false;
      description = "Collect `panix` class fragments (panix.settings modules) from each fleet host's aspects.";
    };
    writeFile = mkOption {
      type = types.bool;
      default = false;
      description = "Also write panix.yml into the repo through github:sini/files (files.file). Needs flakeUrl.";
    };
  };

  config = {
    flake-file.inputs.panix = lib.mkIf cfg.enable {
      url = "github:mihakrumpestar/panix";
      inputs = {
        nixpkgs.follows = "nixpkgs-unstable";
        flake-utils.follows = "flake-utils";
      };
    };

    # Per system: the deployer is the system the package is built for.
    flake.packages = lib.mkIf cfg.enable (
      lib.genAttrs config.systems (
        system:
        withSystem system (
          { pkgs, inputs', ... }:
          rec {
            panix-config = configFileFor system pkgs;
            # Runs panix from <repo root>/.panix (0700), so its logs, snapshots
            # and outlinks land there, on a copy of panix-config with the flake
            # url filled in. PANIX_CONFIG (panix's env form of -c) overrides.
            panix = pkgs.writeShellApplication {
              name = "panix";
              runtimeInputs = [ pkgs.git ];
              text = ''
                root=''${PRJ_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || true)}
                if [ -z "$root" ]; then
                  echo "panix: run from the devshell or inside the flake's git checkout" >&2
                  exit 1
                fi
                state="$root/.panix"
                umask 077
                mkdir -p "$state"
                chmod 0700 "$state"
                if [ -n "''${PANIX_CONFIG:-}" ]; then
                  PANIX_CONFIG=$(realpath "$PANIX_CONFIG")
                else
                  sed 's|${urlSentinel}|git+file://'"$root"'|g' ${panix-config} > "$state/panix.yml"
                  PANIX_CONFIG="$state/panix.yml"
                fi
                export PANIX_CONFIG
                cd "$state"
                exec ${lib.getExe inputs'.panix.packages.default} "$@"
              '';
            };
          }
        )
      )
    );

    # den reads the definitions below as raw values (no mkIf), so they gate on
    # the flags with optionals; the aspect and policy are inert until included.
    den.classes = lib.optionalAttrs (cfg.enable && cfg.enableClass) {
      panix.description = "panix.settings fragments, collected per host";
    };
    den.policies.panix-fragments =
      { host, ... }:
      [
        (den.lib.policy.instantiate {
          name = "${host.name}-panix";
          class = "panix";
          instantiate = { modules, ... }: modules;
          intoAttr = [
            "panixModules"
            host.name
          ];
        })
      ];
    den.schema.host.includes = lib.optionals (cfg.enable && cfg.enableClass) [
      den.policies.panix-fragments
    ];

    den.aspects.devshell.panix = {
      devshell =
        { self', ... }:
        {
          commands = [
            {
              package = self'.packages.panix;
              help = "Deploy this nix config to nodes (panix, config rendered from den.hosts)";
            }
          ];
        };
    };
    den.schema.flake-parts.includes = lib.optionals cfg.enable [ den.aspects.devshell.panix ];

    perSystem =
      { self', pkgs, ... }:
      {
        # One fixture breaking each hardened rule once; the eval fails if any
        # rule stops firing or a clean config starts failing.
        checks = lib.optionalAttrs cfg.enable {
          panix-hardened =
            let
              m = {
                ssh.hostname = "h";
                ssh.username = "u";
              };
              bad = {
                flags.skip_phases = [ "inspect" ];
                fleet = {
                  ssh.disable_strict_key_checking = true;
                  bootstrap.force_bootstrap = true;
                  bootstrap.ssh.hostname = "installer";
                  flakes.f.installables.nixosConfigurations.x = {
                    nix.build_mode = "remote";
                    machines.a = m // {
                      hardware_config_path = "/hw.nix";
                      activation_hooks.pre = [ "echo {{ x }}" ];
                    };
                    machines.Bad = m // {
                      ssh.extra_flags = [
                        "-o"
                        "StrictHostKeyChecking=no"
                      ];
                    };
                  };
                };
              };
              good.fleet.flakes.f.installables.nixosConfigurations.x.machines.a = m;
              n = lib.length (violations bad);
            in
            assert lib.assertMsg (n == 9) "panix-hardened: expected 9 violations, got ${toString n}";
            assert lib.assertMsg (violations good == [ ]) "panix-hardened: clean config flagged";
            pkgs.runCommand "panix-hardened" { } "touch $out";
        };
      }
      // lib.optionalAttrs (cfg.enable && cfg.writeFile) {
        files.file."panix.yml".source =
          lib.throwIf (cfg.flakeUrl == null)
            "den.panix.writeFile needs den.panix.flakeUrl: a committed panix.yml has no wrapper to fill the url in"
            self'.packages.panix-config;
      };
  };
}
