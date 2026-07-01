# opkssh CLIENT tooling for the machines you SSH *from* (workstations + darwin).
# Installs the `opkssh` CLI plus provider config so `opkssh login` mints an
# OIDC-backed short-lived SSH cert against kanidm (default) or Google. The
# server-side verifier lives in core/security/opkssh.nix; this is the client
# counterpart. Attached via roles.workstation / roles.darwin-workstation only
# (NOT roles.dev — that reaches slab/droid, which has no opkssh).
{ lib, ... }:
{
  den.aspects.apps.dev.security.opkssh-client = {
    homeManager =
      { pkgs, environment, ... }:
      let
        idmDomain = environment.getDomainFor "kanidm";
        kanidmIssuer = "https://${idmDomain}/oauth2/openid/opkssh";
      in
      {
        home.packages = [ pkgs.opkssh ];

        # Upstream home-manager has no `programs.opkssh` module, so write the
        # client provider config by hand. This is the swarsel-proven config.yml
        # format: `opkssh login` reads it and offers `default_provider` (kanidm)
        # with google available by alias.
        home.file.".opk/config.yml".text = ''
          default_provider: kanidm
          providers:
            - alias: kanidm
              issuer: ${kanidmIssuer}
              client_id: opkssh
              scopes: openid email profile groups
              redirect_uris:
                - http://localhost:3000/login-callback
                - http://localhost:10001/login-callback
                - http://localhost:11110/login-callback
            - alias: google
              issuer: https://accounts.google.com
              client_id: 206584157355-7cbe4s640tvm7naoludob4ut1emii7sf.apps.googleusercontent.com
        '';

        # config.yml above is the preferred UX (plain `opkssh login`). The
        # `--provider` alias below is the guaranteed fallback (the documented
        # datosh recipe) that works regardless of whether the pinned opkssh
        # version (currently 0.14.x in nixpkgs) honors the config file — pending
        # hands-on confirmation of its config-file support at e2e
        # (fleet/hardware) time.
        home.shellAliases = {
          opkssh-login = "${lib.getExe pkgs.opkssh} login --provider=${kanidmIssuer},opkssh";
        };
      };
  };
}
