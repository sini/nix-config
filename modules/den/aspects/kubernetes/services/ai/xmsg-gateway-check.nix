# xmsg-gateway-check: the hardening, shared uid, owner configuration, grant-store
# initContainers, secret modes and egress of xmsg-gateway.nix, asserted over the
# aspect's manifests with the flag forced on and the pinned images, so the check holds
# whatever axon's flags are. A second render with the tunnel on (stand-in image and
# id) shows the sidecar appears only then, pointed at the loopback listener.
#   nix build .#checks.x86_64-linux.xmsg-gateway-pod
{ config, lib, ... }:
let
  render =
    tunnel:
    config.den.aspects.kubernetes.services.ai.xmsg-gateway.k8s-manifests {
      config.age.secrets = {
        xmsg-gateway-events-key.sopsRef = "ref+sops://stand-in";
        xmsg-gateway-lookup-oidc-client-secret.sopsRef = "ref+sops://stand-in";
        xmsg-gateway-tunnel-runtime-key.sopsRef = "ref+sops://stand-in";
      };
      cluster = {
        name = "axon";
        environment = "prod";
        domainFor = svc: if svc == "kanidm" then "idm.json64.dev" else "${svc}.json64.dev";
        settings.kubernetes.services.ai.xmsg-gateway = {
          enable = true;
          hub = "cortex";
          kanidmHost = "uplink";
          # A stand-in: the real value is measured at cutover.
          subject = "00000000-0000-4000-8000-000000000000";
          inherit tunnel;
        };
      };
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
  };

  # Negative controls: each mutant of the tunnel-off pod's initContainers must fail the
  # check on the named property.
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
  mutant =
    f:
    manifests
    // {
      off = lib.updateManyAttrsByPath [
        {
          path = initsPath;
          update = f;
        }
      ] manifests.off;
    };
  isInspect = c: c.name == "store-retirement-inspect";
  mutants = {
    # migrate-retirement before the inspect that backs up.
    "inspect runs before migrate-retirement" =
      inits:
      let
        i = lib.findFirst isInspect null inits;
        rest = lib.filter (c: !isInspect c) inits;
        at = lib.lists.findFirstIndex (c: c.name == "store-migrate-retirement") null rest;
      in
      lib.take (at + 1) rest ++ [ i ] ++ lib.drop (at + 1) rest;
    # A backup on every start, not only for a legacy store.
    "inspect, migrated store: link to the staged store, no backup" = map (
      c:
      if isInspect c then
        c
        // {
          command = map (lib.replaceStrings [ "if app == LEGACY:" ] [ "if True:" ]) c.command;
        }
      else
        c
    );
    # The link to the real store made before the backup.
    "inspect, legacy store, backup impossible: refuses, no link to the real store" = map (
      c:
      if isInspect c then
        c
        // {
          command = map (lib.replaceStrings
            [
              "os.makedirs("
            ]
            [
              "os.symlink(\"/var/lib/xmsg-mcp-gateway/state/grants.db\", \"/var/lib/xmsg-mcp-gateway/staging/retirement.db\"); os.makedirs("
            ]
          ) c.command;
        }
      else
        c
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
              lib.mapAttrsToList (property: f: ''
                if python3 -I ${./xmsg-gateway-check.py} ${
                  json "xmsg-gateway-mutant" (mutant f) pkgs
                } > mutant.log; then
                  echo "negative control passed the check: ${property}" >&2; exit 1
                fi
                grep -qF -- ${lib.escapeShellArg property} mutant.log || { cat mutant.log >&2; echo "negative control failed elsewhere: ${property}" >&2; exit 1; }
                echo "negative control refused: ${property}"
              '') mutants
            )}
            touch $out
          '';
    };
}
