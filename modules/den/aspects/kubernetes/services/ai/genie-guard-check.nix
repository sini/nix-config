# genie-guard-check: the hardening, identity, egress and shared-socket properties
# of genie-guard.nix, asserted over axon's rendered resources (the xmsg chart in
# leaf mode with genie-agent's overlay), so it checks what the chart produces.
#   nix build .#checks.x86_64-linux.genie-guard-pod
{ config, lib, ... }:
let
  app = config.flake.nixidyEnvs.x86_64-linux.axon.config.applications.genie-guard;
  # The rendered objects (chart and hand-set alike), keyed as nixidy's resources are.
  byKind =
    kind:
    lib.listToAttrs (
      map (o: lib.nameValuePair o.metadata.name o) (lib.filter (o: o.kind == kind) app.objects)
    );
  manifests.applications.genie-guard = {
    inherit (app) namespace;
    resources = lib.mapAttrs (_: byKind) {
      deployments = "Deployment";
      serviceAccounts = "ServiceAccount";
      certificates = "Certificate";
      configMaps = "ConfigMap";
      ciliumClusterwideNetworkPolicies = "CiliumClusterwideNetworkPolicy";
      ciliumNetworkPolicies = "CiliumNetworkPolicy";
      services = "Service";
      ingresses = "Ingress";
      httpRoutes = "HTTPRoute";
    };
  };
in
{
  perSystem =
    { pkgs, ... }:
    {
      checks.genie-guard-pod =
        pkgs.runCommand "genie-guard-pod" { nativeBuildInputs = [ pkgs.python3 ]; }
          ''
            python3 -I ${./genie-guard-check.py} ${pkgs.writeText "genie-guard.json" (builtins.toJSON manifests)}
            touch $out
          '';
    };
}
