{ den, lib, ... }:
let
  # Deduplication module for list-type options to prevent duplicate entries
  # when multiple aspects contribute to the same persistence path
  dedupModule = {
    options = {
      directories = lib.mkOption {
        type = with lib.types; listOf anything;
        default = [ ];
        apply = lib.unique;
      };
      files = lib.mkOption {
        type = with lib.types; listOf anything;
        default = [ ];
        apply = lib.unique;
      };
    };
  };

  # Factory for system-level forwarding classes
  mkSystemClass =
    {
      fromClass,
      intoPath,
    }:
    den.lib.perHost (
      # deadnix: skip
      { class, aspect-chain }:
      den._.forward {
        each = lib.singleton true;
        fromClass = _: fromClass;
        intoClass = _: "nixos";
        intoPath = _: intoPath;
        fromAspect = _: lib.head aspect-chain;
        guard = { options, ... }: _: lib.mkIf (options ? environment && options.environment ? persistence);
        adapterModule = dedupModule;
      }
    );

  # Factory for user-level forwarding classes
  mkUserClass =
    {
      fromClass,
      intoPath,
    }:
    den.lib.perUser (
      { user }:
      # deadnix: skip
      { class, aspect-chain }:
      den._.forward {
        each = lib.singleton user;
        fromClass = _: fromClass;
        intoClass = _: "homeManager";
        intoPath = _: intoPath;
        fromAspect = _: lib.head aspect-chain;
        adapterModule = dedupModule;
      }
    );

  # System-level: persist class -> environment.persistence."/persist"
  persist-class = mkSystemClass {
    fromClass = "persist";
    intoPath = [
      "environment"
      "persistence"
      "/persist"
    ];
  };

  # System-level: cache class -> environment.persistence."/cache"
  cache-class = mkSystemClass {
    fromClass = "cache";
    intoPath = [
      "environment"
      "persistence"
      "/cache"
    ];
  };

  # User-level: persistHome class -> home.persistence."/persist"
  persistHome-class = mkUserClass {
    fromClass = "persistHome";
    intoPath = [
      "home"
      "persistence"
      "/persist"
    ];
  };

  # User-level: cacheHome class -> home.persistence."/cache"
  cacheHome-class = mkUserClass {
    fromClass = "cacheHome";
    intoPath = [
      "home"
      "persistence"
      "/cache"
    ];
  };
in
{
  den.ctx.default.includes = [
    persist-class
    cache-class
    persistHome-class
    cacheHome-class
  ];
}
