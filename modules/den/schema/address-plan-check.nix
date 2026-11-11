# The address plan's pure checks (docs/address-plan.md §3), each with a control
# that must fail or throw:
#   address-plan-slices  every environment's (purpose) /64s, as GUA subnet ids and
#                        site-ULA subnets, lie in its own /60 and overlap no other;
#                        prod's LAN ULA is Blocky's fd3d:f136:2e4e::/64 exactly; the
#                        fleet yields 2 × 3 slices. Controls: two environments on
#                        one nibble, and a nibble of 16, throw
#   nix build .#checks.x86_64-linux.address-plan-slices
{ config, lib, ... }:
let
  plan = import ./_address-plan.nix { inherit lib; };

  # Every (environment, purpose) slice of the environments with a nibble.
  slicesOf =
    envs:
    let
      withNibble = lib.filter (e: e.ipv6Nibble or null != null) envs;
      byNibble = lib.groupBy (e: toString e.ipv6Nibble) withNibble;
      shared = lib.filterAttrs (_: es: lib.length es > 1) byNibble;
    in
    if shared != { } then
      throw "address-plan: environments ${
        lib.concatMapStringsSep ", " (es: lib.concatMapStringsSep "/" (e: e.name) es) (
          lib.attrValues shared
        )
      } share a nibble"
    else
      lib.concatMap (
        e:
        lib.mapAttrsToList (purpose: p: rec {
          env = e.name;
          inherit purpose;
          nibble = e.ipv6Nibble;
          id = plan.subnetId e.ipv6Nibble p;
          gua = plan.subnetHex id;
          ula = plan.ulaSubnet id;
        }) plan.purposes
      ) withNibble;

  slices = slicesOf (lib.attrValues config.den.environments);
  ulaHead = lib.removeSuffix "::/48" plan.ula;
  slicesOk =
    ss:
    lib.length ss == 2 * lib.length (lib.attrNames plan.purposes)
    && lib.length (lib.unique (map (s: s.id) ss)) == lib.length ss
    && lib.length (lib.unique (map (s: s.ula) ss)) == lib.length ss
    # Inside its own /60: the id's high nibble is the environment's.
    && lib.all (s: s.id / 16 == s.nibble && s.id < 256) ss
    && lib.all (s: lib.hasPrefix "${ulaHead}:" s.ula && lib.hasSuffix "::/64" s.ula) ss;
  throws = v: !(builtins.tryEval (builtins.deepSeq v null)).success;
  fixture = name: ipv6Nibble: { inherit name ipv6Nibble; };
  prodLan = config.den.environments.prod.networks.default.ipv6_cidr;

  checks = {
    slices = slicesOk slices;
    prodLanIsBlockys = prodLan == "fd3d:f136:2e4e::/64";
    devLanIsSubnet10 =
      config.den.environments.dev.networks.default.ipv6_cidr == "fd3d:f136:2e4e:10::/64";
    lanUlaIsSlice = lib.all (
      s: s.purpose != "lan" || config.den.environments.${s.env}.networks.default.ipv6_cidr == s.ula
    ) slices;
    guaIds =
      lib.sort lib.lessThan (map (s: s.gua) slices) == [
        "0"
        "1"
        "10"
        "11"
        "12"
        "2"
      ];
    # Controls.
    sharedNibbleThrows = throws (slicesOf [
      (fixture "a" 0)
      (fixture "b" 0)
    ]);
    nibble16Throws = throws (slicesOf [ (fixture "a" 16) ]);
    oneEnvFails = !(slicesOk (slicesOf [ (fixture "a" 0) ]));
    overlapFails = !(slicesOk (lib.init slices ++ [ (lib.head slices // { env = "x"; }) ]));
    foreignSliceFails = !(slicesOk (lib.init slices ++ [ (lib.last slices // { nibble = 5; }) ]));
  };
  failed = lib.attrNames (lib.filterAttrs (_: ok: !ok) checks);
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.address-plan-slices = pkgs.runCommand "address-plan-slices" { } ''
        failed=${lib.escapeShellArg (lib.concatStringsSep " " failed)}
        if [ -n "$failed" ]; then
          echo "address-plan-slices: failed: $failed" >&2
          exit 1
        fi
        echo "address-plan-slices: ${toString (lib.length (lib.attrNames checks))} properties hold"
        touch $out
      '';
    };
}
