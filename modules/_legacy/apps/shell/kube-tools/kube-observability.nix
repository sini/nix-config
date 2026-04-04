{
  features.kube-observability.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        cilium-cli
        hubble
        stern
        kubeshark
        kubespy
        kube-capacity
        kube-linter
        kubeconform
        kubeval
        datree
        popeye
        netassert
        k8sgpt
      ];
    };
}
