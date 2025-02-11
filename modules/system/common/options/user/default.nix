############################################################################
# OS-agnostic home config options for the system's primary account holder. #
############################################################################
{
  config,
  lib,
  options,
  pkgs,
  namespace,
  ...
}:
let
  inherit (lib)
    mkIf
    mkOption
    mkDefault
    types
    ;
  inherit (lib.${namespace}) mkOpt;
  inherit (pkgs.buildPlatform) isDarwin;
  cfg = config.user;
in
{
  options.user = with types; {
    name = mkOption {
      type = nullOr str;
      default = "sini";
      description = "The primary account holder's username (defaults to 'sini').";
    };

    home = mkOption {
      type = nullOr str;
      default = if isDarwin then "/Users/${cfg.name}" else "/home/${cfg.name}";
      description = "The primary account holder's home directory.";
    };

    initialPassword =
      mkOpt str "$y$j9T$RpfkDk8AusZr9NS09tJ9e.$kbc4SL9Cu45o1YYPlyV1jiVTZZ/126ue5Nff2Rfgpw8"
        "The initial password to use when the user is first created.";

    extraGroups = mkOpt (listOf str) [ ] "Groups for the user to be assigned.";

    extraOptions = mkOpt attrs { } "Extra options passed to <option>users.users.<name></option>.";
  };

  config = mkIf (cfg.name != null) {
    # home-manager.useGlobalPkgs = lib.mkDefault true;
    # # NOTE: For some reason if this enabled on macOS it totally breaks
    # # home-manager's package installation.
    # home-manager.useUserPackages = lib.mkDefault true;
    users.users.${cfg.name} = {
      inherit (cfg) name home;
      uid = mkDefault 1000;
    };
  };

}
