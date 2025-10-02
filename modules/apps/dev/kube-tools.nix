{

  flake.features.kube-tools.home =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        lens
        cilium-cli

        # --- Containers ---
        fetchit # A tool to manage the life cycle and configuration of Podman containers
        #podman-desktop # A graphical tool for developing on containers and Kubernetes

        # --- Helm ---
        helmfile # Declarative spec for deploying Helm charts
        helm-ls # Language server for Helm
        helmsman # Helm Charts (k8s applications) as Code tool

        # --- Kubernetes ---
        kubecfg # A tool for managing Kubernetes resources as code
        kubectl # Kubernetes CLI

        # --- Security ---
        hubble # Network, Service & Security Observability for Kubernetes using eBPF
        kdigger # An in-pod context discovery tool for Kubernetes penetration testing
        kube-bench # Checks whether Kubernetes is deployed according to security best practices as defined in the CIS Kubernetes Benchmark
        kube-score # Kubernetes object analysis with recommendations for improved reliability and Security
        kubeaudit # Audit tool for kubernetes
        nova # Find outdated or deprecated Helm charts running in your cluster
        pinniped # Tool to securely log in to your Kubernetes clusters
        kubeclarity # Kubernetes runtime scanner

        #kubepub # Check cluster for objects using deprecated API versions
        kubesec # Security risk analysis tool for Kubernetes resources
        #kubevpn # Create VPN & connect to Kubernetes cluster network, access resources, & more
        kubexit # Command supervisor for coordinated Kubernetes pod container termination.
        stern # Multi pod and container log tailing for Kubernetes
        kubernetes-polaris # Validate and remediate Kubernetes resources to ensure configuration best practices are followed
        kubescape # Tool for testing if Kubernetes is deployed securely
        kubeseal # A Kubernetes controller and tool for one-way encrypted Secrets

        # Cluster Admin
        clusterctl # Kubernetes cluster API tool
        cmctl # A CLI tool for managing cert-manager service on Kubernetes clusters
        cri-tools # CLI and validation tools for Kubelet Container Runtime Interface (CRI)
        #ctlpl # CLI for declaratively setting up local Kubernetes clusters
        karmor # A client tool to help manage KubeArmor
        kubernetes-controller-tools # Tools to use with the Kubernetes controller-runtime libraries
        kubernix
        kubestroyer # Kubernetes exploitation tool
        starboard # Kubernetes-native security tool kit

        #Single dependency Kubernetes clusters for local testing, experimenting and development

        # Developing on Kubernetes
        devspace # DevSpace is an open-source developer tool for Kubernetes that lets you develop and deploy cloud-native software faster
        #k3d # helper to run k3s (Lightweight Kubernetes. 5 less than k8s) in a docker container
        #k3s # Lightweight k8s distribution
        kail # Kubernetes log viewer
        kubectl-evict-pod # This plugin evicts the given pod and is useful for testing pod disruption budget rules
        kubectl-example # kubectl plugin for retrieving resource example YAMLs
        kubectl-images
        tilt # Local development tool to manage your developer instance when your team deploys to Kubernetes in production # Show container images used in the cluster.

        # Linting & Validation
        datree # CLI tool to ensure K8s manifests and Helm charts follow best practices
        kubeval # Validate your Kubernetes configuration files
        kubectl-doctor # kubectl cluster triage plugin for k8s

        # Configs
        k2tf # Kubernetes YAML to Terraform HCL converter
        kubectl-convert
        kubectl
        kubemqctl # Kubemqctl is a command line interface (CLI) for Kubemq Kubernetes Message Broker.
        kubeone # Automate cluster operations on all your cloud, on-prem, edge, and IoT environments

        # CLI Utils
        k8sgpt # Giving Kubernetes Superpowers to everyone
        kconf # An opinionated command line tool for managing multiple kubeconfigs
        kubergrunt # Collection of commands to fill in the gaps between Terraform, Helm, and Kubectl

        # TUI & REPLs
        click # The "Command Line Interactive Controller for Kubernetes" (REPL)
        k9s # Kubernetes CLI To Manage Your Clusters In Style
        kdash # A simple and fast dashboard for Kubernetes
        kubectl-explore # A better kubectl explain with the fuzzy finder
        kubernetes-code-generator # Kubernetes code generation

        # Desktop Tools
        #gnomeExtensions.kube-config # Switches kube config context
        #gnomeExtensions.kubectl-extension # Quick panel access to kubernetes resources utilizing kubectl CLI

        # --- Distributions ---
        #rke # An extremely simple, lightning fast Kubernetes distribution that runs entirey within containers
        #rke2 # RKE2, also known as RKE Government, is Rancher's next-generation Kubernetes distribution.

        # --- Plugins ---
        kubectl-klock # A kubectl plugin to render watch output in a more readable fashion
        kubernetes-helm
        kubernetes-helmPlugins.helm-cm-push
        kubernetes-helmPlugins.helm-diff
        kubernetes-helmPlugins.helm-s3
        kubernetes-helmPlugins.helm-git # The Helm downloader plugin that provides GIT protocol support
        kubernetes-helmPlugins.helm-secrets # A Helm plugin that helps manage secrets
        terrascan # Detect compliance and security violations across Infrastructure
        #BDD styled unit test framework for Kubernetes Helm charts as a Helm plugin
        rakkess # Review Access - kubectl plugin to show an access matrix for k8s server resources

        # --- MISC ---
        kfilt # Command-line tool that filters Kubernetes resources
        kind # Kubernetes IN Docker - local clusters for testing kubernetes
        kluctl # The missing glue to put together large Kubernetes deployments
        kns # Kubernetes namespace switcher
        kompose # A tool to help users who are familiar with docker-compose move to Kubernetes
        konf # Lightweight and blazing fast kubeconfig manager which allows to use different kubeconfigs at the same time
        kontemplate # Extremely simple Kubernetes resource templates
        kops # Easiest way to get a production Kubernetes up and running
        kpt # A toolkit to help you manage, manipulate, customize, and apply Kubernetes Resource configuration data files
        krane # A command-line tool that helps you ship changes to a Kubernetes namespace and understand the result
        krelay # A better alternative to `kubectl port-forward` that can forward TCP or UDP traffic to IP/Host which is accessible inside the cluster.
        krew # Package manager for kubectl plugins
        ktop # A top-like tool for your Kubernetes cluster
        kubectl-node-shell # Exec into node via kubectl
        kubectl-tree # kubectl plugin to browse Kubernetes object hierarchies as a tree
        kubectl-view-allocations # kubectl plugin to list allocations (cpu, memory, gpu,... X utilization, requested, limit, allocatable,...)
        kubectl-view-secret # Kubernetes CLI plugin to decode Kubernetes secrets
        kubectx # Fast way to switch between clusters and namespaces in kubectl!
        kubelogin # A Kubernetes credential plugin implementing Azure authentication
        kubelogin-oidc # A Kubernetes credential plugin implementing OpenID Connect (OIDC) authentication
        kubeswitch # The kubectx for operators
        kubetail # Bash script to tail Kubernetes logs from multiple pods at the same time
        kubevirt # Client tool to use advanced features such as console access
        kustomize-sops # A Flexible Kustomize Plugin for SOPS Encrypted Resource
        kyverno # Kubernetes Native Policy Management
        #openlens # The Kubernetes IDE
        pgo-client # A CLI client for Crunchy PostgreSQL Kubernetes Operator
        popeye # A Kubernetes cluster resource sanitizer
        pv-migrate # CLI tool to easily migrate Kubernetes persistent volumes
        skaffold # Easy and Repeatable Kubernetes Development
        talosctl # A CLI for out-of-band management of Kubernetes nodes created by Talos

        minikube # A tool that makes it easy to run Kubernetes locally
        netassert # A command line utility to test network connectivity between kubernetes objects

        ktunnel # A cli that exposes your local resources to kubernetes
        kube-capacity # A simple CLI that provides an overview of the resource requests, limits, and utilization in a Kubernetes cluster
        #kube-hunter # Tool to search issues in Kubernetes clusters
        kube-linter # A static analysis tool that checks Kubernetes YAML files and Helm charts
        kube-prompt # An interactive kubernetes client featuring auto-complete
        kube-router # All-in-one router, firewall and service proxy for Kubernetes
        kubecm # Manage your kubeconfig more easily
        kubecolor # Colorizes kubectl output
        kubeconform # A FAST Kubernetes manifests validator, with support for Custom Resources!
        kubeshark # The API Traffic Viewer for Kuberneteskubespy
        kubespy # A tool to observe Kubernetes resources in real time
        timoni # A package manager for Kubernetes, powered by CUE and inspired by Helm

        # --- Non-K8s ---
        # shellz # Utility to manage your SSH, telnet, kubernetes, winrm, web or any custom shell
        # teleport # Certificate authority and access plane for SSH, Kubernetes, web applications, and databases
      ];
    };
}
