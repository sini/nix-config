## flake\.kubernetes

Global Kubernetes configuration



*Type:*
submodule



## flake\.kubernetes\.clusterCidr



Kubernetes pod network CIDR



*Type:*
string



## flake\.kubernetes\.kubeAPIVIP



Kubernetes API VIP



*Type:*
string



## flake\.kubernetes\.loadBalancer



LoadBalancer configuration



*Type:*
submodule



## flake\.kubernetes\.loadBalancer\.cidr



IP range for LoadBalancer services



*Type:*
string



## flake\.kubernetes\.loadBalancer\.reservations



Reserved IP addresses for specific LoadBalancer services



*Type:*
attribute set of string



## flake\.kubernetes\.serviceCidr



Kubernetes service network CIDR



*Type:*
string



## flake\.kubernetes\.services



Kubernetes service definitions with their nixidy modules



*Type:*
lazy attribute set of (submodule)



## flake\.kubernetes\.services\.\<name>\.crds



CRD generator configuration function for this service\.

Should be a function that receives perSystem module args ({ pkgs, lib, inputs, system, … })
and returns an attribute set with CRD configuration\.

Two patterns are supported:

 - fromCRD: Return { src, crds } to manually specify CRD files
 - fromChartCRD: Return { chart } or { chartAttrs } to auto-discover CRDs from a helm chart

Example (fromCRD):
crds = { pkgs, lib, … }: {
src = pkgs\.fetchFromGitHub { … };
crds = \[ “path/to/crd\.yaml” ];
};

Example (fromChartCRD):
crds = { inputs, system, … }: {
chart = inputs\.nixhelm\.chartsDerivations\.${system}\.traefik\.traefik;
};

Available options in the returned attrset:

 - src: Source package with CRD YAML files (for fromCRD)
 - chart: Helm chart derivation (for fromChartCRD)
 - chartAttrs: Attributes for downloadHelmChart (for fromChartCRD)
 - values: Helm values for chart rendering (for fromChartCRD)
 - crds: List of CRD file paths (fromCRD) or kind names (fromChartCRD)
 - namePrefix: Prefix for generated type names
 - attrNameOverrides: Custom attribute name mappings
 - skipCoerceToList: Control list coercion behavior



*Type:*
null or raw value



## flake\.kubernetes\.services\.\<name>\.excludes



List of names of services to exclude from this service



*Type:*
list of string



## flake\.kubernetes\.services\.\<name>\.nixidy



A nixidy module for this Kubernetes service



*Type:*
module



## flake\.kubernetes\.services\.\<name>\.options



Option declarations for environment-level configuration of this service\.
These options will be available at kubernetes\.services\.\<name> in environment configs\.
Should contain ONLY option declarations, no config assignments\.



*Type:*
lazy attribute set of raw value



## flake\.kubernetes\.services\.\<name>\.requires



List of names of services required by this service



*Type:*
list of string



## flake\.kubernetes\.tlsSanIps



Additional IPs to include in Kubernetes API server TLS certificate SANs



*Type:*
list of string


