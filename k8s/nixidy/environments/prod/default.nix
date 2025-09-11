{
  # Target repository configuration for this environment
  nixidy.target = {
    repository = "https://github.com/sini/nix-config";
    branch = "main";
    rootPath = "./k8s/nixidy/manifests/prod";
  };

  # Core application namespaces
  applications.namespaces = {
    namespace = "default"; # Not used, but required
    resources = {
      namespaces = {
        monitoring = { };
        ingress = { };
        storage = { };
        auth = { };
        applications = { };
      };
    };
  };

  # Include application modules
  imports = [
    ./test.nix
    # ./monitoring.nix
    # ./ingress.nix
    # ./storage.nix
  ];
}
