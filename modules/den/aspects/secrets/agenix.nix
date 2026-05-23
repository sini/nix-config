# Agenix aspect — opt-in marker for hosts that use agenix secrets.
#
# Core agenix wiring (module imports, rekey config, HM sharedModules) is
# handled by the agenix battery in modules/den/batteries/agenix.nix,
# which fires for all hosts via den.schema.host.includes.
#
# This aspect remains as an inclusion target for hosts and provides
# the persist key for impermanence integration.
_: {
  den.aspects.secrets.agenix = {
    persist = {
      # Agenix-rekey generators state
    };
  };
}
