# Panix battery: a panix.yml fleet generated from den host entities.
#
# Site-neutral: it reads only den-generic host fields (name, system, intoAttr,
# aspects); site values are den.panix.* options (this fleet sets them in
# modules/den/defaults.nix). Pieces of the feature:
#   ./settings.nix       typed settings (den.panix.fleets) and rendering
#   ./hardened.nix       review rules, den.panix.violations, the check
#   classes/panix.nix    the opt-in `panix` class
#   policies/panix.nix   per-host capture of `panix` class fragments
# This file derives the settings and wires the outputs. Per deployer system,
# den.panix.fleets.<system> merges, with module semantics:
#   1. derived defaults (mkDefault, each at its own panix level):
#        flags        local_machine_hostname (sentinel), runtime.max_concurrency
#        fleet        ssh hardening, bootstrap.disable_nix_install, auto_rollback
#        flake        url
#        installable  nix.build_mode  (remote when host.system != deployer)
#        machine      ssh.hostname, ssh.username, tags (hostTags ++ aspect tags)
#      One installable per host at its flake output (host.intoAttr, e.g.
#      nixosConfigurations.<name>); hosts without one (intoAttr = [ ]) are skipped.
#   2. den.panix.settings, a settings module (flags, output_types, fleet/flake).
#   3. with enableClass, each fleet host's `panix` class fragments.
# Nothing else is set, so panix's fleet -> flake -> installable -> machine
# inheritance stays in charge. Usage and options: docs/panix.md.
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
      p = cfg.pathOf host;
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

  configFileFor =
    system: pkgs:
    let
      settings = cfg.fleets.${system};
      clean =
        v:
        if builtins.isAttrs v then
          lib.mapAttrs (_: clean) (lib.filterAttrs (_: x: x != null) v)
        else if builtins.isList v then
          map clean v
        else
          v;
      # JSON round-trip to plain data, nulls (unset) dropped, as rendered.
      errs = cfg.violations (clean (builtins.fromJSON (builtins.toJSON settings)));
    in
    lib.throwIf (cfg.hardened && errs != [ ]) ''
      den.panix (hardened): the panix settings break these rules (see docs/panix.md, or set den.panix.hardened = false):
        - ${lib.concatStringsSep "\n  - " errs}'' (cfg.render pkgs settings);
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
    settings = mkOption {
      type = types.deferredModule;
      default = { };
      description = "Settings module merged into every den.panix.fleets.<system> (flags, output_types, fleet- or flake-level settings).";
    };
    enableClass = mkOption {
      type = types.bool;
      default = false;
      description = "Collect `panix` class fragments (settings modules) from each fleet host's aspects.";
    };
    writeFile = mkOption {
      type = types.bool;
      default = false;
      description = "Also write panix.yml into the repo through github:sini/files (files.file). Needs flakeUrl.";
    };
    pathOf = mkOption {
      type = types.functionTo (types.attrsOf types.str);
      readOnly = true;
      internal = true;
      description = "Host entity -> { flake, outputType, installable, machine }, its keys in panix.yml (fragments get it as `panixPath`).";
      default = host: {
        flake = cfg.flakeName;
        outputType = builtins.elemAt host.intoAttr 0;
        installable = builtins.elemAt host.intoAttr 1;
        machine = host.name;
      };
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

    den.panix.fleets = lib.mkIf cfg.enable (
      lib.genAttrs config.systems (
        system:
        # A function, so `imports` is a module key, not a setting (submodule
        # attrset definitions are config-only shorthand).
        _: {
          imports = [
            cfg.settings
            (mkDefaults globalDefaults)
          ]
          ++ lib.mapAttrsToList (_: host: mkDefaults (hostDefaults system host)) hosts
          ++ lib.optionals cfg.enableClass (
            lib.concatMap (name: config.flake.panixModules.${name} or [ ]) (builtins.attrNames hosts)
          );
        }
      )
    );

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
            # url filled in. TMPDIR, where panix puts its ssh control sockets,
            # is a private 0700 directory too: $XDG_RUNTIME_DIR/panix, else
            # .panix/tmp (a socket path must stay under ~104 bytes, which a
            # deep checkout's .panix can exceed). PANIX_CONFIG (panix's env
            # form of -c) overrides the config.
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
                if [ -n "''${XDG_RUNTIME_DIR:-}" ]; then
                  tmp="$XDG_RUNTIME_DIR/panix"
                else
                  tmp="$state/tmp"
                fi
                umask 077
                mkdir -p "$state" "$tmp"
                chmod 0700 "$state" "$tmp"
                if [ -n "''${PANIX_CONFIG:-}" ]; then
                  PANIX_CONFIG=$(realpath "$PANIX_CONFIG")
                else
                  sed 's|${urlSentinel}|git+file://'"$root"'|g' ${panix-config} > "$state/panix.yml"
                  PANIX_CONFIG="$state/panix.yml"
                fi
                export PANIX_CONFIG
                export TMPDIR="$tmp"
                cd "$state"
                exec ${lib.getExe inputs'.panix.packages.default} "$@"
              '';
            };
          }
        )
      )
    );

    # den reads these as raw values (no mkIf); the aspect is inert until included.
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
      { self', ... }:
      lib.optionalAttrs (cfg.enable && cfg.writeFile) {
        files.file."panix.yml".source =
          lib.throwIf (cfg.flakeUrl == null)
            "den.panix.writeFile needs den.panix.flakeUrl: a committed panix.yml has no wrapper to fill the url in"
            self'.packages.panix-config;
      };
  };
}
