{ lib, ... }:
with lib;
rec {
  enabled = {
    ## Quickly enable an option.
    ##
    ## ```nix
    ## services.nginx = enabled;
    ## ```
    ##
    #@ true
    enable = true;
  };

  disabled = {
    ## Quickly disable an option.
    ##
    ## ```nix
    ## services.nginx = enabled;
    ## ```
    ##
    #@ false
    enable = false;
  };

  # return an int (1/0) based on boolean value
  # `boolToNum true` -> 1
  boolToNum = bool: if bool then 1 else 0;

  ## Create a default attribute set.
  default-attrs = mapAttrs (_key: lib.mkDefault);

  ## Create a force attribute set.
  force-attrs = mapAttrs (_key: lib.mkForce);

  ## Create a nested default attribute set.
  nested-default-attrs = mapAttrs (_key: default-attrs);

  ## Create a nested force attribute set.
  nested-force-attrs = mapAttrs (_key: force-attrs);
}
