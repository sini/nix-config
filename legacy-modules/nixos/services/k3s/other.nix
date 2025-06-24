_: { }
# { lib, config, pkgs, ... }:
# let
#   cfg = config.templates.services.k3s;
# in
# {
#   options.templates.services.k3s = {
#     enable = lib.mkOption {
#       type = lib.types.bool;
#       default = false;
#       description = "Enable Single Node K3S Cluster.";
#     };

#     delay = lib.mkOption {
#       type = lib.types.int;
#       default = 60;
#       description = "K3S Service Start Delay";
#     };

#     bootstrap = {
#       helm = {
#         enable = lib.mkOption {
#           type = lib.types.bool;
#           default = false;
#           description = "Enable Helm bootsrap service for K3S Cluster.";
#         };
#         completedIf = lib.mkOption {
#           type = lib.types.str;
#           description = ''
#              kubectl command condition meet when bootstrap is completed
#           '';
#         };
#         helmfile = lib.mkOption {
#           type = lib.types.str;
#           description = ''
#             Path to bootstrap helmfile
#           '';
#         };
#       };
#     };

#     prepare = {
#       cilium = lib.mkOption {
#         type = lib.types.bool;
#         default = false;
#         description = ''
#           Set required preconditions to install cilium to k3s cluster
#         '';
#       };
#     };

#     services = {
#       coredns = lib.mkOption {
#         type = lib.types.bool;
#         default = true;
#         description = ''
#           If enabled coredns will be installed to k3s cluster
#         '';
#       };

#       kube-proxy = lib.mkOption {
#         type = lib.types.bool;
#         default = true;
#         description = ''
#           If enabled k3s kube-proxy will be enabled on k3s cluster
#         '';
#       };

#       flannel = lib.mkOption {
#         type = lib.types.bool;
#         default = true;
#         description = ''
#           If enabled flannel will be enabled on k3s cluster
#         '';
#       };

#       flux = lib.mkOption {
#         type = lib.types.bool;
#         default = true;
#         description = ''
#           If enabled flux will be installed to k3s cluster
#         '';
#       };

#       servicelb = lib.mkOption {
#         type = lib.types.bool;
#         default = false;
#         description = ''
#           If enabled klipper-lb will be enabled on k3s cluster
#         '';
#       };

#       traefik = lib.mkOption {
#         type = lib.types.bool;
#         default = false;
#         description = ''
#           If enabled traefik will be enabled on k3s cluster
#         '';
#       };

#       local-storage = lib.mkOption {
#         type = lib.types.bool;
#         default = false;
#         description = ''
#           If enabled local-storage will be enabled on k3s cluster
#         '';
#       };

#       metrics-server = lib.mkOption {
#         type = lib.types.bool;
#         default = false;
#         description = ''
#           If enabled metrics-server will be enabled on k3s cluster
#         '';
#       };

#        nvidia = lib.mkOption {
#         type = lib.types.bool;
#         default = true;
#         description = ''
#           If enabled setup nvidia containerd runtime on k3s cluster
#         '';
#       };
#     };

#     addons = {
#       nfs = {
#         enable = lib.mkOption {
#           type = lib.types.bool;
#           default = false;
#           description = ''
#             If enabled a localhost only nfs-server will be enabled on node
#           '';
#         };
#         path = lib.mkOption {
#           type = lib.types.str;
#           default = "/mnt/nfs";
#           description = ''
#             Host path for nfs server share
#           '';
#         };
#       };

#       minio = {
#         enable = lib.mkOption {
#           type = lib.types.bool;
#           default = false;
#           description = ''
#             If enabled minio will be enabled on node
#           '';
#         };
#         credentialsFile = lib.mkOption {
#           type = lib.types.path;
#           description = ''
#             File containing the MINIO_ROOT_USER, default is "minioadmin", and
#             MINIO_ROOT_PASSWORD (length >= 8), default is "minioadmin"; in the format of
#             an EnvironmentFile=, as described by systemd.exec(5). The acess permission must
#             be set to 770 for minio:minio.
#           '';
#         };
#         region = lib.mkOption {
#           type = lib.types.str;
#           default = "local";
#           description = ''
#             The physical location of the server.
#           '';
#         };
#         buckets = lib.mkOption {
#           type = lib.types.listOf lib.types.str;
#           default = ["volsync" "postgres"];
#           description = ''
#             Bucket name.
#           '';
#         };
#         dataDir = lib.mkOption {
#           default = [ "/var/lib/minio/data" ];
#           type = lib.types.listOf (lib.types.either lib.types.path lib.types.str);
#           description = "The list of data directories or nodes for storing the objects.";
#         };
#       };
#     };
#   };

#   config = let
#     k3sAdmissionPlugins = [
#       "DefaultStorageClass"
#       "DefaultTolerationSeconds"
#       "LimitRanger"
#       "MutatingAdmissionWebhook"
#       "NamespaceLifecycle"
#       "NodeRestriction"
#       "PersistentVolumeClaimResize"
#       "Priority"
#       "ResourceQuota"
#       "ServiceAccount"
#       "TaintNodesByCondition"
#       "ValidatingAdmissionWebhook"
#     ];
#     k3sDisabledServices = []
#       ++ lib.optionals (cfg.services.flannel == false) [ "flannel" ]
#       ++ lib.optionals (cfg.services.servicelb == false) [ "servicelb" ]
#       ++ lib.optionals (cfg.services.coredns == false) [ "coredns" ]
#       ++ lib.optionals (cfg.services.local-storage == false) [ "local-storage" ]
#       ++ lib.optionals (cfg.services.metrics-server == false) [ "metrics-server" ]
#       ++ lib.optionals (cfg.services.traefik == false) [ "traefik" ]
#     ;
#     k3sExtraFlags = [
#       "--kubelet-arg=config=/etc/rancher/k3s/kubelet.config"
#       "--node-label \"k3s-upgrade=false\""
#       "--kube-apiserver-arg anonymous-auth=true"
#       "--kube-controller-manager-arg bind-address=0.0.0.0"
#       "--kube-scheduler-arg bind-address=0.0.0.0"
#       "--etcd-expose-metrics"
#       "--secrets-encryption"
#       "--write-kubeconfig-mode 0644"
#       "--kube-apiserver-arg='enable-admission-plugins=${lib.concatStringsSep "," k3sAdmissionPlugins}'"
#     ] ++ lib.lists.optionals (cfg.services.flannel == false) [
#       "--flannel-backend=none"
#       "--disable-network-policy"
#     ] ++ lib.optionals (cfg.services.kube-proxy == false) [
#       "--disable-cloud-controller"
#       "--disable-kube-proxy"
#     ] ++ lib.optionals cfg.prepare.cilium [
#       "--kubelet-arg=register-with-taints=node.cilium.io/agent-not-ready:NoExecute"
#     ];
#     k3sDisableFlags = builtins.map (service: "--disable ${service}") k3sDisabledServices;
#     k3sCombinedFlags = lib.concatLists [k3sDisableFlags k3sExtraFlags];
#   in
#     lib.mkIf cfg.enable {

#     templates = lib.mkIf cfg.services.nvidia {
#       hardware = {
#         nvidia.enable = true;
#       };
#     };

#     hardware.nvidia-container-toolkit = lib.mkIf cfg.services.nvidia {
#       enable = true;
#     };

#     environment = {
#       systemPackages = lib.mkMerge [
#         [
#           pkgs.runc
#           pkgs.age
#           pkgs.cilium-cli
#           pkgs.fluxcd
#           pkgs.kubernetes-helm
#           pkgs.helmfile
#           pkgs.git
#           pkgs.go-task
#           pkgs.minio-client
#           pkgs.jq
#           pkgs.k9s
#           pkgs.krelay
#           pkgs.kubectl
#           pkgs.nfs-utils
#           pkgs.openiscsi
#           pkgs.openssl_3
#           pkgs.sops

#           (pkgs.writeShellScriptBin "nuke-k3s" ''
#             if [ "$EUID" -ne 0 ] ; then
#               echo "Please run as root"
#               exit 1
#             fi
#             read -r -p 'Nuke k3s?, confirm with yes (y/N): ' choice
#             case "$choice" in
#               y|Y|yes|Yes) echo "nuke k3s...";;
#               *) exit 0;;
#             esac
#             systemctl stop k3s-helm-bootstrap.timer || true
#             systemctl stop k3s-helm-bootstrap.service || true
#             systemctl stop k3s-flux2-bootstrap.timer || true
#             systemctl stop k3s-flux2-bootstrap.service || true
#             flux uninstall -s || true
#             kubectl delete deployments --all=true -A
#             kubectl delete statefulsets --all=true -A
#             kubectl delete ns --all=true -A
#             kubectl get ns | tail -n +2 | cut -d ' ' -f 1 | xargs -I{} kubectl delete pods --all=true --force=true -n {}
#             cilium uninstall || true
#             echo "wait until objects are deleted..."
#             sleep 28
#             systemctl stop k3s
#             sleep 2
#             rm -rf /var/lib/rancher/k3s/
#             rm -rf /var/lib/cni/networks/cbr0/
#             if [ -d /opt/k3s/data/temp ]; then
#               rm -rf /opt/k3s/data/temp/*
#             fi
#             sync
#             echo -e "\n => reboot now to complete k3s cleanup!"
#             sleep 3
#             reboot
#           '')
#         ]
#         (lib.mkIf cfg.services.nvidia [
#           pkgs.nvtopPackages.nvidia
#           pkgs.nvidia-docker # Note, using docker here is a workaround, it will install nvidia-container-runtime and that will cause it to be accessible via /run/current-system/sw/bin/nvidia-container-runtime, currently its not directly accessible in nixpkgs.
#         ])
#       ];

#       etc = {
#         "rancher/k3s/kubelet.config" = {
#           mode = "0750";
#           text = ''
#             apiVersion: kubelet.config.k8s.io/v1beta1
#             kind: KubeletConfiguration
#             maxPods: 250
#           '';
#         };
#         "rancher/k3s/k3s.service.env" = {
#           mode = "0750";
#           text = ''
#             K3S_KUBECONFIG_MODE="644"
#           '';
#         };
#         "rancher/k3s/nvidia/config.toml.tmpl" = lib.mkIf cfg.services.nvidia {
#           mode = "0750";
#           text = ''
#             {{ template "base" . }}

#             [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
#               runtime_type = "io.containerd.runc.v2"

#             [plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
#               BinaryName = "/run/current-system/sw/bin/nvidia-container-runtime.cdi"
#           '';
#         };
#         "rancher/k3s/nvidia/nvidia-runtime.yaml" = lib.mkIf cfg.services.nvidia {
#           mode = "0750";
#           text = ''
#             apiVersion: node.k8s.io/v1
#             handler: nvidia
#             kind: RuntimeClass
#             metadata:
#               labels:
#                 app.kubernetes.io/component: gpu-operator
#               name: nvidia
#           '';
#         };
#       };
#     };

#     systemd.tmpfiles.rules = lib.mkMerge [
#       [
#         "d /root/.kube 0755 root root -"
#         "L /root/.kube/config  - - - - /etc/rancher/k3s/k3s.yaml"
#       ]
#       (lib.mkIf cfg.addons.nfs.enable [
#         "d ${cfg.addons.nfs.path} 0775 root root -"
#         "d ${cfg.addons.nfs.path}/pv 0775 root root -"
#       ])
#       (lib.mkIf cfg.services.nvidia [
#         "L /var/lib/rancher/k3s/server/manifests/nvidia-runtime.yaml - - - - /etc/rancher/k3s/nvidia/nvidia-runtime.yaml"
#         "L /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl - - - - /etc/rancher/k3s/nvidia/config.toml.tmpl"
#       ])
#     ];

#     boot.kernel.sysctl = {
#       "fs.inotify.max_user_instances" = 524288;
#       "fs.inotify.max_user_watches" = 524288;
#     };

#     networking.firewall = {
#       allowedTCPPorts = lib.mkMerge [
#         [
#           80 # http
#           222 # git ssh
#           443 # https
#           445 # samba
#           6443 # kubernetes api
#           8080 # reserved http
#           10250 # k3s metrics
#         ]
#         (lib.mkIf cfg.addons.nfs.enable [ 2049 ])
#         (lib.mkIf cfg.addons.minio.enable [ 9000 9001 ])
#         (lib.mkIf cfg.prepare.cilium [
#           4240 # health check
#           4244 # hubble server
#           4245 # hubble relay
#           9962 # agent prometheus metrics
#           9963 # operator prometheus metrics
#           9964 # envoy prometheus metrics
#         ])
#       ];
#       allowedUDPPorts = lib.mkMerge [
#         (lib.mkIf cfg.prepare.cilium [
#           8472 # VXLAN overlay
#         ])
#       ];
#       allowedTCPPortRanges = [
#         {
#           from = 2379;
#           to = 2380;
#         } # etcd
#       ];
#     };

#     services = {
#       prometheus.exporters.node = {
#         enable = true;
#       };
#       openiscsi = {
#         enable = true;
#         name = "iscsid";
#       };
#       nfs.server = lib.mkIf cfg.addons.nfs.enable {
#         enable = true;
#         exports = ''
#           ${cfg.addons.nfs.path} ${config.networking.hostName}(rw,fsid=0,async,no_subtree_check,no_auth_nlm,insecure,no_root_squash)
#         '';
#       };
#       minio = lib.mkIf cfg.addons.minio.enable {
#         enable = true;
#         region = cfg.addons.minio.region;
#         dataDir = cfg.addons.minio.dataDir;
#         rootCredentialsFile = cfg.addons.minio.credentialsFile;
#       };
#       k3s = {
#         enable = true;
#         role = "server";
#         environmentFile = "/etc/rancher/k3s/k3s.service.env";
#         extraFlags = lib.concatStringsSep " " k3sCombinedFlags;
#       };
#     };

#     systemd = {
#       services = {
#         k3s-delay = {
#           description = "Delay start of k3s";
#           wantedBy = [ "multi-user.target" ];
#           serviceConfig = {
#             Type = "oneshot";
#             RemainAfterExit = true;
#             ExecStart = "${pkgs.coreutils}/bin/true";
#           };
#         };
#         k3s = {
#           after = lib.mkMerge [
#            ["k3s.delay.service"]
#            (lib.mkIf cfg.addons.minio.enable [ "minio.service" ])
#            (lib.mkIf cfg.addons.nfs.enable [ "nfs-server.service" ])
#           ];
#           serviceConfig = {
#             TimeoutStartSec = (120 + cfg.delay);
#           };
#         };
#         minio-init = lib.mkIf cfg.addons.minio.enable {
#           enable = true;
#           path = [ pkgs.minio pkgs.minio-client];
#           requiredBy = [ "multi-user.target" ];
#           after = [ "minio.service" ];
#           serviceConfig = {
#             Type = "simple";
#             User = "minio";
#             Group = "minio";
#             RuntimeDirectory = "minio-config";
#           };
#           script = ''
#             set -e
#             sleep 5
#             source ${cfg.addons.minio.credentialsFile}
#             mc --config-dir "$RUNTIME_DIRECTORY" alias set minio http://localhost:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
#             ${toString (lib.lists.forEach cfg.addons.minio.buckets (bucket: "mc --config-dir $RUNTIME_DIRECTORY mb --ignore-existing minio/${bucket};"))}
#           '';
#         };
#       };
#       timers.k3s-delay = {
#         wantedBy = ["timers.target"];
#         timerConfig = {
#           OnBootSec = "${toString cfg.delay}s";
#           Unit = "k3s-delay.service";
#         };
#       };
#       timers."k3s-helm-bootstrap" = lib.mkIf cfg.bootstrap.helm.enable {
#         wantedBy = [ "timers.target" ];
#         timerConfig = {
#           OnBootSec = "3m";
#           OnUnitActiveSec = "3m";
#           Unit = "k3s-helm-bootstrap.service";
#         };
#       };
#       timers."k3s-flux2-bootstrap" = lib.mkIf cfg.services.flux {
#         wantedBy = [ "timers.target" ];
#         timerConfig = {
#           OnBootSec = "3m";
#           OnUnitActiveSec = "3m";
#           Unit = "k3s-flux2-bootstrap.service";
#         };
#       };
#     };

#     systemd.services."k3s-helm-bootstrap" = lib.mkIf cfg.bootstrap.helm.enable {
#       script = ''
#         export PATH="$PATH:${pkgs.git}/bin:${pkgs.kubernetes-helm}/bin"
#         if ${pkgs.kubectl}/bin/kubectl ${cfg.bootstrap.helm.completedIf} ; then
#           exit 0
#         fi
#         sleep 30
#         if ${pkgs.kubectl}/bin/kubectl ${cfg.bootstrap.helm.completedIf} ; then
#           exit 0
#         fi
#         ${pkgs.helmfile}/bin/helmfile --quiet --file ${cfg.bootstrap.helm.helmfile} apply --skip-diff-on-install --suppress-diff
#       '';
#       after = [ "k3s.service" ];
#       serviceConfig = {
#         Type = "oneshot";
#         User = "root";
#         RestartSec = "3m";
#       };
#     };

#     systemd.services."k3s-flux2-bootstrap" = lib.mkIf cfg.services.flux {
#       script = ''
#         export PATH="$PATH:${pkgs.git}/bin"
#         if ${pkgs.kubectl}/bin/kubectl get CustomResourceDefinition -A | grep -q "toolkit.fluxcd.io" ; then
#           exit 0
#         fi
#         sleep 30
#         if ${pkgs.kubectl}/bin/kubectl get CustomResourceDefinition -A | grep -q "toolkit.fluxcd.io" ; then
#           exit 0
#         fi
#         mkdir -p /tmp/k3s-flux2-bootstrap
#         cat > /tmp/k3s-flux2-bootstrap/kustomization.yaml << EOL
#         apiVersion: kustomize.config.k8s.io/v1beta1
#         kind: Kustomization
#         resources:
#           - github.com/fluxcd/flux2/manifests/install
#         patches:
#           # Remove the default network policies
#           - patch: |-
#               \$patch: delete
#               apiVersion: networking.k8s.io/v1
#               kind: NetworkPolicy
#               metadata:
#                 name: not-used
#             target:
#               group: networking.k8s.io
#               kind: NetworkPolicy
#         EOL
#         ${pkgs.kubectl}/bin/kubectl apply --kustomize /tmp/k3s-flux2-bootstrap
#       '';
#       after = [ "k3s.service" ];
#       serviceConfig = {
#         Type = "oneshot";
#         User = "root";
#         RestartSec = "3m";
#       };
#     };
#   };
# }
