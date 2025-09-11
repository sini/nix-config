{
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
    ./monitoring.nix
    ./ingress.nix
    ./storage.nix
  ];
}
