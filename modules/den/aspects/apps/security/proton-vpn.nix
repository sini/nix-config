{
  den.aspects.apps.security.proton-vpn = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          proton-vpn
        ];
      };
  };
}
