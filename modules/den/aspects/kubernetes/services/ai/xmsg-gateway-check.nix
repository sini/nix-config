# xmsg-gateway-check: the hardening, shared uid, owner configuration, grant-store
# initContainers, secret modes and egress of xmsg-gateway.nix, asserted over the
# aspect's manifests with the flag forced on and the pinned images, so the check holds
# whatever axon's flags are. A second render with the tunnel on (stand-in image and
# id) shows the sidecar appears only then, pointed at the loopback listener.
#   nix build .#checks.x86_64-linux.xmsg-gateway-pod
{ config, ... }:
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
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.xmsg-gateway-pod =
        pkgs.runCommand "xmsg-gateway-pod" { nativeBuildInputs = [ pkgs.python3 ]; }
          ''
            python3 -I ${./xmsg-gateway-check.py} ${pkgs.writeText "xmsg-gateway.json" (builtins.toJSON manifests)}
            touch $out
          '';
    };
}
