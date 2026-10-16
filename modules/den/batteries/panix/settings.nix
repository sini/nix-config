# panix option module contributed by theutz (Matrix).
#
# The typed panix.yml settings: `den.panix.fleets.<system>` holds the merged
# settings per deployer system (the battery, ./panix.nix, defines them) and
# `den.panix.render` turns one into the store file. Adapted from his module:
# the option tree and its stripNulls / checkTransfer / permissions-sentinel
# rendering are his; it is declared here as a flake-level module instead of a
# standalone panix.settings module, and fragments get `panixPath`
# (den.panix.pathOf) as a specialArg; the top-level freeform type is
# types.anything, so no pkgs is needed to declare it. panix 0.11.0 resolves relative paths
# against its working directory, not panix.yml's.
#
# Nix module for Panix configuration (panix.yml), translated from
# https://raw.githubusercontent.com/mihakrumpestar/panix/main/gen/panix-schema.yaml (v0.11.0)
#
# Option names are kept in snake_case so they map 1:1 onto the YAML keys and
# the upstream docs (RFC 42 "settings" style). Every optional field defaults
# to `null` and is stripped before serialization, so anything you don't set
# is simply absent from the YAML and Panix's own defaults / level-by-level
# inheritance (fleet -> flake -> installable -> machine) keep working.
#
# Paths (identity_file, local_path, hardware_config_path, ...) are typed as
# strings, not `types.path`, so they stay relative to panix.yml instead of
# being copied into the Nix store.
{ lib, config, ... }:
let
  inherit (lib) mkOption types;

  # ---------------------------------------------------------------- helpers

  opt =
    type: description:
    mkOption {
      type = types.nullOr type;
      default = null;
      inherit description;
    };

  sub = options: types.submodule { inherit options; };

  str = types.str;
  bool = types.bool;
  int = types.int;
  listOfStr = types.listOf types.str;
  envVars = types.attrsOf types.str;

  # Recursively drop nulls so unset options don't end up in the YAML.
  stripNulls =
    v:
    if builtins.isAttrs v then
      lib.mapAttrs (_: stripNulls) (lib.filterAttrs (_: x: x != null) v)
    else if builtins.isList v then
      map stripNulls v
    else
      v;

  # JSON-schema constraints on TransferSource that a plain submodule can't express:
  #   anyOf [required: command, required: local_path]
  #   dependencies: uid <-> gid
  checkTransfer =
    s:
    lib.throwIf (s.local_path == null && s.command == null)
      "panix: transfer to '${s.remote_path}' needs at least one of local_path or command"
      (
        lib.throwIf (
          (s.uid == null) != (s.gid == null)
        ) "panix: transfer to '${s.remote_path}' must set uid and gid together" (encodePermissions s)
      );

  # The YAML generator would quote a template string ('{{ ... }}'), so
  # permissions are first replaced with a sentinel, which the configFile
  # derivation then rewrites into an unquoted template expression.
  octalSentinel = "__PANIX_OCTAL_";
  encodePermissions =
    s:
    if s.permissions == null then
      s
    else
      let
        p = s.permissions;
        padded = if builtins.stringLength p == 3 then "0${p}" else p;
      in
      s // { permissions = "${octalSentinel}${padded}__"; };

  # ------------------------------------------------------------ definitions

  activationHooks = sub {
    pre = opt listOfStr ''
      Commands to run before activation (same format as bootstrap hooks).
      A failure skips activation and fails the machine without rollback.
    '';
    post = opt listOfStr ''
      Commands to run after activation succeeds, only for mutating modes
      (skipped for non-mutating modes such as dry-activate). A failure fails
      the deploy without rolling back the successful activation.
    '';
  };

  transferSource = sub {
    command = opt str ''
      Command whose stdout is streamed to remote_path. When local_path is also
      set, the command receives it as PANIX_SECRET_LOCAL_PATH.
    '';
    local_path = opt str "Path to a local file or directory.";
    remote_path = mkOption {
      type = types.strMatching "/.*";
      description = "Absolute path on the remote machine.";
    };
    permissions = opt (types.strMatching "[0-7]{3,4}") ''
      File mode as an octal string, e.g. "0600" or "600" (panix default: 0700).
      Rendered as a Go template, {{ "0600" | toOctal }}, so panix receives the
      correct integer.
    '';
    uid = opt int "User ID on the remote (requires gid).";
    gid = opt int "Group ID on the remote (requires uid).";
  };

  transferList =
    description:
    mkOption {
      type = types.nullOr (types.listOf transferSource);
      default = null;
      apply = v: if v == null then null else map checkTransfer v;
      inherit description;
    };

  sshClient = sub {
    disable_auto_add_host_key = opt bool "Disable automatically adding the host key to known_hosts on first connection (panix default: false).";
    disable_strict_key_checking = opt bool "Disable strict host key checking (panix default: false).";
    extra_flags = opt listOfStr "Extra flags passed to ssh, e.g. [ \"-o\" \"StrictHostKeyChecking=no\" ].";
    hostname = opt str "SSH hostname or IP address.";
    identity_file = opt str "Path to the SSH private key.";
    known_hosts_file = opt str ''
      Path to the known_hosts file (panix default: ~/.ssh/known_hosts;
      bootstrap SSH uses a temporary file).
    '';
    port = opt types.port "SSH port (panix default: 22).";
    username = opt str "SSH username (panix default: root).";
  };

  kexecConfig = sub {
    curl_default_flags = opt listOfStr "Base curl flags for downloading the kexec tarball (panix default: [ \"--fail\" \"-#\" \"-L\" \"-C\" \"-\" ]).";
    extra_flags = opt listOfStr "Extra flags passed to kexec, e.g. [ \"--no-sync\" ].";
    image = opt str ''
      URL or path to the kexec tarball (panix default: the nix-community
      nixos-kexec-installer-noninteractive-$PANIX_ARCH-linux.tar.gz release).
    '';
    ssh_port = opt types.port "SSH port of the kexec installer (panix default: 22).";
  };

  # `attributes_NixConfig` in the schema: the Nix installer used during bootstrap.
  nixInstallerConfig = sub {
    args = opt listOfStr "Arguments passed to the installer (panix default: [ \"install\" \"--no-confirm\" ]).";
    curl_default_flags = opt listOfStr "Base curl flags for downloading the installer (panix default: [ \"--fail\" \"-#\" \"-L\" \"-C\" \"-\" ]).";
    url = opt str "Installer script or binary, as an http(s) URL or local path (panix default: https://install.determinate.systems/nix).";
  };

  bootstrap = sub {
    allow_destructive_actions = opt bool "Allow destructive bootstrap actions (required for force_bootstrap and force_bootstrap_kexec).";
    disable_automatic_reboot = opt bool "Disable the automatic reboot after nixos-install.";
    disable_disko = opt bool "Disable building, transferring and running disko.";
    disable_nix_install = opt bool "Skip installing Nix on targets that lack it (panix default: false).";
    disk_encryption_keys = transferList ''
      Keys transferred to the installer's root filesystem. Prefix remote_path
      with /mnt to place them on the final system's disk.
    '';
    force_bootstrap = opt bool "Force bootstrap even if the machine already runs NixOS (requires allow_destructive_actions).";
    force_bootstrap_kexec = opt bool "Force kexec even if already in the NixOS installer (requires force_bootstrap and allow_destructive_actions).";
    kexec = opt kexecConfig "Kexec configuration for non-NixOS machines or reinstalls.";
    nix = opt nixInstallerConfig "Nix installer configuration used when the target lacks Nix.";
    post_bootstrap_hooks = opt listOfStr "Commands run after disko partitioning (NixOS bootstrap) or after the Nix installer.";
    post_bootstrap_install_hooks = opt listOfStr "Commands run after nixos-install, before reboot.";
    post_bootstrap_provisioned_hooks = opt listOfStr "Commands run after reboot (over regular SSH).";
    ssh = opt sshClient "SSH configuration used during initial provisioning.";
  };

  preset = sub {
    activation_default_mode = opt str "Default activation mode.";
    activation_non_mutating_modes = opt listOfStr "Activation modes that don't mutate the target (auto rollback is skipped for these).";
    activation_path = opt str "Activation script path in the closure.";
    activation_profile_skip_modes = opt listOfStr "Activation modes that don't set the profile before activating.";
    activation_supported_modes = opt listOfStr "Supported activation modes.";
    bootstrap_mode =
      opt
        (types.enum [
          "nixos"
          "nix-install"
        ])
        ''
          Bootstrap mode for this output type; unset disables bootstrap.
          Type-level field: only set under output_types.
        '';
    build_path = opt str "Build path within the flake output.";
    omit_type_from_attr_path = opt bool ''
      Omit the output type from the attrpath (for packages where nix resolves
      bare names). Type-level field: only set under output_types.
    '';
    output_type_attr = opt str "Top-level flake output attribute used in the attrpath (defaults to the output type key).";
    profile_path = opt str "Nix profile path.";
    set_profile = opt bool "Run nix-env --profile --set before activation.";
    system_level = opt bool ''
      System-level (root) vs user-level. Type-level field: only set under output_types.
    '';
  };

  # `nix_NixConfig` in the schema: build/copy configuration.
  nixConfig = sub {
    build_default_flags = opt listOfStr "Base flags for nix build (panix default: [ \"--no-link\" \"--print-out-paths\" \"--keep-going\" ]).";
    build_env = opt envVars "Environment for nix build only (merged on top of env).";
    build_flags = opt listOfStr "Extra flags for nix build, e.g. [ \"--max-jobs\" \"4\" ].";
    build_mode =
      opt
        (types.enum [
          "local"
          "remote"
        ])
        ''
          local: build locally and copy the closure to targets.
          remote: build on the first target via --store ssh-ng://<target>
          (panix default: local).
        '';
    copy_default_flags = opt listOfStr "Base flags for nix copy (panix default: [ \"--no-check-sigs\" ]).";
    copy_env = opt envVars "Environment for nix copy only (merged on top of env).";
    copy_flags = opt listOfStr "Extra flags for nix copy, e.g. [ \"--compress\" ].";
    env = opt envVars "Environment applied to all nix commands; command-specific env fields override it.";
    experimental_features = opt listOfStr "Experimental feature flags (panix default: [ \"--extra-experimental-features\" \"nix-command flakes\" ]).";
    extra_flags = opt listOfStr "Extra flags appended to both nix build and nix copy.";
    nixos_install_default_flags = opt listOfStr "Base flags for nixos-install (panix default: [ \"--no-root-passwd\" \"--no-channel-copy\" ]).";
    nixos_install_env = opt envVars "Environment for nixos-install only (merged on top of env).";
    nixos_install_flags = opt listOfStr "Extra flags for nixos-install, e.g. [ \"--no-bootloader\" ].";
    profile_add_default_flags = opt listOfStr "Base flags for nix profile add (panix default: [ ]).";
    profile_add_env = opt envVars "Environment for nix profile add only (merged on top of env).";
  };

  # ------------------------------------------------------- fleet hierarchy

  # Options shared by every level (fleet, flake, installable, machine).
  levelOptions = {
    activation_hooks = opt activationHooks "Hooks around the activation step.";
    auto_rollback = opt bool "Roll back to the pre-deploy generation when activation fails.";
    bootstrap = opt bootstrap "Bootstrap configuration for initial provisioning.";
    disabled = opt bool "Disable this level and everything beneath it.";
    hardware_config_path = opt str ''
      Local path for the target's generated hardware config, written once the
      target runs the NixOS installer. Keep it inside your flake.
    '';
    rsync_default_flags = opt listOfStr "Base rsync flags (panix default: [ \"-rcPEx\" \"--mkpath\" ]).";
    secrets = transferList "Files or directories to transfer to the remote machine.";
    ssh = opt sshClient "SSH configuration for remote access.";
    sudo_program = opt str "Elevation program used when the executing user is not root (panix default: sudo).";
    tags = opt listOfStr "Tags for filtering (flakes, configs and machine names are registered automatically).";
  };

  # Every level except machine also accepts `nix`.
  levelOptionsWithNix = levelOptions // {
    nix = opt nixConfig "Nix build and copy configuration.";
  };

  # In YAML a machine may be a bare key (`web-01:` -> null); here `web-01 = { };`
  # serializes to `web-01: {}`, which the schema also accepts.
  machine = sub levelOptions;

  installable = sub (
    levelOptionsWithNix
    // {
      activation_mode = opt str "Activation mode (overrides the preset default).";
      preset = opt preset "Per-installable preset overrides.";
      user = opt str ''
        Target user for activation, run via su -l (requires SSHing as root).
        If unset, uses the SSH username.
      '';
      machines = mkOption {
        type = types.attrsOf machine;
        description = "Machines this installable is deployed to.";
      };
    }
  );

  flake = sub (
    levelOptionsWithNix
    // {
      url = opt str ''
        Flake path (e.g. ./dir) or URL (path:, ssh:, github:, ...) (panix default: .).
      '';
      installables = mkOption {
        # output type (nixosConfigurations, homeConfigurations, ...) -> name -> installable
        type = types.attrsOf (types.attrsOf installable);
        description = "Installables, keyed by output type and then attribute name.";
      };
    }
  );

  fleet = sub (
    levelOptionsWithNix
    // {
      flakes = mkOption {
        type = types.attrsOf flake;
        description = "Flakes in the fleet.";
      };
    }
  );

  # ------------------------------------------------------------------ flags

  flags = sub {
    activation_mode = opt (sub {
      alltypes = opt str "Activation mode applied to all output types.";
      pertype = opt (types.attrsOf str) "Activation mode per output type.";
    }) "Activation mode override.";
    dry_run = opt bool "Show what would be done without executing.";
    dry_run_with_inspect = opt bool "Dry run, but with a real inspect query.";
    exit_on_complete = opt bool "Exit the TUI on completion.";
    local_machine_hostname = opt str "Hostname treated as local (no SSH) (panix default: the deploying machine's hostname).";
    logging = opt (sub {
      debug = opt bool "Debug mode (enables logging).";
      log = opt bool "Enable logging to file.";
      log_file = opt str "Log file path; epoch timestamp is appended before .log (panix default: panix.log).";
    }) "Logging settings.";
    out_links = opt bool ''
      Create GC-root outlinks for built installables in out_links_dir,
      structured as <flake>/<output_type>/<name>.
    '';
    out_links_dir = opt str "Directory for build outlinks (panix default: .panix).";
    output = opt (types.enum [
      "tui"
      "console"
      "json"
    ]) "Output mode.";
    profile = opt (sub {
      block = opt str "Block profile output path (enables block profiling).";
      cpu = opt str "CPU profile output path (enables CPU profiling).";
      goroutine = opt str "Goroutine profile output path (enables goroutine profiling).";
      mem = opt str "Memory profile output path (enables memory profiling).";
      mutex = opt str "Mutex profile output path (enables mutex profiling).";
    }) "Profiling settings.";
    require_all_success = opt bool "Abort if any task fails, for CI/CD (disables the retry and restart keybinds).";
    rollback_generation = opt int "0 = current generation, -N = Nth before current, N = specific generation (panix default: -1).";
    runtime = opt (sub {
      disconnect_timeout = opt str "Timeout waiting for a host to disconnect during reboot (panix default: 5m).";
      flake_validation_timeout = opt str "Timeout for nix flake metadata/eval during validation (panix default: 60s).";
      max_concurrency = opt types.ints.unsigned "Maximum concurrent workers, 0 = unlimited (panix default: 0).";
      reconnect_timeout = opt str "Timeout waiting for a host to reconnect after reboot (panix default: 10m).";
      ssh_reachability_timeout = opt str "TCP dial timeout for the SSH reachability probe (panix default: 2s).";
    }) "Runtime settings.";
    skip_phases = opt listOfStr "Phases to skip (not all phases can be skipped).";
    snapshot = opt (sub {
      dir = opt str "Directory to save snapshots (panix default: .).";
      on_exit = opt bool "Take a snapshot on exit.";
      on_retry = opt bool "Take a snapshot before retry.";
    }) "Snapshot settings.";
    tags = opt listOfStr "Only deploy machines matching these tags.";
    timeout = opt str "Timeout per command, e.g. 1h or 1m15s (panix default: 2h).";
    tui = opt (sub {
      command_output_max_height = opt types.ints.positive "Max height of command output viewports (panix default: 8).";
      command_output_max_lines = opt types.ints.positive "Max output lines kept per command (panix default: 10000).";
      show_active_only = opt bool "Show only running or errored logs (keybind a).";
      show_all_build_logs = opt bool "Show all build logs (keybind h).";
      show_commands_in_labels = opt bool "Show raw commands instead of descriptions as labels (keybind c).";
    }) "TUI settings.";
    validate = opt (sub {
      bootstrap_secrets = opt bool "Validate that bootstrap disk encryption key local paths exist.";
      flakes = opt bool "Validate flake URLs and configuration keys.";
    }) "Validator settings.";
  };

  settingsType = types.submoduleWith {
    shorthandOnlyDefinesConfig = true;
    # specialArgs, not _module.args: fragments build attr names from it.
    specialArgs.panixPath = config.den.panix.pathOf;
    modules = [
      {
        # The schema allows additional top-level keys (additionalProperties: true).
        freeformType = types.attrsOf types.anything;
        options = {
          flags = opt flags "Flags (also settable on the CLI).";
          fleet = mkOption {
            type = fleet;
            description = "Fleet configuration.";
          };
          output_types = opt (types.attrsOf preset) "Custom output type presets, applied as defaults to installables of that type.";
        };
      }
    ];
  };
in
{
  options.den.panix = {
    fleets = mkOption {
      type = types.lazyAttrsOf settingsType;
      default = { };
      internal = true;
      description = "Merged panix.yml settings, per deployer system.";
    };

    render = mkOption {
      type = types.functionTo (types.functionTo types.package);
      readOnly = true;
      internal = true;
      description = "pkgs -> settings -> the panix.yml store file.";
      # Generate the YAML, then turn every permissions sentinel (quoted or not)
      # into an unquoted Go template:  permissions: {{ "0600" | toOctal }}
      default =
        pkgs: settings:
        let
          json = pkgs.writeText "panix.json" (builtins.toJSON (stripNulls settings));
          sedExpr = "s/['\"]?${octalSentinel}([0-7]{4})__['\"]?/{{ \"\\1\" | toOctal }}/g";
        in
        pkgs.runCommand "panix.yml"
          {
            nativeBuildInputs = [ pkgs.yq-go ];
            preferLocalBuild = true;
          }
          ''
            yq --input-format json --output-format yaml ${json} \
              | sed -E ${lib.escapeShellArg sedExpr} > $out

            if grep -q ${lib.escapeShellArg octalSentinel} $out; then
              echo "panix: unreplaced permissions sentinel in generated YAML" >&2
              exit 1
            fi
          '';
    };
  };
}
