{
  den.aspects.core.impermanence.persist-home-collector = {
    homeManager =
      {
        persistHome,
        cacheHome,
        lib,
        ...
      }:
      let
        mergePersist = entries: {
          directories = lib.unique (lib.concatMap (e: e.directories or [ ]) entries);
          files = lib.unique (lib.concatMap (e: e.files or [ ]) entries);
        };
      in
      {
        home.persistence."/persist" = mergePersist persistHome;
        home.persistence."/cache" = mergePersist cacheHome;
      };
  };
}
