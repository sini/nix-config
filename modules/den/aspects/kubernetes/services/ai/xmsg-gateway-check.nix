# xmsg-gateway-check: the hardening, shared uid, owner configuration, grant-store
# initContainers, secret modes, hub peers, xmsg-leaves record and egress of
# xmsg-gateway.nix, asserted over the
# aspect's manifests with the flag forced on and the pinned images, so the check holds
# whatever axon's flags are. A second render with the tunnel on (stand-in image and
# id) shows the sidecar appears only then, pointed at the loopback listener.
#   nix build .#checks.x86_64-linux.xmsg-gateway-pod
{ config, lib, ... }:
let
  aspect = config.den.aspects.kubernetes.services.ai.xmsg-gateway;
  cluster = tunnel: {
    name = "axon";
    environment = "prod";
    domainFor = svc: if svc == "kanidm" then "idm.json64.dev" else "${svc}.json64.dev";
    settings.kubernetes.services.ai.xmsg-gateway = {
      enable = true;
      hub = "cortex";
      extraHubs = [ "bitstream" ];
      kanidmHost = "uplink";
      # A stand-in: the real value is measured at cutover.
      subject = "00000000-0000-4000-8000-000000000000";
      inherit tunnel;
    };
  };
  render =
    tunnel:
    aspect.k8s-manifests {
      config.age.secrets = {
        xmsg-gateway-events-key.sopsRef = "ref+sops://stand-in";
        xmsg-gateway-lookup-oidc-client-secret.sopsRef = "ref+sops://stand-in";
        xmsg-gateway-tunnel-runtime-key.sopsRef = "ref+sops://stand-in";
      };
      cluster = cluster tunnel;
      images = config.flake.imageRefs.x86_64-linux // {
        "openai/tunnel-client" = {
          repository = "ghcr.io/openai/tunnel-client";
          digest = "sha256:0000000000000000000000000000000000000000000000000000000000000000";
        };
      };
    };
  manifests = {
    off = render {
      enable = false;
      id = null;
    };
    on = render {
      enable = true;
      id = "tunnel_stand_in";
    };
    leaves = aspect.xmsg-leaves {
      cluster = cluster {
        enable = false;
        id = null;
      };
    };
  };

  # Negative controls: each mutant must fail the check on the named property. The
  # `mutants` rewrite the tunnel-off pod's initContainers; `wholeMutants` rewrite any
  # part of the render.
  resPath = [
    "applications"
    "xmsg-gateway"
    "resources"
  ];
  atOff =
    path: update:
    manifests
    // {
      off = lib.updateManyAttrsByPath [ { inherit path update; } ] manifests.off;
    };
  bitstreamIp = "10.9.1.1/32";
  wholeMutants = {
    # The leaf federates with cortex only.
    "one peer per hub" = atOff (
      resPath
      ++ [
        "configMaps"
        "xmsg-gateway-xmsg-peers"
        "data"
        "peers.json"
      ]
    ) (s: builtins.toJSON (removeAttrs (builtins.fromJSON s) [ "sini.bitstream" ]));
    # The peers entry kept, its egress dropped.
    "allow-xmsg-egress-xmsg-gateway-xmsg-gateway egress" = atOff (
      resPath
      ++ [
        "ciliumClusterwideNetworkPolicies"
        "allow-xmsg-egress-xmsg-gateway-xmsg-gateway"
        "spec"
        "egress"
      ]
    ) (lib.filter (r: !(lib.elem bitstreamIp (r.toCIDR or [ ]))));
    # bitstream's node never takes the leaf.
    "leaf record names every hub" = manifests // {
      leaves = map (l: l // { hubs = lib.take 1 l.hubs; }) manifests.leaves;
    };
    # The hubs grant the leaf no `list`, so xmsg_list comes back empty.
    "leaf record rights" = manifests // {
      leaves = map (l: l // { allow = lib.remove "list" l.allow; }) manifests.leaves;
    };
  };
  initsPath = [
    "applications"
    "xmsg-gateway"
    "resources"
    "deployments"
    "xmsg-gateway"
    "spec"
    "template"
    "spec"
    "initContainers"
  ];
  mutant = atOff initsPath;
  # The inspect step `inspect` moved after its migration `step`.
  inspectAfter =
    inspect: step: inits:
    let
      is = c: c.name == inspect;
      i = lib.findFirst is null inits;
      rest = lib.filter (c: !is c) inits;
      at = lib.lists.findFirstIndex (c: c.name == step) null rest;
    in
    lib.take (at + 1) rest ++ [ i ] ++ lib.drop (at + 1) rest;
  # The inspect step `inspect`'s script with `from` replaced by `to`.
  rewrite =
    inspect: from: to:
    map (
      c:
      if c.name == inspect then
        c // { command = map (lib.replaceStrings [ from ] [ to ]) c.command; }
      else
        c
    );
  mutants = {
    # migrate-retirement before the inspect that backs up.
    "inspect runs before migrate-retirement" =
      inspectAfter "store-retirement-inspect" "store-migrate-retirement";
    # A backup on every start, not only for a store not yet retired.
    "inspect, migrated store: link to the staged store, no backup" =
      rewrite "store-retirement-inspect" "if app == LEGACY or (app == SUMMARY and not retired):"
        "if True:";
    # The link to the real store made before the backup.
    "inspect, legacy store, backup impossible: refuses, no link to the real store" =
      rewrite "store-retirement-inspect" "os.makedirs("
        "os.symlink(\"/var/lib/xmsg-mcp-gateway/state/grants.db\", \"/var/lib/xmsg-mcp-gateway/staging/retirement.db\"); os.makedirs(";
    # A summary store taken for unretired, so it is backed up and migrated again.
    "inspect, summary store, retired: link to the staged store, no backup" =
      rewrite "store-retirement-inspect" " and not retired"
        "";
    # migrate-custody-summaries before the inspect that backs up.
    "summaries inspect runs before migrate-custody-summaries" =
      inspectAfter "store-custody-summaries-inspect" "store-migrate-custody-summaries";
    # A backup on every start, not only for a store without the summary marker.
    "summaries inspect, summary store: link to a pre-summary scratch copy of the staged store, no backup" =
      rewrite "store-custody-summaries-inspect" "if app != SUMMARY:" "if True:";
    # The link to the real store made before the backup.
    "summaries inspect, backup impossible: refuses, no link to the real store" =
      rewrite "store-custody-summaries-inspect" "os.makedirs("
        "os.symlink(\"/var/lib/xmsg-mcp-gateway/state/grants.db\", \"/var/lib/xmsg-mcp-gateway/staging/custody-summaries.db\"); os.makedirs(";
    # The gateway's `enable` verb in the chain.
    "never runs enable" =
      inits:
      inits
      ++ [
        {
          name = "store-enable";
          inherit (lib.last inits) image securityContext;
          args = [
            "enable"
            "chatgpt"
            "1"
          ];
        }
      ];
  };
  json =
    name: v: pkgs:
    pkgs.writeText "${name}.json" (builtins.toJSON v);
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.xmsg-gateway-pod =
        pkgs.runCommand "xmsg-gateway-pod" { nativeBuildInputs = [ pkgs.python3 ]; }
          ''
            python3 -I ${./xmsg-gateway-check.py} ${json "xmsg-gateway" manifests pkgs}
            ${lib.concatStrings (
              lib.mapAttrsToList (property: m: ''
                if python3 -I ${./xmsg-gateway-check.py} ${json "xmsg-gateway-mutant" m pkgs} > mutant.log; then
                  echo "negative control passed the check: ${property}" >&2; exit 1
                fi
                grep -qF -- ${lib.escapeShellArg property} mutant.log || { cat mutant.log >&2; echo "negative control failed elsewhere: ${property}" >&2; exit 1; }
                echo "negative control refused: ${property}"
              '') (lib.mapAttrs (_: mutant) mutants // wholeMutants)
            )}
            touch $out
          '';
    };
}
