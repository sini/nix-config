{ self, ... }:
{
  text.readme.parts.flake-options =
    # markdown
    ''
      ## Flake Options

      This repository defines configuration options in the following attribute sets:

      - **[environments](docs/environments-options.md)**: Environment settings including network and infrastructure configuration that can be shared across hosts. Each environment contains topology definitions for domains, networks, Kubernetes clusters, and ACME settings.

      - **[hosts](docs/hosts-options.md)**: Host definitions for individual machines. Each host configuration includes system architecture, IP addresses, roles, hardware settings, and deployment configuration for Colmena/deploy-rs.

      - **[kubernetes](docs/kubernetes-options.md)**: Kubernetes cluster configuration options for k3s deployments.

      - **[users](docs/users-options.md)**: User account definitions and configuration options.

      See the linked documentation files for complete option references.
    '';
  perSystem =
    { pkgs, lib, ... }:
    {

      files.files =
        let
          mkOptionDoc = name: options: {
            path_ = "docs/${name}-options.md";
            drv =
              let
                doc = pkgs.nixosOptionsDoc {
                  inherit options;
                  warningsAreErrors = false;
                  transformOptions =
                    opt:
                    opt
                    // {
                      default = null;
                      declarations = [ ]; # Keeps the output cleaner for READMEs
                      # Optional: Hide the type if it's just 'submodule' to save space
                      type = if opt.type == "submodule" then null else opt.type;
                      visible = opt.description != null; # && !(opt.type == "submodule");
                    };
                };
              in
              pkgs.runCommand "${name}-options.md" { buildInputs = [ pkgs.jq ]; } ''
                jq -r 'to_entries | map(
                  .value.isMultiline = (.value.description | contains("\n")) |
                  if (.value.type == null or (.value.type | tostring | contains("submodule")) or (.value.type | tostring | contains("raw"))) then
                    if .value.isMultiline then
                      "* `\(.key)`: \\\n  \(.value.description | gsub("\n"; "\n  "))"
                    else
                      "* `\(.key)`: \(.value.description)"
                    end
                  else
                    if .value.isMultiline then
                      "* `\(.key)`: [\(.value.type)] \\\n  \(.value.description | gsub("\n"; "\n  "))"
                    else
                      "* `\(.key)`: [\(.value.type)] \(.value.description)"
                    end
                  end
                ) | join("\n\n")' \
                  ${doc.optionsJSON}/share/doc/nixos/options.json > $out
              '';
          };
        in
        lib.mapAttrsToList mkOptionDoc self.flakeOptions;
    };
}
