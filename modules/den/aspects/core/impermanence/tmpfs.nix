{
  den.aspects.core.impermanence.tmpfs = {
    nixos = {
      boot.tmp = {
        useTmpfs = true;
        cleanOnBoot = true;
      };
    };
  };
}
