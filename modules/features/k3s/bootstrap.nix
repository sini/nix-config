{
  flake.modules.nixos.kubernetes =
    {
      inputs,
      ...
    }:
    {
      system.activationScripts = {
        k3s-bootstrap = {
          text = (
            let
              k3sBootstrapFile =
                (inputs.kubenix.evalModules.x86_64-linux {
                  module = import ./_bootstrap;
                }).config.kubernetes.result;
            in
            ''
              mkdir -p /var/lib/rancher/k3s/server/manifests
              ln -sf ${k3sBootstrapFile} /var/lib/rancher/k3s/server/manifests/k3s-bootstrap.json
            ''
          );
        };
      };
    };
}
