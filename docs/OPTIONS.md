## flake\.environments

Environment configurations



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.acme



ACME certificate authority configuration



*Type:*
submodule



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.acme\.dnsProvider



DNS provider for ACME challenges



*Type:*
string



*Default:*

```nix
"cloudflare"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.acme\.dnsResolver



DNS resolver for ACME validation



*Type:*
string



*Default:*

```nix
"1.1.1.1:53"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.acme\.server



ACME server URL



*Type:*
string



*Default:*

```nix
"https://acme-v02.api.letsencrypt.org/directory"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.delegation



Cross-environment delegation configuration



*Type:*
submodule



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.delegation\.authTo



Environment to delegate authentication to (e\.g\., ‘prod’)



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.delegation\.logsTo



Environment to delegate log shipping to (e\.g\., ‘prod’)



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.delegation\.metricsTo



Environment to delegate metrics reporting to (e\.g\., ‘prod’)



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.dnsServers



DNS server IPs for the environment



*Type:*
list of string



*Default:*

```nix
[
  "1.1.1.1"
  "8.8.8.8"
]
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.domain



Base domain for the environment



*Type:*
string

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.email



Email configuration for the environment



*Type:*
submodule

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.email\.adminEmail



Default admin email address



*Type:*
string

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.email\.domain



Email domain (e\.g\., json64\.dev)



*Type:*
string

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.gatewayIp



Gateway IP address for the environment



*Type:*
string

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.gatewayIpV6



Gateway IPv6 address for the environment



*Type:*
string

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.id



ID of the environment



*Type:*
signed integer



*Default:*

```nix
1
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.ipv6



IPv6 ULA and prefix configuration for NPTv6 translation



*Type:*
submodule



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.ipv6\.external_prefix



External ISP prefix for NPTv6 translation (e\.g\., 2001:db8::/64)



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.ipv6\.kubernetes_prefix



IPv6 prefix for Kubernetes pods (e\.g\., fd64:0:2::/64)



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.ipv6\.management_prefix



IPv6 prefix for management network (e\.g\., fd64:0:1::/64)



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.ipv6\.services_prefix



IPv6 prefix for Kubernetes services (e\.g\., fd64:0:3::/64)



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.ipv6\.ula_prefix



ULA prefix for the environment (e\.g\., fd64::/48)



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes



Kubernetes-specific network configuration



*Type:*
submodule



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.clusterCidr



Kubernetes pod network CIDR



*Type:*
string



*Default:*

```nix
"172.20.0.0/16"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.kubeAPIVIP



Kubernetes API VIP



*Type:*
string



*Default:*

```nix
"10.10.10.100"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.loadBalancer



LoadBalancer configuration



*Type:*
submodule



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.loadBalancer\.cidr



IP range for LoadBalancer services



*Type:*
string



*Default:*

```nix
"10.0.100.0/24"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.loadBalancer\.reservations



Reserved IP addresses for specific LoadBalancer services



*Type:*
attribute set of string



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.secretsFile



Path to sops encrypted secret file for kubernetes environment



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.serviceCidr



Kubernetes service network CIDR



*Type:*
string



*Default:*

```nix
"172.21.0.0/16"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.services



Kubernetes service management for this environment\.
Use ‘enabled’ to enable services and ‘config’ for service-specific options\.



*Type:*
submodule



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.services\.enabled



List of enabled services for this environment\.
Services without configuration can be enabled by simply adding them to this list\.



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.services\.config



Service-specific configurations for this environment\.
Options are imported from flake\.kubernetes\.services\.\<name>\.options\.



*Type:*
submodule



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.services\.config\.argocd



Configuration for argocd service



*Type:*
attribute set



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.services\.config\.bootstrap



Configuration for bootstrap service



*Type:*
attribute set



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.services\.config\.cert-manager



Configuration for cert-manager service



*Type:*
attribute set



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.services\.config\.cilium



Configuration for cilium service



*Type:*
submodule



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.services\.config\.cilium\.devices



List of devices



*Type:*
null or (list of string)



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.services\.config\.cilium\.directRoutingDevice



Default routing device



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.services\.config\.cilium-bgp



Configuration for cilium-bgp service



*Type:*
attribute set



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.services\.config\.envoy-gateway



Configuration for envoy-gateway service



*Type:*
attribute set



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.services\.config\.gateway-api



Configuration for gateway-api service



*Type:*
attribute set



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.services\.config\.hubble-ui



Configuration for hubble-ui service



*Type:*
attribute set



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.services\.config\.romm



Configuration for romm service



*Type:*
attribute set



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.services\.config\.sops-secrets-operator



Configuration for sops-secrets-operator service



*Type:*
submodule



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.services\.config\.sops-secrets-operator\.replicaCount



Number of replicas for the sops-secrets-operator



*Type:*
signed integer



*Default:*

```nix
1
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.sso



Single Sign-On configuration



*Type:*
submodule



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.sso\.credentialsEnvironment



Environment variable name containing SSO credentials



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.sso\.issuerPattern



SSO issuer URL pattern for authentication\.
Use {clientID} as a placeholder for the client ID\.
Example: “https://idm\.example\.com/oauth2/openid/{clientID}”



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.kubernetes\.tlsSanIps



Additional IPs to include in Kubernetes API server TLS certificate SANs



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.location



Geographic location information



*Type:*
submodule



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.location\.country



ISO country code



*Type:*
string



*Default:*

```nix
"US"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.location\.region



Geographic region or datacenter



*Type:*
string



*Default:*

```nix
""
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.monitoring



Monitoring configuration including cross-environment scanning



*Type:*
submodule



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.monitoring\.scanEnvironments



Additional environments to scan for metrics (e\.g\., \[‘dev’] for prod scanning dev)



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.name



Human-readable environment name



*Type:*
string *(read only)*



*Default:*

```nix
"‹name›"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.networks



Network definitions for the environment\.
Example: ` {   management = { cidr = "10.0.0.0/24"; purpose = "management"; };   cluster = { cidr = "172.20.0.0/16"; purpose = "kubernetes-pods"; }; } `



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.networks\.\<name>\.cidr



Network CIDR (e\.g\., 10\.0\.0\.0/24)



*Type:*
string

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.networks\.\<name>\.description



Human-readable description of the network



*Type:*
string



*Default:*

```nix
""
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.networks\.\<name>\.ipv6_cidr



IPv6 network CIDR (e\.g\., fd64:0:1::/64)



*Type:*
null or string



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.networks\.\<name>\.purpose



Network purpose (e\.g\., management, cluster, service)



*Type:*
string

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.tags



Environment-wide tags for metadata and organization



*Type:*
attribute set of string



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.timezone



Default timezone for the environment



*Type:*
string



*Default:*

```nix
"UTC"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.users



Users in this environment with their features and configuration



*Type:*
lazy attribute set of (submodule)



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.users\.\<name>\.configuration



User-specific home configuration



*Type:*
module



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.environments\.\<name>\.users\.\<name>\.features



List of features specific to the user\.

While a feature may specify NixOS modules in addition to home
modules, only home modules will affect configuration\.  For this
reason, users should be encouraged to avoid pointlessly specifying
their own NixOS modules\.



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/environment-options.nix)



## flake\.hosts



This option has no description\.



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.baseline



Baseline configurations for repeatable configuration types on this host



*Type:*
submodule



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.baseline\.home



Host-specific home-manager configuration, applied to all users for host\.



*Type:*
module



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.environment



Environment name that this host belongs to (references flake\.environments)



*Type:*
string



*Default:*

```nix
"prod"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.exclude-features



List of features to exclude for the host (prevents the feature and its requires from being added)



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.exporters



Prometheus exporters exposed by this host\.
Example: ` { node = { port = 9100; }; k3s = { port = 10249; }; } `



*Type:*
attribute set of (submodule)



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.exporters\.\<name>\.interval



Scrape interval



*Type:*
string



*Default:*

```nix
"30s"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.exporters\.\<name>\.path



HTTP path for metrics endpoint



*Type:*
string



*Default:*

```nix
"/metrics"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.exporters\.\<name>\.port



Port number for the exporter



*Type:*
signed integer

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.extra_modules



List of additional modules to include for the host\.



*Type:*
list of module



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.facts



Path to the Facter JSON file for the host\.



*Type:*
null or absolute path



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.features



List of features for the host



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.hostname



Hostname



*Type:*
unspecified value *(read only)*



*Default:*

```nix
"‹name›"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.ipv4



The static IP addresses of this host in it’s home vlan\.



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.ipv6



The static IPv6 addresses of this host\.



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.nixosConfiguration



Host-specific NixOS module configuration\.



*Type:*
module



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.public_key



Path to or string value of the public SSH key for the host\.



*Type:*
absolute path



*Default:*

```nix
/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/.secrets/host-keys/‹name›/ssh_host_ed25519_key.pub
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.remoteBuildJobs



The number of build jobs to be scheduled



*Type:*
signed integer



*Default:*

```nix
4
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.remoteBuildSpeed



The relative build speed



*Type:*
signed integer



*Default:*

```nix
1
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.roles



List of roles for the host\.



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.system



System string for the host



*Type:*
one of “aarch64-linux”, “x86_64-linux”



*Default:*

```nix
"x86_64-linux"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.tags



An attribute set of string key-value pairs to tag the host with metadata\.
Example: ` { "kubernetes-cluster" = "prod"; "kubernetes-internal-ip" = "10.0.1.100"; } `

Special tags:

 - bgp-asn: BGP AS number for this host (used by bgp-hub and thunderbolt-mesh modules)
 - thunderbolt-interface-1: IPv4 address for first thunderbolt interface (e\.g\., “169\.254\.12\.0/31”)
 - thunderbolt-interface-2: IPv4 address for second thunderbolt interface (e\.g\., “169\.254\.31\.1/31”)



*Type:*
attribute set of string



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.unstable



This option has no description\.



*Type:*
boolean



*Default:*

```nix
true
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.users



Users on this host with their features and configuration



*Type:*
lazy attribute set of (submodule)



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.users\.\<name>\.configuration



User-specific home configuration



*Type:*
module



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.hosts\.\<name>\.users\.\<name>\.features



List of features specific to the user\.

While a feature may specify NixOS modules in addition to home
modules, only home modules will affect configuration\.  For this
reason, users should be encouraged to avoid pointlessly specifying
their own NixOS modules\.



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/host-options.nix)



## flake\.kubernetes



Global Kubernetes configuration



*Type:*
submodule



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module.nix)



## flake\.kubernetes\.clusterCidr



Kubernetes pod network CIDR



*Type:*
string



*Default:*

```nix
"172.20.0.0/16"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module.nix)



## flake\.kubernetes\.kubeAPIVIP



Kubernetes API VIP



*Type:*
string



*Default:*

```nix
"10.10.10.100"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module.nix)



## flake\.kubernetes\.loadBalancer



LoadBalancer configuration



*Type:*
submodule



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module.nix)



## flake\.kubernetes\.loadBalancer\.cidr



IP range for LoadBalancer services



*Type:*
string



*Default:*

```nix
"10.0.100.0/24"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module.nix)



## flake\.kubernetes\.loadBalancer\.reservations



Reserved IP addresses for specific LoadBalancer services



*Type:*
attribute set of string



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module.nix)



## flake\.kubernetes\.serviceCidr



Kubernetes service network CIDR



*Type:*
string



*Default:*

```nix
"172.21.0.0/16"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module.nix)



## flake\.kubernetes\.services

Kubernetes service definitions with their nixidy modules



*Type:*
lazy attribute set of (submodule)



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module.nix)



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



*Default:*

```nix
null
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module.nix)



## flake\.kubernetes\.services\.\<name>\.excludes



List of names of services to exclude from this service



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module.nix)



## flake\.kubernetes\.services\.\<name>\.nixidy



A nixidy module for this Kubernetes service



*Type:*
module



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module.nix)



## flake\.kubernetes\.services\.\<name>\.options



Option declarations for environment-level configuration of this service\.
These options will be available at kubernetes\.services\.\<name> in environment configs\.
Should contain ONLY option declarations, no config assignments\.



*Type:*
lazy attribute set of raw value



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module.nix)



## flake\.kubernetes\.services\.\<name>\.requires



List of names of services required by this service



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module.nix)



## flake\.kubernetes\.tlsSanIps



Additional IPs to include in Kubernetes API server TLS certificate SANs



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/kubernetes-service-module.nix)



## flake\.users



User specifications and configurations



*Type:*
lazy attribute set of (submodule)



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options.nix)



## flake\.users\.\<name>\.baseline



Baseline features and configurations shared by all of this user’s configurations



*Type:*
submodule



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options.nix)



## flake\.users\.\<name>\.baseline\.features



List of baseline features shared by all of this user’s configurations\.

Note that the “core” feature
(` users.<username>.features.core `) will *always* be
included in all of the user’s configurations\.  This
follows the same behavior as the “core” feature in
the system scope, which is included in all system
configurations\.



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options.nix)



## flake\.users\.\<name>\.baseline\.inheritHostFeatures



Whether to inherit all home-manager features from the host configuration\.

When true, this user will receive all home-manager modules from the host’s
enabled features\. When false, only user-specific features and baseline features
will be included\.

This allows for more granular control over which users get which features on
shared systems\.



*Type:*
boolean



*Default:*

```nix
false
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options.nix)



## flake\.users\.\<name>\.configuration



NixOS configuration for this user



*Type:*
module



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options.nix)



## flake\.users\.\<name>\.features



User-specific feature definitions\.

Note that due to these features’ nature as user-specific, they
may not define NixOS modules, which would affect the entire system\.



*Type:*
lazy attribute set of (submodule)



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options.nix)



## flake\.users\.\<name>\.features\.\<name>\.excludes



List of names of features to exclude from this feature (prevents the feature and its requires from being added)



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options.nix)



## flake\.users\.\<name>\.features\.\<name>\.home



A Home-Manager module for this feature



*Type:*
module



*Default:*

```nix
{ }
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options.nix)



## flake\.users\.\<name>\.features\.\<name>\.requires



List of names of features required by this feature



*Type:*
list of string



*Default:*

```nix
[ ]
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options.nix)



## flake\.users\.\<name>\.name



Username



*Type:*
unspecified value *(read only)*



*Default:*

```nix
"‹name›"
```

*Declared by:*
 - [/nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options\.nix](file:///nix/store/ww7xdp8kpjcnm7lgd9lczhaisb6v8nl3-source/modules/flake-parts/meta/user-options.nix)


