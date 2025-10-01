{
  writeShellApplication,
  openssh,
  kubectl,
  gnused,
}:
writeShellApplication {
  name = "reset-axon";
  runtimeInputs = [
    openssh
    kubectl
    gnused
  ];
  excludeShellChecks = [ "SC2016" ];
  text = ''
    colmena exec --on axon-01,axon-02,axon-03 -- systemctl stop k3s containerd
    colmena exec --on axon-01,axon-02,axon-03 -- k3s-killall.sh
    colmena exec --on axon-01,axon-02,axon-03 -- 'KUBELET_PATH=$(mount | grep kubelet | cut -d" " -f3) ''${KUBELET_PATH:+umount $KUBELET_PATH}'
    colmena exec --on axon-01,axon-02,axon-03 -- systemctl start containerd
    colmena exec --on axon-01,axon-02,axon-03 -- systemctl stop containerd
    colmena exec --on axon-01,axon-02,axon-03 -- rm -rf /etc/rancher/ /var/lib/rancher/ /var/lib/containerd/ /var/lib/kubelet/ /var/lib/cni/ /run/k3s/ /run/containerd/ /run/cni/ /opt/cni/ /opt/containerd/
    echo "Applying changes to axon-01..."
    colmena apply --on axon-01
    scp sini@axon-01:/etc/rancher/k3s/k3s.yaml "''${HOME}/.config/kube/config"
    sed -i 's/0.0.0.0/axon-01/' "''${HOME}/.config/kube/config"
    kubectl get nodes -o wide
    echo "Bringing up additional nodes..."
    colmena apply --on axon-02,axon-03
    kubectl get nodes -o wide
  '';
}
