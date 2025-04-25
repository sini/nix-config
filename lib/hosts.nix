{ lib, namespace, ... }:
let
  inherit (builtins)
    filter
    map
    ;
  inherit (lib.strings) hasSuffix;
  inherit (lib.lists) flatten;
  inherit (lib.${namespace}) relativeToRoot listDirectories;

  listHostsWithSystem = flatten (
    map (
      system:
      map (hostname: {
        "system" = system;
        "hostname" = hostname;
        "path" = relativeToRoot "systems/${system}/${hostname}";
      }) (listDirectories "systems/${system}")
    ) (listDirectories "systems")
  );

  isHostDarwin = { system, ... }: hasSuffix "darwin" system;

  darwinHosts = filter isHostDarwin listHostsWithSystem;

  linuxHosts = filter (host: !isHostDarwin host) listHostsWithSystem;

  # Function to extract the targetHost of the *first* node with the
  # "kubernetes-master" tag.  Returns null if no match is found.
  getKubernetesMasterTargetHost =
    nodes:
    let
      # Use lib.findFirst to find the *first* matching node.
      firstMasterNode =
        lib.findFirst
          (
            nodeConfig: # Changed to expect nodeConfig directly
            builtins.elem "kubernetes-master" (nodeConfig.config.node.deployment.tags or [ ])
          )
          (config: config) # Return the config, not just true/false
          (lib.attrValues nodes); # Convert the nodes attribute set to a list
    in
    if firstMasterNode != null then firstMasterNode.config.node.deployment.targetHost or null else null;
in
rec {
  inherit
    listHostsWithSystem
    isHostDarwin
    darwinHosts
    linuxHosts
    getKubernetesMasterTargetHost
    ;
}
