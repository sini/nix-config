## flake\.hosts

This option has no description\.



*Type:*
attribute set of (submodule)



## flake\.hosts\.\<name>\.baseline



Baseline configurations for repeatable configuration types on this host



*Type:*
submodule



## flake\.hosts\.\<name>\.baseline\.home



Host-specific home-manager configuration, applied to all users for host\.



*Type:*
module



## flake\.hosts\.\<name>\.environment



Environment name that this host belongs to (references flake\.environments)



*Type:*
string



## flake\.hosts\.\<name>\.exclude-features



List of features to exclude for the host (prevents the feature and its requires from being added)



*Type:*
list of string



## flake\.hosts\.\<name>\.exporters



Prometheus exporters exposed by this host\.
Example: ` { node = { port = 9100; }; k3s = { port = 10249; }; } `



*Type:*
attribute set of (submodule)



## flake\.hosts\.\<name>\.exporters\.\<name>\.interval



Scrape interval



*Type:*
string



## flake\.hosts\.\<name>\.exporters\.\<name>\.path



HTTP path for metrics endpoint



*Type:*
string



## flake\.hosts\.\<name>\.exporters\.\<name>\.port



Port number for the exporter



*Type:*
signed integer



## flake\.hosts\.\<name>\.extra_modules



List of additional modules to include for the host\.



*Type:*
list of module



## flake\.hosts\.\<name>\.facts



Path to the Facter JSON file for the host\.



*Type:*
null or absolute path



## flake\.hosts\.\<name>\.features



List of features for the host



*Type:*
list of string



## flake\.hosts\.\<name>\.hostname



Hostname



*Type:*
unspecified value *(read only)*



## flake\.hosts\.\<name>\.ipv4



The static IP addresses of this host in it’s home vlan\.



*Type:*
list of string



## flake\.hosts\.\<name>\.ipv6



The static IPv6 addresses of this host\.



*Type:*
list of string



## flake\.hosts\.\<name>\.nixosConfiguration



Host-specific NixOS module configuration\.



*Type:*
module



## flake\.hosts\.\<name>\.public_key



Path to or string value of the public SSH key for the host\.



*Type:*
absolute path



## flake\.hosts\.\<name>\.remoteBuildJobs



The number of build jobs to be scheduled



*Type:*
signed integer



## flake\.hosts\.\<name>\.remoteBuildSpeed



The relative build speed



*Type:*
signed integer



## flake\.hosts\.\<name>\.roles



List of roles for the host\.



*Type:*
list of string



## flake\.hosts\.\<name>\.system



System string for the host



*Type:*
one of “aarch64-linux”, “x86_64-linux”



## flake\.hosts\.\<name>\.tags



An attribute set of string key-value pairs to tag the host with metadata\.
Example: ` { "kubernetes-cluster" = "prod"; "kubernetes-internal-ip" = "10.0.1.100"; } `

Special tags:

 - bgp-asn: BGP AS number for this host (used by bgp-hub and thunderbolt-mesh modules)
 - thunderbolt-interface-1: IPv4 address for first thunderbolt interface (e\.g\., “169\.254\.12\.0/31”)
 - thunderbolt-interface-2: IPv4 address for second thunderbolt interface (e\.g\., “169\.254\.31\.1/31”)



*Type:*
attribute set of string



## flake\.hosts\.\<name>\.unstable



This option has no description\.



*Type:*
boolean



## flake\.hosts\.\<name>\.users



Users on this host with their features and configuration



*Type:*
lazy attribute set of (submodule)



## flake\.hosts\.\<name>\.users\.\<name>\.configuration



User-specific home configuration



*Type:*
module



## flake\.hosts\.\<name>\.users\.\<name>\.features



List of features specific to the user\.

While a feature may specify NixOS modules in addition to home
modules, only home modules will affect configuration\.  For this
reason, users should be encouraged to avoid pointlessly specifying
their own NixOS modules\.



*Type:*
list of string


