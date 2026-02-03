# Bootstrap:
# helm repo add argo https://argoproj.github.io/argo-helm
# helm repo update
# kubectl create namespace argocd
# kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# nixidy bootstrap .#prod | kubectl apply -f -
{
  imports = [
    ../../modules/argocd.nix
    ../../modules/cilium.nix
    # ../../modules/sops-secrets-operator.nix
  ];
}
