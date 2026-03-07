{
  lib,
  options,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  # Declare a flake output so flake-parts can merge/typecheck it
  options.flake.flakeOptions = mkOption {
    type = types.raw; # option declarations are not "normal values"; keep it raw
    readOnly = true;
    description = "Option declarations for this flake-parts evaluation (for docs generation).";
  };

  # Populate it from the module argument, NOT from self
  config.flake.flakeOptions =
    let
      # We reach into the 'flake' option's type to find the sub-options.
      # For many flake-parts setups, the sub-options are nested inside
      # the 'type' attribute of the option itself.
      subOptions = options.flake.type.getSubOptions [ "flake" ];
    in
    {
      # This selects only your specific namespaces from the sub-module options
      inherit (subOptions)
        hosts
        environments
        users
        kubernetes
        ;
    };
}
