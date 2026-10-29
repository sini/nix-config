# genie-expert-check: the properties of genie-expert.nix, asserted over bitstream's
# evaluated config. Each failing property is printed by name.
#   nix build .#checks.x86_64-linux.genie-expert
#
# The tier users stay credential-free, the public clones hold only public repos, and
# the retired tmux expert stack (genie-expert@ and its genie-claude-token) stays gone.
{ config, lib, ... }:
let
  nixos = config.flake.nixosConfigurations.bitstream;
  c = nixos.config;
  ownerHome = c.users.users.sini.home;
  # Measured with `gh repo view sini/<r> --json visibility` (2026-10-08): the
  # checkouts that must never reach the public tier.
  knownPrivate = [
    "den-ag-design"
    "gen-progress-report-v1"
  ];
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

  # The repos genie-public-repos clones: its ExecStart arguments.
  fetchArgs = lib.tail (
    lib.splitString " " (c.systemd.services.genie-public-repos.serviceConfig.ExecStart or "")
  );
  fetched = map (a: lib.removePrefix "'" (lib.removeSuffix "'" a)) fetchArgs;

  checks = {
    publicUser = userOk "public";
    trustedUser = userOk "trusted";
    sshDenied = lib.all (
      tier: lib.elem (user tier) (lib.toList (c.services.openssh.settings.DenyUsers or [ ]))
    ) tiers;
    homesPrivate = lib.all (
      tier: lib.elem "d /var/lib/${user tier} 0700 ${user tier} ${user tier} -" c.systemd.tmpfiles.rules
    ) tiers;
    publicReposOnlyPublic = fetched != [ ] && lib.intersectLists fetched knownPrivate == [ ];
    publicMemoryFromGenieAgent = lib.elem "genie-agent" fetched;
    publicReposAsPublicUser =
      c.systemd.services.genie-public-repos.serviceConfig.User or null == user "public";
    # The retired stack: no template, no instance drop-in, no token.
    expertStackRetired = lib.all (n: !(lib.hasPrefix "genie-expert@" n)) (
      lib.attrNames c.systemd.services
    );
    expertTokenRetired = !(c.age.secrets ? genie-claude-token);
    # No host mount is sourced from the owner's home (the trusted tier binds its
    # sources in its own unit, read-only).
    noOwnerSourcedMounts = lib.all (m: !(lib.hasPrefix "${ownerHome}/" (m.device or ""))) (
      lib.attrValues c.fileSystems
    );
  };
  failed = lib.attrNames (lib.filterAttrs (_: ok: !ok) checks);
in
{
  perSystem =
    { pkgs, system, ... }:
    {
      checks = lib.optionalAttrs (system == nixos.pkgs.stdenv.hostPlatform.system) {
        genie-expert = pkgs.runCommand "genie-expert" { } ''
          failed=${lib.escapeShellArg (lib.concatStringsSep " " failed)}
          if [ -n "$failed" ]; then
            echo "genie-expert: failed: $failed" >&2
            exit 1
          fi
          echo "genie-expert: ${toString (lib.length (lib.attrNames checks))} properties hold"
          touch $out
        '';
      };
    };
}
