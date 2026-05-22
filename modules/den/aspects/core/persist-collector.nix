{ den, ... }:
{
  den.aspects.core.persist-collector = {
    nixos =
      { persist, cache, lib, ... }:
      let
        mergePersist = entries: {
          directories = lib.unique (lib.concatMap (e: e.directories or [ ]) entries);
          files = lib.unique (lib.concatMap (e: e.files or [ ]) entries);
        };
      in
      {
        environment.persistence."/persist" = mergePersist persist;
        environment.persistence."/cache" = mergePersist cache;
      };
  };
}
