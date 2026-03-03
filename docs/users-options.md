## flake\.users

User specifications and configurations



*Type:*
lazy attribute set of (submodule)



## flake\.users\.\<name>\.baseline



Baseline features and configurations shared by all of this user’s configurations



*Type:*
submodule



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



## flake\.users\.\<name>\.baseline\.inheritHostFeatures



Whether to inherit all home-manager features from the host configuration\.

When true, this user will receive all home-manager modules from the host’s
enabled features\. When false, only user-specific features and baseline features
will be included\.

This allows for more granular control over which users get which features on
shared systems\.



*Type:*
boolean



## flake\.users\.\<name>\.configuration



NixOS configuration for this user



*Type:*
module



## flake\.users\.\<name>\.features



User-specific feature definitions\.

Note that due to these features’ nature as user-specific, they
may not define NixOS modules, which would affect the entire system\.



*Type:*
lazy attribute set of (submodule)



## flake\.users\.\<name>\.features\.\<name>\.excludes



List of names of features to exclude from this feature (prevents the feature and its requires from being added)



*Type:*
list of string



## flake\.users\.\<name>\.features\.\<name>\.home



A Home-Manager module for this feature



*Type:*
module



## flake\.users\.\<name>\.features\.\<name>\.requires



List of names of features required by this feature



*Type:*
list of string



## flake\.users\.\<name>\.name



Username



*Type:*
unspecified value *(read only)*


