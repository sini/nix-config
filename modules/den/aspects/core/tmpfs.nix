_: {
  den.aspects.core.tmpfs = {
    nixos = {
      boot.tmp = {
        useTmpfs = true;
        cleanOnBoot = true;
      };
    };
  };
}
