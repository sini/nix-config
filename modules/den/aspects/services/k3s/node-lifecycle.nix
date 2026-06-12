# K3s node lifecycle — drain on shutdown, uncordon on startup.
#
# Sub-aspect of k3s (which includes it). One oneshot unit whose stop path is
# the drain: systemd stops units in reverse ordering-dependency order, so with
# After=k3s.service the ExecStop drain runs to completion BEFORE systemd may
# begin stopping k3s (the node-local apiserver is still serving), and
# After=containerd.service keeps the runtime alive while evicted pods
# terminate. Deliberately NO PartOf/BindsTo on k3s: a k3s service restart
# (colmena activation) must not drain — with the standalone containerd a k3s
# restart never touches running pods (KillMode=process, Delegate=yes), only
# the control plane blips. The unit is only stopped in the same transaction
# as k3s during system shutdown/reboot, which is exactly when draining is
# wanted; that makes rolling reboots (colmena --reboot -p1, the toggle
# script) stagger on PDBs — CNPG gets a clean switchover before the node
# goes down.
#
# Shutdown can never deadlock on the drain: evictions that cannot proceed
# (whole-cluster poweroff, last node standing) hit --timeout and the script
# exits zero anyway.
{
  den.aspects.services.k3s.node-lifecycle = {
    nixos =
      {
        config,
        pkgs,
        ...
      }:
      let
        nodeName = config.networking.hostName;
      in
      {
        systemd.services.k3s-node-lifecycle = {
          description = "K3s node lifecycle: uncordon after startup, drain before shutdown";
          wantedBy = [ "multi-user.target" ];
          after = [
            "k3s.service"
            "containerd.service"
          ];
          wants = [ "k3s.service" ];
          path = [ pkgs.kubectl ];
          environment.KUBECONFIG = "/etc/rancher/k3s/k3s.yaml";

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            TimeoutStartSec = "10min";
            # Must exceed the drain --timeout below.
            TimeoutStopSec = "7min";

            ExecStart = pkgs.writeShellScript "k3s-node-uncordon" ''
              echo "Waiting for node ${nodeName} to be Ready..."
              until kubectl wait --for=condition=Ready "node/${nodeName}" --timeout=30s 2>/dev/null; do
                sleep 5
              done
              kubectl uncordon "${nodeName}"
            '';

            ExecStop = pkgs.writeShellScript "k3s-node-drain" ''
              # Never block shutdown on a broken control plane.
              if ! kubectl get node "${nodeName}" --request-timeout=10s >/dev/null 2>&1; then
                echo "apiserver unreachable; skipping drain"
                exit 0
              fi

              echo "Draining ${nodeName}..."
              kubectl drain "${nodeName}" \
                --ignore-daemonsets \
                --delete-emptydir-data \
                --timeout=5m \
                || echo "drain incomplete (timeout or eviction failure); continuing shutdown"
              exit 0
            '';
          };
        };
      };
  };
}
