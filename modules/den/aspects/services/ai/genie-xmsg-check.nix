# genie-xmsg-check: the tier-bus properties of genie-xmsg.nix, asserted over
# bitstream's evaluated config. Each failing property is printed by name.
#   nix build .#checks.x86_64-linux.genie-xmsg
#
# The TCP property reads the rendered unit files, so a --listen or XMSG_LISTEN
# reaching a tier instance by any definition is caught. The node keys' owner and
# mode are read from the declared slot (services.genie-xmsg.keySecrets), since the
# live secrets exist only once settings.nodeKeys is set.
{ config, lib, ... }:
let
  nixos = config.flake.nixosConfigurations.bitstream;
  c = nixos.config;
  tiers = [
    "public"
    "trusted"
  ];
  user = tier: "genie-${tier}";

  tmpl = c.systemd.services."xmsg@" or { serviceConfig = { }; };
  svc = tier: c.systemd.services."xmsg@${tier}" or { serviceConfig = { }; };
  unitText = n: c.systemd.units."${n}.service".text or "";
  sc = tier: (svc tier).serviceConfig;
  runsAs = tier: (sc tier).User or tmpl.serviceConfig.User or null;

  keys = c.services.genie-xmsg.keySecrets;
  live = tier: c.age.secrets."xmsg-${user tier}" or null;
  ports = lib.attrValues c.services.genie-xmsg.fedPorts;

  checks = {
    instancesDefined = lib.all (tier: c.systemd.units ? "xmsg@${tier}.service") tiers;
    noTcp = lib.all (
      tier:
      lib.all (t: !(lib.hasInfix "--listen" t) && !(lib.hasInfix "XMSG_LISTEN" t)) [
        (unitText "xmsg@")
        (unitText "xmsg@${tier}")
      ]
    ) tiers;
    runtimeDirOwned = lib.all (
      tier:
      (sc tier).RuntimeDirectory or null == "xmsg-${tier}"
      && (sc tier).RuntimeDirectoryMode or null == "0700"
      && (sc tier).RuntimeDirectoryPreserve or null == "yes"
      && runsAs tier == user tier
      && (sc tier).Group or null == user tier
    ) tiers;
    xdgRuntimeDir = lib.all (
      tier:
      (svc tier).environment.XDG_RUNTIME_DIR or null == "/run/xmsg-${tier}"
      && c.services.genie-xmsg.runtimeDir.${tier} == "/run/xmsg-${tier}"
    ) tiers;
    tiersSeparateUids = lib.length (lib.unique (map runsAs tiers)) == lib.length tiers;
    fedPortsDistinct = lib.length ports == 3 && lib.length (lib.unique ports) == lib.length ports;
    keysOwnedPerTier =
      lib.all (
        tier:
        keys.${tier}.owner == user tier && keys.${tier}.group == user tier && keys.${tier}.mode == "0400"
      ) tiers
      && lib.length (lib.unique (map (tier: keys.${tier}.rekeyFile) tiers)) == lib.length tiers;
    liveKeysAreDeclared = lib.all (
      tier:
      live tier == null
      || lib.all (k: (live tier).${k} == keys.${tier}.${k}) [
        "owner"
        "group"
        "mode"
      ]
    ) tiers;
  };
  failed = lib.attrNames (lib.filterAttrs (_: ok: !ok) checks);
in
{
  perSystem =
    { pkgs, system, ... }:
    {
      checks = lib.optionalAttrs (system == nixos.pkgs.stdenv.hostPlatform.system) {
        genie-xmsg = pkgs.runCommand "genie-xmsg" { } ''
          failed=${lib.escapeShellArg (lib.concatStringsSep " " failed)}
          if [ -n "$failed" ]; then
            echo "genie-xmsg: failed: $failed" >&2
            exit 1
          fi
          echo "genie-xmsg: ${toString (lib.length (lib.attrNames checks))} properties hold"
          touch $out
        '';
      };
    };
}
