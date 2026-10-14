# xmsg-check: two checks over what nix-config renders for xmsg.
#
# xmsg-peers: every peers file loads in the xmsg it runs (`xmsg check-peers`, the
# loader `xmsg serve` uses): bitstream's and cortex's, each checked against its own
# node certificate.
#   nix build .#checks.x86_64-linux.xmsg-peers
#
# xmsg-harnesses: opencode reaches xmsg through the module's plugin and has no xmsg MCP
# server (an `xmsg mcp` child of opencode is anonymous), and patch (darwin) runs no
# `xmsg serve`. Each failing property is printed by name.
#   nix build .#checks.x86_64-linux.xmsg-harnesses
{
  config,
  lib,
  ...
}:
let
  hosts = [
    "bitstream"
    "cortex"
  ];
  nixosOf = h: config.flake.nixosConfigurations.${h};
  homeOf = h: (nixosOf h).config.home-manager.users.sini;
  patch = config.flake.darwinConfigurations.patch.config.home-manager.users.sini;
  opencodeMcp =
    h:
    (builtins.fromJSON (
      builtins.unsafeDiscardStringContext (homeOf h).home.file.".config/opencode/opencode.json".text
    )).mcp or { };
  properties =
    lib.concatMap (h: [
      {
        name = "${h}: opencode has no xmsg MCP server";
        ok = !(opencodeMcp h ? xmsg);
      }
      {
        name = "${h}: opencode loads the xmsg plugin";
        ok = (homeOf h).xdg.configFile ? "opencode/plugin/xmsg.ts";
      }
    ]) (hosts ++ [ "blade" ])
    ++ [
      {
        name = "patch: no launchd xmsg agent";
        ok = !(patch.launchd.agents.xmsg.enable or false);
      }
      {
        name = "patch: no systemd xmsg unit";
        ok = !(patch.systemd.user.services ? xmsg);
      }
    ];
  failed = map (p: p.name) (lib.filter (p: !p.ok) properties);
  argvOf = h: lib.splitString " " (lib.head (homeOf h).systemd.user.services.xmsg.Service.ExecStart);
  flagOf =
    h: flag:
    let
      argv = argvOf h;
      i = lib.lists.findFirstIndex (a: a == flag) null argv;
    in
    if i == null then throw "xmsg-check: ${h}'s xmsg unit has no ${flag}" else lib.elemAt argv (i + 1);
in
{
  perSystem =
    { pkgs, system, ... }:
    {
      checks = lib.optionalAttrs (system == (nixosOf "bitstream").pkgs.stdenv.hostPlatform.system) {
        xmsg-peers =
          pkgs.runCommand "xmsg-peers"
            {
              nativeBuildInputs = [
                (homeOf "bitstream").programs.xmsg.package
              ];
            }
            ''
              ${lib.concatMapStrings (h: ''
                xmsg check-peers ${flagOf h "--peers-file"} --fed-cert ${flagOf h "--fed-cert"}
              '') hosts}
              touch $out
            '';

        xmsg-harnesses = pkgs.runCommand "xmsg-harnesses" { } ''
          failed=${lib.escapeShellArg (lib.concatStringsSep "\n" failed)}
          if [ -n "$failed" ]; then
            printf 'xmsg-harnesses: failed:\n%b\n' "$failed" >&2
            exit 1
          fi
          echo "xmsg-harnesses: ${toString (lib.length properties)} properties hold"
          touch $out
        '';
      };
    };
}
