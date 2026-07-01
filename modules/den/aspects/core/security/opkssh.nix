{
  # NIXOS-BRANCH-ONLY: darwin (patch) pulls roles.default but ignores the nixos branch,
  # so services.opkssh (a NixOS-only module) never evaluates there. Do NOT add os/darwin.
  den.aspects.core.security.opkssh = {
    nixos =
      { environment, ... }:
      let
        idmDomain = environment.getDomainFor "kanidm";
      in
      {
        services.opkssh = {
          enable = true;
          providers = {
            kanidm = {
              issuer = "https://${idmDomain}/oauth2/openid/opkssh";
              clientId = "opkssh";
              lifetime = "24h";
            };
            # opkssh ships a shared Google client id (the nixpkgs module's own default).
            # Pinned here because setting `providers` replaces the default set (which would
            # otherwise drop google).
            google = {
              issuer = "https://accounts.google.com";
              clientId = "206584157355-7cbe4s640tvm7naoludob4ut1emii7sf.apps.googleusercontent.com";
              lifetime = "24h";
            };
          };
          # authorizations are contributed per-user by a later task (Task 2); leave unset here.
        };
      };
  };
}
