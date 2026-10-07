# xmsg (github:sini/xmsg): lists running agent sessions and delivers messages into
# them. Anonymous callers (scripts, CI, other hosts over ssh) use HTTP on loopback;
# agents use the `xmsg mcp` tools, whose send/reply go over agent.sock and are
# attested by SO_PEERCRED, so an agent can never claim another session's identity.
#
# The input SOURCE builds our own `xmsg` package (pkgs/by-name/xmsg), threaded to
# callPackage as `xmsg-src` by the overlay in pkgs/overlays.nix.
{ ... }:
{
  flake-file.inputs.xmsg = {
    url = "github:sini/xmsg";
    inputs.nixpkgs.follows = "nixpkgs-unstable";
  };

  den.aspects.applications.dev.ai.mcp.xmsg = {
    # Folded into the MCP registry of every agent aspect that reads agent-extensions
    # (agents/claude.nix, agents/antigravity-cli.nix).
    agent-extensions =
      { lib, pkgs, ... }:
      {
        type = "mcp";
        mcpServers.xmsg = {
          command = lib.getExe pkgs.local.xmsg;
          args = [ "mcp" ];
        };
      };

    homeManager =
      { lib, pkgs, ... }:
      let
        xmsg = lib.getExe pkgs.local.xmsg;
      in
      lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
        home.packages = [ pkgs.local.xmsg ];

        # Runs as the sessions' own user: the inbox sockets live in 0700 dirs, and
        # xmsg's own sockets require $XDG_RUNTIME_DIR. Loopback only; widening
        # --listen exposes every session to anyone who can reach the port.
        systemd.user.services.xmsg = {
          Unit.Description = "xmsg: bridge into running agent sessions";
          Service = {
            ExecStart = "${xmsg} serve --listen 127.0.0.1:7787";
            Restart = "on-failure";
          };
          Install.WantedBy = [ "default.target" ];
        };

        # The owner's explicit authorization of the three tools. Allowed calls skip
        # the auto-mode classifier, so the tools must never be requiresUserInteraction.
        programs.claude-code.settings.permissions.allow = [
          "mcp__xmsg__list"
          "mcp__xmsg__send"
          "mcp__xmsg__reply"
        ];

        # agy registers its language-server credentials before every turn. The hook
        # always prints {"injectSteps":[]} and exits 0, even with the server down.
        home.file.".gemini/config/hooks.json".text = builtins.toJSON {
          xmsg-register.PreInvocation = [
            {
              type = "command";
              command = "${xmsg} register agy";
            }
          ];
        };
      };
  };
}
