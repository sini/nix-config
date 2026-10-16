# Hardened rules for the panix battery (panix review 2026-10-16, commit
# 414806c). `den.panix.violations` lists every break in a set of rendered
# settings; the battery fails eval on any when `hardened` is on. Reasons per
# rule: docs/panix.md.
{ lib, config, ... }:
let
  inherit (lib) mkOption types;

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
in
{
  options.den.panix = {
    hardened = mkOption {
      type = types.bool;
      default = true;
      description = "Fail eval when the merged settings break the rules listed in docs/panix.md.";
    };
    violations = mkOption {
      type = types.functionTo (types.listOf types.str);
      readOnly = true;
      internal = true;
      default = violations;
      description = "Plain settings data (nulls dropped) -> rule violations.";
    };
    hardenedCheck = mkOption {
      type = types.functionTo types.package;
      readOnly = true;
      internal = true;
      description = "pkgs -> the panix-hardened check (wired by the battery's perSystem).";
      # One fixture breaking each rule once, compared message by message, so
      # a regression names the rule that stopped (or started) firing.
      default =
        pkgs:
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
          f = "fleet.flakes.f.installables.nixosConfigurations.x";
          expected = [
            "fleet.ssh.disable_strict_key_checking: strict host key checking must stay on"
            "${f}.machines.Bad.ssh.extra_flags: must not loosen host key checking (StrictHostKeyChecking=no, StrictHostKeyChecking=accept-new, UserKnownHostsFile=/dev/null)"
            "fleet.bootstrap.ssh: bootstrap ssh does not belong in the everyday config"
            "${f}.machines.a.hardware_config_path: hardware_config_path writes target output into the flake"
            "flags.skip_phases: skipping inspect makes live hosts look unprovisioned"
            "fleet.bootstrap.force_bootstrap: destructive flags only at machine level"
            "${f}: build_mode remote needs exactly one machine (it builds on the first and copies peer to peer)"
            "${f}.machines.a.activation_hooks.pre.0: literal '{{' would be read as a panix template: echo {{ x }}"
            "${f}.machines.Bad: name is outside [a-z0-9-]"
          ];
          got = violations bad;
          missing = lib.subtractLists got expected;
          unexpected = lib.subtractLists expected got;
          show = xs: lib.concatMapStrings (x: "\n  - " + x) xs;
        in
        assert lib.assertMsg (missing == [ ] && unexpected == [ ]) (
          "panix-hardened: rule output changed."
          + lib.optionalString (missing != [ ]) "\nno longer reported:${show missing}"
          + lib.optionalString (unexpected != [ ]) "\nnewly reported:${show unexpected}"
        );
        assert lib.assertMsg (
          violations good == [ ]
        ) "panix-hardened: clean config flagged:${show (violations good)}";
        pkgs.runCommand "panix-hardened" { } "touch $out";
    };
  };
}
