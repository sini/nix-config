{
  lib,
  config,
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
  config.flake.flakeOptions = {
    # These are now top-level options, not flake sub-options
    inherit (options)
      hosts
      environments
      users
      groups
      kubernetes
      ;
  };

  # Explicitly re-expose internal resources as flake outputs
  config.flake = {
    inherit (config)
      hosts
      environments
      roles
      users
      groups
      ;
  };
}
