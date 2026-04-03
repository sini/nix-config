{ den, ... }:
{
  den.aspects.kube-dev = den.lib.perUser {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          devspace
          kind
          minikube
          kops
          kluctl
          kompose
          skaffold
          tilt
          kail
          krane
          kpt
          kontemplate
          timoni
        ];
      };
  };
}
