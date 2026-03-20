- `kubernetes`: Global Kubernetes configuration

- `kubernetes.services`: Kubernetes service definitions with their nixidy
  modules

- `kubernetes.services.<name>.crds`: \
  CRD generator configuration function for this service.

  Should be a function that receives perSystem module args ({ pkgs, lib, inputs,
  system, ... }) and returns an attribute set with CRD configuration.

  Two patterns are supported:
  - fromCRD: Return { src, crds } to manually specify CRD files
  - fromChartCRD: Return { chart } or { chartAttrs } to auto-discover CRDs from
    a helm chart

  Example (fromCRD):

  ```nix
  crds = { pkgs, lib, ... }: {
    src = pkgs.fetchFromGitHub { ... };
    crds = [ "path/to/crd.yaml" ];
  };
  ```

  Example (fromChartCRD):

  ```nix
  crds = { inputs, system, ... }: {
    chart = inputs.nixhelm.chartsDerivations.${system}.traefik.traefik;
  };
  ```

  Available options in the returned attrset:
  - src: Source package with CRD YAML files (for fromCRD)
  - chart: Helm chart derivation (for fromChartCRD)
  - chartAttrs: Attributes for downloadHelmChart (for fromChartCRD)
  - values: Helm values for chart rendering (for fromChartCRD)
  - crds: List of CRD file paths (fromCRD) or kind names (fromChartCRD)
  - namePrefix: Prefix for generated type names
  - attrNameOverrides: Custom attribute name mappings
  - skipCoerceToList: Control list coercion behavior

- `kubernetes.services.<name>.excludes`: [list of string] List of names of
  services to exclude from this service

- `kubernetes.services.<name>.nixidy`: [module] A nixidy module for this
  Kubernetes service

- `kubernetes.services.<name>.options`: \
  Option declarations for environment-level configuration of this service. These
  options will be available at kubernetes.services.<name> in environment
  configs. Should contain ONLY option declarations, no config assignments.

- `kubernetes.services.<name>.requires`: [list of string] List of names of
  services required by this service

- `kubernetes.tlsSanIps`: [list of string] Additional IPs to include in
  Kubernetes API server TLS certificate SANs
