## flake\.environments

Environment configurations



*Type:*
attribute set of (submodule)



## flake\.environments\.\<name>\.acme



ACME certificate authority configuration



*Type:*
submodule



## flake\.environments\.\<name>\.acme\.dnsProvider



DNS provider for ACME challenges



*Type:*
string



## flake\.environments\.\<name>\.acme\.dnsResolver



DNS resolver for ACME validation



*Type:*
string



## flake\.environments\.\<name>\.acme\.server



ACME server URL



*Type:*
string



## flake\.environments\.\<name>\.delegation



Cross-environment delegation configuration



*Type:*
submodule



## flake\.environments\.\<name>\.delegation\.authTo



Environment to delegate authentication to (e\.g\., ‘prod’)



*Type:*
null or string



## flake\.environments\.\<name>\.delegation\.logsTo



Environment to delegate log shipping to (e\.g\., ‘prod’)



*Type:*
null or string



## flake\.environments\.\<name>\.delegation\.metricsTo



Environment to delegate metrics reporting to (e\.g\., ‘prod’)



*Type:*
null or string



## flake\.environments\.\<name>\.dnsServers



DNS server IPs for the environment



*Type:*
list of string



## flake\.environments\.\<name>\.domain



Base domain for the environment



*Type:*
string



## flake\.environments\.\<name>\.email



Email configuration for the environment



*Type:*
submodule



## flake\.environments\.\<name>\.email\.adminEmail



Default admin email address



*Type:*
string



## flake\.environments\.\<name>\.email\.domain



Email domain (e\.g\., json64\.dev)



*Type:*
string



## flake\.environments\.\<name>\.gatewayIp



Gateway IP address for the environment



*Type:*
string



## flake\.environments\.\<name>\.gatewayIpV6



Gateway IPv6 address for the environment



*Type:*
string



## flake\.environments\.\<name>\.id



ID of the environment



*Type:*
signed integer



## flake\.environments\.\<name>\.ipv6



IPv6 ULA and prefix configuration for NPTv6 translation



*Type:*
submodule



## flake\.environments\.\<name>\.ipv6\.external_prefix



External ISP prefix for NPTv6 translation (e\.g\., 2001:db8::/64)



*Type:*
null or string



## flake\.environments\.\<name>\.ipv6\.kubernetes_prefix



IPv6 prefix for Kubernetes pods (e\.g\., fd64:0:2::/64)



*Type:*
null or string



## flake\.environments\.\<name>\.ipv6\.management_prefix



IPv6 prefix for management network (e\.g\., fd64:0:1::/64)



*Type:*
null or string



## flake\.environments\.\<name>\.ipv6\.services_prefix



IPv6 prefix for Kubernetes services (e\.g\., fd64:0:3::/64)



*Type:*
null or string



## flake\.environments\.\<name>\.ipv6\.ula_prefix



ULA prefix for the environment (e\.g\., fd64::/48)



*Type:*
null or string



## flake\.environments\.\<name>\.kubernetes



Kubernetes-specific network configuration



*Type:*
submodule



## flake\.environments\.\<name>\.kubernetes\.clusterCidr



Kubernetes pod network CIDR



*Type:*
string



## flake\.environments\.\<name>\.kubernetes\.kubeAPIVIP



Kubernetes API VIP



*Type:*
string



## flake\.environments\.\<name>\.kubernetes\.loadBalancer



LoadBalancer configuration



*Type:*
submodule



## flake\.environments\.\<name>\.kubernetes\.loadBalancer\.cidr



IP range for LoadBalancer services



*Type:*
string



## flake\.environments\.\<name>\.kubernetes\.loadBalancer\.reservations



Reserved IP addresses for specific LoadBalancer services



*Type:*
attribute set of string



## flake\.environments\.\<name>\.kubernetes\.secretsFile



Path to sops encrypted secret file for kubernetes environment



*Type:*
null or absolute path



## flake\.environments\.\<name>\.kubernetes\.serviceCidr



Kubernetes service network CIDR



*Type:*
string



## flake\.environments\.\<name>\.kubernetes\.services



Kubernetes service management for this environment\.
Use ‘enabled’ to enable services and ‘config’ for service-specific options\.



*Type:*
submodule



## flake\.environments\.\<name>\.kubernetes\.services\.enabled



List of enabled services for this environment\.
Services without configuration can be enabled by simply adding them to this list\.



*Type:*
list of string



## flake\.environments\.\<name>\.kubernetes\.services\.config



Service-specific configurations for this environment\.
Options are imported from flake\.kubernetes\.services\.\<name>\.options\.



*Type:*
submodule



## flake\.environments\.\<name>\.kubernetes\.services\.config\.argocd



Configuration for argocd service



*Type:*
attribute set



## flake\.environments\.\<name>\.kubernetes\.services\.config\.bootstrap



Configuration for bootstrap service



*Type:*
attribute set



## flake\.environments\.\<name>\.kubernetes\.services\.config\.cert-manager



Configuration for cert-manager service



*Type:*
attribute set



## flake\.environments\.\<name>\.kubernetes\.services\.config\.cilium



Configuration for cilium service



*Type:*
submodule



## flake\.environments\.\<name>\.kubernetes\.services\.config\.cilium\.devices



List of devices



*Type:*
null or (list of string)



## flake\.environments\.\<name>\.kubernetes\.services\.config\.cilium\.directRoutingDevice



Default routing device



*Type:*
null or string



## flake\.environments\.\<name>\.kubernetes\.services\.config\.cilium-bgp



Configuration for cilium-bgp service



*Type:*
attribute set



## flake\.environments\.\<name>\.kubernetes\.services\.config\.envoy-gateway



Configuration for envoy-gateway service



*Type:*
attribute set



## flake\.environments\.\<name>\.kubernetes\.services\.config\.gateway-api



Configuration for gateway-api service



*Type:*
attribute set



## flake\.environments\.\<name>\.kubernetes\.services\.config\.hubble-ui



Configuration for hubble-ui service



*Type:*
attribute set



## flake\.environments\.\<name>\.kubernetes\.services\.config\.romm



Configuration for romm service



*Type:*
attribute set



## flake\.environments\.\<name>\.kubernetes\.services\.config\.sops-secrets-operator



Configuration for sops-secrets-operator service



*Type:*
submodule



## flake\.environments\.\<name>\.kubernetes\.services\.config\.sops-secrets-operator\.replicaCount



Number of replicas for the sops-secrets-operator



*Type:*
signed integer



## flake\.environments\.\<name>\.kubernetes\.sso



Single Sign-On configuration



*Type:*
submodule



## flake\.environments\.\<name>\.kubernetes\.sso\.credentialsEnvironment



Environment variable name containing SSO credentials



*Type:*
null or string



## flake\.environments\.\<name>\.kubernetes\.sso\.issuerPattern



SSO issuer URL pattern for authentication\.
Use {clientID} as a placeholder for the client ID\.
Example: “https://idm\.example\.com/oauth2/openid/{clientID}”



*Type:*
null or string



## flake\.environments\.\<name>\.kubernetes\.tlsSanIps



Additional IPs to include in Kubernetes API server TLS certificate SANs



*Type:*
list of string



## flake\.environments\.\<name>\.location



Geographic location information



*Type:*
submodule



## flake\.environments\.\<name>\.location\.country



ISO country code



*Type:*
string



## flake\.environments\.\<name>\.location\.region



Geographic region or datacenter



*Type:*
string



## flake\.environments\.\<name>\.monitoring



Monitoring configuration including cross-environment scanning



*Type:*
submodule



## flake\.environments\.\<name>\.monitoring\.scanEnvironments



Additional environments to scan for metrics (e\.g\., \[‘dev’] for prod scanning dev)



*Type:*
list of string



## flake\.environments\.\<name>\.name



Human-readable environment name



*Type:*
string *(read only)*



## flake\.environments\.\<name>\.networks



Network definitions for the environment\.
Example: ` {   management = { cidr = "10.0.0.0/24"; purpose = "management"; };   cluster = { cidr = "172.20.0.0/16"; purpose = "kubernetes-pods"; }; } `



*Type:*
attribute set of (submodule)



## flake\.environments\.\<name>\.networks\.\<name>\.cidr



Network CIDR (e\.g\., 10\.0\.0\.0/24)



*Type:*
string



## flake\.environments\.\<name>\.networks\.\<name>\.description



Human-readable description of the network



*Type:*
string



## flake\.environments\.\<name>\.networks\.\<name>\.ipv6_cidr



IPv6 network CIDR (e\.g\., fd64:0:1::/64)



*Type:*
null or string



## flake\.environments\.\<name>\.networks\.\<name>\.purpose



Network purpose (e\.g\., management, cluster, service)



*Type:*
string



## flake\.environments\.\<name>\.tags



Environment-wide tags for metadata and organization



*Type:*
attribute set of string



## flake\.environments\.\<name>\.timezone



Default timezone for the environment



*Type:*
string



## flake\.environments\.\<name>\.users



Users in this environment with their features and configuration



*Type:*
lazy attribute set of (submodule)



## flake\.environments\.\<name>\.users\.\<name>\.configuration



User-specific home configuration



*Type:*
module



## flake\.environments\.\<name>\.users\.\<name>\.features



List of features specific to the user\.

While a feature may specify NixOS modules in addition to home
modules, only home modules will affect configuration\.  For this
reason, users should be encouraged to avoid pointlessly specifying
their own NixOS modules\.



*Type:*
list of string


