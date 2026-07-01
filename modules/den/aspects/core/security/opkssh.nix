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
          # authorizations are contributed per-user via den.schema.user.includes below.
        };
      };
  };

  # Per-user opkssh authorizations, derived from the user registry — mirrors
  # user-enrich (modules/den/aspects/core/users/users.nix) in emitting per-user
  # NixOS config from resolved user entities. `services.opkssh.authorizations` is
  # a list option, so per-(host,user) emissions concatenate.
  den.schema.user.includes = [
    (
      { host, user }:
      {
        name = "opkssh-authz/${user.userName}@${host.name}";
        # environment IS available in a schema-include function branch (scope
        # inheritance; precedent: the function `${host.class}` branch in
        # modules/den/batteries/agenix.nix).
        nixos =
          { environment, ... }:
          let
            idmDomain = environment.getDomainFor "kanidm";
            issuerFor =
              p:
              if p.provider == "google" then
                "https://accounts.google.com"
              else
                "https://${idmDomain}/oauth2/openid/opkssh";
          in
          {
            services.opkssh.authorizations = map (p: {
              user = user.userName;
              principal = p.email;
              issuer = issuerFor p;
            }) (user.identity.sshOidcPrincipals or [ ]);
          };
      }
    )
  ];
}
