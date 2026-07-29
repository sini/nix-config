{
  den.aspects.applications.security.proton-vpn = {
    homeManager =
      { pkgs, ... }:
      {
        home.packages = with pkgs; [
          proton-vpn
        ];
      };
  };
}
