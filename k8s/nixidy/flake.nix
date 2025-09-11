{
  description = "Kubernetes manifests via nixidy";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixidy = {
      url = "github:arnarg/nixidy";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      nixpkgs,
      nixidy,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      packages.${system} = nixidy.lib.mkEnvs {
        inherit pkgs;
        envs = {
          # Dev environment configuration
          dev = {
            nixidy.target = {
              repository = "https://github.com/your-org/nix-config.git"; # TODO: Replace with actual repo URL
              branch = "main";
              rootPath = "./k8s/nixidy/manifests/dev";
            };

            # Import application configurations
            imports = [
              ./environments/dev
            ];
          };
        };
      };

      # Development shell with nixidy tools
      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          nixidy.packages.${system}.default
          kubectl
          kubernetes-helm
          kustomize
        ];
      };
    };
}
