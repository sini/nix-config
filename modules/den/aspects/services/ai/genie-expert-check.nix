# genie-expert-check: the isolation properties of genie-expert.nix, asserted over
# bitstream's evaluated config. Each failing property is printed by name.
#   nix build .#checks.x86_64-linux.genie-expert
#
# The token secret is gated on its .age existing, so its owner and mode are read
# from the declared slot (services.genie-expert.tokenSecret); the instances are
# defined either way and only their `enable` follows the token.
{ config, lib, ... }:
let
  nixos = config.flake.nixosConfigurations.bitstream;
  c = nixos.config;
  home = "/var/lib/genie";
  ownerClaude = "${c.users.users.sini.home}/.claude";
  tokenPath = "${c.age.secretsDir}/genie-claude-token";

  u = c.users.users.genie;
  mounts = lib.filterAttrs (n: _: lib.hasPrefix "${home}/" n) c.fileSystems;
  under = prefix: lib.filter (lib.hasPrefix prefix);

  secret = c.services.genie-expert.tokenSecret;
  # Once the token exists, the live secret must be that declaration.
  liveSecret = c.age.secrets.genie-claude-token or null;

  svc = t: c.systemd.services."genie-expert@${t}" or { serviceConfig = { }; };
  binds = t: lib.toList ((svc t).serviceConfig.BindReadOnlyPaths or [ ]);
  bindSrcs = t: map (b: lib.head (lib.splitString ":" (lib.removePrefix "-" b))) (binds t);
  memBinds = t: lib.filter (lib.hasSuffix ":${home}/memory") (binds t);
  inacc = t: lib.toList ((svc t).serviceConfig.InaccessiblePaths or [ ]);
  tmpl = (c.systemd.services."genie-expert@" or { serviceConfig = { }; }).serviceConfig;

  settingsRule = lib.findFirst (lib.hasInfix "/claude/settings.json") null c.systemd.tmpfiles.rules;

  checks = {
    userIsSystem = !u.isNormalUser && u.group == "genie";
    noExtraGroups = u.extraGroups == [ ] && !(lib.elem "genie" (c.users.groups.wheel.members or [ ]));
    sshDenied = lib.elem "genie" (lib.toList (c.services.openssh.settings.DenyUsers or [ ]));
    checkoutsMounted = mounts != { };
    allMountsRo = lib.all (m: lib.elem "ro" m.options && !(lib.elem "rw" m.options)) (
      lib.attrValues mounts
    );
    hostMountsNoOwnerClaude =
      under ownerClaude (map (m: m.device) (lib.attrValues c.fileSystems)) == [ ];
    secretRootOwned = secret.owner or null == "root" && secret.group or null == "root";
    secretMode = secret.mode or null == "0400";
    liveSecretIsDeclared =
      liveSecret == null
      || lib.all (k: liveSecret.${k} == secret.${k}) [
        "owner"
        "group"
        "mode"
      ];
    loadCredential = tmpl.LoadCredential or null == "claude-token:${tokenPath}";
    serviceUser = tmpl.User or null == "genie";
    publicNoOwnerClaude =
      c.systemd.services ? "genie-expert@public" && under ownerClaude (bindSrcs "public") == [ ];
    publicSupportMemory = memBinds "public" == [ "${home}/support-memory:${home}/memory" ];
    trustedMemory = memBinds "trusted" == [ "${ownerClaude}/memory:${home}/memory" ];
    publicHidesTrusted = lib.elem "${home}/tiers/trusted" (inacc "public");
    trustedHidesPublic = lib.elem "${home}/tiers/public" (inacc "trusted");
    sandboxOnPath = lib.all (t: lib.hasInfix "bubblewrap" ((svc t).environment.PATH or "")) [
      "public"
      "trusted"
    ];
    settingsLinked = settingsRule != null;
  };
  failed = lib.attrNames (lib.filterAttrs (_: ok: !ok) checks);
in
{
  perSystem =
    { pkgs, system, ... }:
    {
      checks = lib.optionalAttrs (system == nixos.pkgs.stdenv.hostPlatform.system) {
        genie-expert = pkgs.runCommand "genie-expert" { nativeBuildInputs = [ pkgs.jq ]; } ''
          failed=${lib.escapeShellArg (lib.concatStringsSep " " failed)}
          settings=${lib.last (lib.splitString " " (toString settingsRule))}
          want='["${tokenPath}", "/run/credentials", "/proc/*/environ"]'
          jq -e --argjson want "$want" \
            '.sandbox.enabled == true and ($want - .sandbox.filesystem.denyRead == [])' \
            "$settings" > /dev/null || failed="$failed settingsDenyRead"
          if [ -n "$failed" ]; then
            echo "genie-expert: failed: $failed" >&2
            exit 1
          fi
          echo "genie-expert: ${toString (lib.length (lib.attrNames checks))} properties + settingsDenyRead hold"
          touch $out
        '';
      };
    };
}
