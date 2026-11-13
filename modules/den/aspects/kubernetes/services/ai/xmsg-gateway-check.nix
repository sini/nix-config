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
    # schema/cluster.nix resourceNameOf: the last two labels, hyphenated.
    resourceForDomain =
      domain:
      lib.concatStringsSep "-" (
        lib.reverseList (lib.take 2 (lib.reverseList (lib.splitString "." domain)))
      );
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
    # The policy drops a hub, so sends to its sessions are refused.
    "policy.json is every hub's sessions, send and reply" = atOff (
      resPath
      ++ [
        "configMaps"
        "xmsg-gateway-config"
        "data"
        "policy.json"
      ]
    ) (lib.replaceStrings [ ''"*@sini.bitstream"'' ] [ ''"*@sini.cortex"'' ]);
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
  # The step `name` moved after the step `after`.
  moveAfter =
    name: after: inits:
    let
      is = c: c.name == name;
      i = lib.findFirst is null inits;
      rest = lib.filter (c: !is c) inits;
      at = lib.lists.findFirstIndex (c: c.name == after) null rest;
    in
    lib.take (at + 1) rest ++ [ i ] ++ lib.drop (at + 1) rest;
  # The step `name`'s command or args, each string with `from` replaced by `to`.
  rewrite =
    name: field: from: to:
    map (
      c:
      if c.name == name then
        c // { ${field} = map (lib.replaceStrings [ from ] [ to ]) c.${field}; }
      else
        c
    );
  noIfNeeded =
    name: map (c: if c.name == name then c // { args = lib.remove "--if-needed" c.args; } else c);
  mutants = {
    # A plain migration on the real store: fails on an already-migrated one.
    "store-migrate-custody-summaries has --if-needed" = noIfNeeded "store-migrate-custody-summaries";
    # And on the staged store, which migrate-custody already summarized.
    "staged-migrate-custody-summaries has --if-needed" = noIfNeeded "staged-migrate-custody-summaries";
    # The summaries migration on a scratch copy instead of the real store.
    "no scratch copy" =
      rewrite "store-migrate-custody-summaries" "args" "/state/grants.db"
        "/staging/custody-summaries-scratch.db";
    # A backup on exit 0 too, so every start backs up.
    "backup, exit 0: no backup" =
      inits:
      rewrite "store-backup" "command" "if r.returncode == 0:" "if False:" (
        rewrite "store-backup" "command" "if r.returncode != 10:" "if r.returncode not in (0, 10):" inits
      );
    # No backup on exit 10, so a pending migration runs unprotected.
    "backup, exit 10: one owner-private backup" =
      rewrite "store-backup" "command" "if r.returncode == 0:"
        "if r.returncode in (0, 10):";
    # An error exit (a missing or corrupt store) taken for "nothing pending".
    "backup, any other exit: refuses, no backup" =
      rewrite "store-backup" "command" "if r.returncode == 0:"
        "if r.returncode != 10:";
    # The done-rules copied back in as the decision.
    "backup decision is migrations-pending, no probe copy" =
      rewrite "store-backup" "command" "if r.returncode == 0:"
        ''if sqlite3.connect("file:/var/lib/xmsg-mcp-gateway/state/grants.db?mode=ro", uri=True).execute("PRAGMA user_version").fetchone()[0] == 4:'';
    # A failed backup taken for success.
    "backup, backup impossible: refuses" =
      rewrite "store-backup" "command" "os.makedirs("
        "sys.exit(0); os.makedirs(";
    # A real-store migration before the backup that protects it.
    "backup runs after install, before the real store's migrations" =
      moveAfter "store-backup" "store-migrate-custody";
    # The policy applied before the last migration.
    "apply is last" =
      inits:
      let
        n = lib.length inits;
      in
      lib.take (n - 2) inits
      ++ [
        (lib.last inits)
        (lib.elemAt inits (n - 2))
      ];
    # The chain gone, so the policy is never applied.
    "apply step present" = lib.filter (c: c.name != "store-apply");
    # apply also enabling the grant at every start.
    "apply has no --enabled" = map (
      c: if c.name == "store-apply" then c // { args = c.args ++ [ "--enabled" ]; } else c
    );
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
