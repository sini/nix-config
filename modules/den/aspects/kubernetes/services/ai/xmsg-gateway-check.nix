# xmsg-gateway-check: the hardening, shared uid, owner configuration, grant-store
# initContainers, secret modes, hub peers, xmsg-leaves record and egress of
# xmsg-gateway.nix, asserted over axon's rendered resources (the gateway's chart and the
# objects around it), so it checks what the chart produces for axon's instance.
#   nix build .#checks.x86_64-linux.xmsg-gateway-pod
{ config, lib, ... }:
let
  aspect = config.den.aspects.kubernetes.services.ai.xmsg-gateway;
  app = config.flake.nixidyEnvs.x86_64-linux.axon.config.applications.xmsg-gateway;
  # The rendered objects (chart and hand-set alike), keyed as nixidy's resources are.
  byKind =
    kind:
    lib.listToAttrs (
      map (o: lib.nameValuePair o.metadata.name o) (lib.filter (o: o.kind == kind) app.objects)
    );
  manifests = {
    axon.applications.xmsg-gateway = {
      inherit (app) namespace;
      resources = lib.mapAttrs (_: byKind) {
        deployments = "Deployment";
        serviceAccounts = "ServiceAccount";
        certificates = "Certificate";
        configMaps = "ConfigMap";
        persistentVolumeClaims = "PersistentVolumeClaim";
        ciliumClusterwideNetworkPolicies = "CiliumClusterwideNetworkPolicy";
        ciliumNetworkPolicies = "CiliumNetworkPolicy";
        services = "Service";
        ingresses = "Ingress";
        httpRoutes = "HTTPRoute";
      };
    };
    # Independent oracle: expected leaf record from den.hosts and cluster settings (never xmsg.fleet).
    leaves =
      let
        gw = config.den.clusters.axon.settings.kubernetes.services.ai.xmsg-gateway;
      in
      [
        {
          identity = "spiffe://json64.dev/ns/xmsg-gateway/sa/xmsg-gateway";
          cluster = "axon";
          hubs = map (h: "${config.den.hosts.x86_64-linux.${h}.system-owner}.${h}") (
            [ gw.hub ] ++ (gw.extraHubs or [ ])
          );
          allow = [
            "send"
            "reply"
            "list"
          ];
          targets = null;
        }
      ];
  };

  # Negative controls: each mutant must fail the check on the named property. The
  # `mutants` rewrite the pod's initContainers; `wholeMutants` rewrite any part of the
  # render.
  resPath = [
    "applications"
    "xmsg-gateway"
    "resources"
  ];
  atOff =
    path: update:
    manifests
    // {
      axon = lib.updateManyAttrsByPath [ { inherit path update; } ] manifests.axon;
    };
  bitstreamIp = "10.9.1.1/32";
  wholeMutants = {
    # The leaf federates with cortex only.
    "one peer per hub" =
      atOff
        (
          resPath
          ++ [
            "configMaps"
            "xmsg-gateway-peers"
            "data"
            "peers.json"
          ]
        )
        (
          s:
          let
            f = builtins.fromJSON s;
          in
          builtins.toJSON (f // { peers = removeAttrs f.peers [ "sini.bitstream" ]; })
        );
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
    "policy-chatgpt.json is every hub's sessions, send and reply" = atOff (
      resPath
      ++ [
        "configMaps"
        "xmsg-gateway-config"
        "data"
        "policy-chatgpt.json"
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
    # The summaries migration on a scratch copy instead of the real store.
    "no scratch copy" =
      rewrite "store-migrate-custody-summaries" "args" "/state/grants.db"
        "/staging/custody-summaries-scratch.db";
    # A plain init: fails on the existing store at every start.
    "store-init has --if-needed" = noIfNeeded "store-init";
    # A plain enroll: fails on the enrolled grant at every start.
    "store-enroll-chatgpt has --if-needed" = noIfNeeded "store-enroll-chatgpt";
    # migrations-pending exits 10 with work pending, so no backup and a failed pod.
    "backup is backup-if-pending beside the state directory" =
      rewrite "store-backup" "args" "backup-if-pending"
        "migrations-pending";
    # Every backup but the newest pruned.
    "backup keeps the newest 3" = rewrite "store-backup" "args" "3" "1";
    # A real-store migration before the backup that protects it.
    "backup runs after init, before the real store's migrations" =
      moveAfter "store-backup" "store-migrate-custody";
    # The policy applied before the last migration.
    "apply is last" = moveAfter "store-apply-chatgpt" "store-backup";
    # The chain gone, so the policy is never applied.
    "apply step present" = lib.filter (c: c.name != "store-apply-chatgpt");
    # apply also enabling the grant at every start.
    "apply has no --enabled" = map (
      c: if c.name == "store-apply-chatgpt" then c // { args = c.args ++ [ "--enabled" ]; } else c
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
