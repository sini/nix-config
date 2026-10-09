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
  shared = "/var/lib/genie";
  publicClones = "${shared}/public-repos";
  ownerHome = c.users.users.sini.home;
  ownerCheckouts = "/var/lib/genie-trusted/repos";
  # Measured with `gh repo view sini/<r> --json visibility` (2026-10-08): the
  # checkouts that must never reach the public tier.
  knownPrivate = [
    "den-ag-design"
    "gen-progress-report-v1"
  ];
  ownerClaude = "${ownerHome}/.claude";
  tokenPath = "${c.age.secretsDir}/genie-claude-token";
  tiers = [
    "public"
    "trusted"
  ];
  user = tier: "genie-${tier}";

  u = tier: c.users.users.${user tier} or null;
  userOk =
    tier:
    let
      x = u tier;
    in
    x != null
    && !x.isNormalUser
    && x.group == user tier
    && x.extraGroups == [ ]
    && !(lib.elem (user tier) (c.users.groups.wheel.members or [ ]))
    && x.home == "/var/lib/${user tier}"
    && x.homeMode == "700";

  mounts = lib.filterAttrs (n: _: lib.hasPrefix "${ownerCheckouts}/" n) c.fileSystems;
  ownerSourced = lib.filterAttrs (_: m: lib.hasPrefix "${ownerHome}/" m.device) c.fileSystems;

  # The repos genie-public-repos clones: its ExecStart arguments.
  fetchArgs = lib.tail (
    lib.splitString " " (c.systemd.services.genie-public-repos.serviceConfig.ExecStart or "")
  );
  fetched = map (a: lib.removePrefix "'" (lib.removeSuffix "'" a)) fetchArgs;
  under = prefix: lib.filter (lib.hasPrefix prefix);

  secret = c.services.genie-expert.tokenSecret;
  # Once the token exists, the live secret must be that declaration.
  liveSecret = c.age.secrets.genie-claude-token or null;

  tmpl = (c.systemd.services."genie-expert@" or { serviceConfig = { }; }).serviceConfig;
  svc = tier: c.systemd.services."genie-expert@${tier}" or { serviceConfig = { }; };
  # The uid an instance runs as: its drop-in's User, else the template's.
  runsAs = tier: (svc tier).serviceConfig.User or tmpl.User or null;
  binds = tier: lib.toList ((svc tier).serviceConfig.BindReadOnlyPaths or [ ]);
  bindSrcs = tier: map (b: lib.head (lib.splitString ":" (lib.removePrefix "-" b))) (binds tier);
  bindsTo = target: tier: lib.filter (lib.hasSuffix ":${target}") (binds tier);
  memBinds = bindsTo "${shared}/memory";
  repoBinds = bindsTo "${shared}/repos";

  settingsRules = map (
    tier:
    lib.findFirst (lib.hasPrefix "L+ /var/lib/${user tier}/.claude/settings.json ") null
      c.systemd.tmpfiles.rules
  ) tiers;

  checks = {
    publicUser = userOk "public";
    trustedUser = userOk "trusted";
    sshDenied = lib.all (
      tier: lib.elem (user tier) (lib.toList (c.services.openssh.settings.DenyUsers or [ ]))
    ) tiers;
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
    # One uid per tier, never one serving both.
    tiersSeparateUids =
      lib.all (tier: runsAs tier == user tier) tiers
      && lib.length (lib.unique (map runsAs tiers)) == lib.length tiers;
    publicNoOwnerClaude =
      c.systemd.services ? "genie-expert@public" && under ownerClaude (bindSrcs "public") == [ ];
    # Public sees only clean clones of public repos, never an owner working tree.
    publicReposOnlyPublic =
      fetched != [ ]
      && lib.intersectLists fetched knownPrivate == [ ]
      && repoBinds "public" == [ "${publicClones}:${shared}/repos" ]
      && under ownerHome (bindSrcs "public") == [ ]
      && under ownerCheckouts (bindSrcs "public") == [ ];
    publicMemoryFromGenieAgent =
      lib.elem "genie-agent" fetched
      && memBinds "public" == [ "${publicClones}/genie-agent/support-memory:${shared}/memory" ];
    trustedRepos = repoBinds "trusted" == [ "${ownerCheckouts}:${shared}/repos" ];
    # Owner working trees are mounted only inside the 0700 trusted home.
    ownerCheckoutsInTrustedHome =
      ownerSourced != { } && lib.all (lib.hasPrefix "${ownerCheckouts}/") (lib.attrNames ownerSourced);
    privateTmp =
      tmpl.PrivateTmp or false == true
      && lib.all (tier: (svc tier).serviceConfig.PrivateTmp or true == true) tiers;
    protectSystemStrict =
      tmpl.ProtectSystem or null == "strict"
      && lib.all (
        tier:
        (svc tier).serviceConfig.ReadWritePaths or null == [ "/var/lib/${user tier}" ]
        && (svc tier).environment.HOME or null == "/var/lib/${user tier}"
      ) tiers;
    trustedMemory = memBinds "trusted" == [ "${ownerClaude}/memory:${shared}/memory" ];
    sandboxOnPath = lib.all (tier: lib.hasInfix "bubblewrap" ((svc tier).environment.PATH or "")) tiers;
    settingsLinked = lib.all (r: r != null) settingsRules;
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
          want='["${tokenPath}", "/run/credentials", "/proc/*/environ"]'
          for settings in ${
            lib.escapeShellArgs (map (r: lib.last (lib.splitString " " (toString r))) settingsRules)
          }; do
            jq -e --argjson want "$want" \
              '.sandbox.enabled == true and ($want - .sandbox.filesystem.denyRead == [])' \
              "$settings" > /dev/null || failed="$failed settingsDenyRead"
          done
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
