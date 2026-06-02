_: {
  den.aspects.apps.dev.k8s.helm = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.kubernetes-helm
          pkgs.helmfile
          pkgs.helm-ls
          pkgs.helmsman
          pkgs.kubernetes-helmPlugins.helm-cm-push
          pkgs.kubernetes-helmPlugins.helm-diff
          pkgs.kubernetes-helmPlugins.helm-s3
          pkgs.kubernetes-helmPlugins.helm-git
          pkgs.kubernetes-helmPlugins.helm-secrets
          pkgs.nova
        ];
      };
  };
}
