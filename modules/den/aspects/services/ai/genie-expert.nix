# genie-expert: what remains of the per-user expert stack once genie-agent's expert
# tiers run in local mode (genie-experts.nix, GI-13 §6.4): the two tier users and the
# clean public clones the public tier reads.
#
# The users `genie-public` and `genie-trusted` stay: genie-public-repos runs as
# genie-public, and the tiers' xmsg buses (genie-xmsg.nix) run as theirs. Neither holds
# any of the system owner's credentials: no wheel, no ssh login, no group that reaches
# the owner's files, and a 0700 home of its own.
#
# genie-public-repos keeps /var/lib/genie/public-repos at exactly the published main of
# each PUBLIC repo (no working-tree extras), refreshed hourly; the clones are 0755, so
# the public tier, running as the owner, reads them.
#
# The tmux expert instances (genie-expert@<tier>) and their genie-claude-token are
# retired, so a stray genie-claude-token.age can no longer bring up a second stack.
{ lib, ... }:
let
  publicClones = "/var/lib/genie/public-repos";
  tiers = [
    "public"
    "trusted"
  ];
  user = tier: "genie-${tier}";
  homeOf = tier: "/var/lib/${user tier}";
in
{
  den.aspects.services.ai.genie-expert = {
    settings.publicRepos = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "[A-Za-z0-9._-]+");
      # The repos whose GitHub visibility is PUBLIC (`gh repo view sini/<r>
      # --json visibility`, 2026-10-08). List a repo here only once it is public.
      default = [
        "xmsg"
        "matrix-xmsg"
        "genie-agent"
        "genx"
        "gen"
        "gen-algebra"
        "gen-aspects"
        "gen-assemble"
        "gen-bind"
        "gen-class"
        "gen-delivery"
        "gen-demand"
        "gen-demo"
        "gen-differential"
        "gen-dispatch"
        "gen-edge"
        "gen-flake"
        "gen-graph"
        "gen-harness"
        "gen-identity"
        "gen-inspect"
        "gen-link"
        "gen-lsp"
        "gen-memo"
        "gen-merge"
        "gen-pipe"
        "gen-prelude"
        "gen-product"
        "gen-program"
        "gen-rebuild"
        "gen-resolve"
        "gen-rules"
        "gen-schema"
        "gen-scope"
        "gen-select"
        "gen-settings"
        "gen-types"
        "gen-vars"
        "gen-view"
      ];
      description = "Public github.com/sini repos the public tier sees, as clean clones of main. Must include genie-agent, whose support-memory/ is the public memory.";
    };

    nixos =
      {
        host,
        pkgs,
        ...
      }:
      let
        cfg = host.settings.services.ai.genie-expert;

        # Clones each repo, or resets it to the published main and removes
        # anything else, so the clone is exactly the published tree. Every repo is
        # tried; any failure fails the unit.
        fetch = pkgs.writeShellScript "genie-public-repos" ''
          fail=0
          for r in "$@"; do
            d="$STATE_DIRECTORY/$r"
            if [ -d "$d/.git" ]; then
              git -C "$d" fetch --quiet origin main &&
                git -C "$d" reset --quiet --hard FETCH_HEAD &&
                git -C "$d" clean --quiet -ffdx
            else
              rm -rf "$d" && git clone --quiet --branch main "https://github.com/sini/$r.git" "$d"
            fi || { echo "genie-public-repos: $r failed" >&2; fail=1; }
          done
          exit "$fail"
        '';
      in
      {
        assertions = [
          {
            assertion = lib.elem "genie-agent" cfg.publicRepos;
            message = "genie-expert: the public tier's memory is genie-agent's support-memory/, so `publicRepos` must include genie-agent.";
          }
        ];

        users.groups = lib.genAttrs (map user tiers) (_: { });
        users.users = lib.listToAttrs (
          map (
            tier:
            lib.nameValuePair (user tier) {
              group = user tier;
              isSystemUser = true;
              useDefaultShell = true;
              home = homeOf tier;
              homeMode = "700";
              createHome = true;
              description = "@genie ${tier} tier";
            }
          ) tiers
        );

        services.openssh.settings.DenyUsers = map user tiers;

        # createHome skips a home that already exists, so this `d` rule (which also
        # fixes an existing directory) keeps the mode authoritative.
        systemd.tmpfiles.rules = [
          "d /var/lib/genie 0755 root root -"
        ]
        ++ map (tier: "d ${homeOf tier} 0700 ${user tier} ${user tier} -") tiers;

        systemd.services.genie-public-repos = {
          description = "genie: clean clones of the public repos for the public tier";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          path = [ pkgs.git ];
          environment = {
            HOME = "/var/empty";
            GIT_CONFIG_NOSYSTEM = "1";
          };
          serviceConfig = {
            Type = "oneshot";
            User = user "public";
            Group = user "public";
            StateDirectory = lib.removePrefix "/var/lib/" publicClones;
            ExecStart = "${fetch} ${lib.escapeShellArgs cfg.publicRepos}";
            ProtectSystem = "strict";
            ProtectHome = true;
            PrivateTmp = true;
            NoNewPrivileges = true;
          };
        };

        systemd.timers.genie-public-repos = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "2min";
            OnUnitActiveSec = "1h";
          };
        };
      };

    persist.directories = [
      {
        directory = publicClones;
        user = user "public";
        group = user "public";
        mode = "0755";
      }
    ];
  };
}
