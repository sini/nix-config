{
  den.aspects.applications.dev.k8s.core = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = [
          pkgs.kubectl
          # shortcut: TestPush fails against its in-process mock registry in nixpkgs
          # 20261107 (kubecfg 0.38.0); drop the skip when nixpkgs' build passes again.
          (pkgs.kubecfg.overrideAttrs (old: {
            checkFlags = (old.checkFlags or [ ]) ++ [ "-skip=^TestPush$" ];
          }))
          pkgs.kubectx
          pkgs.kubecolor
          pkgs.kconf
          pkgs.konf
          pkgs.kubecm
          pkgs.kubeswitch
          pkgs.kns
        ];
      };
  };
}
