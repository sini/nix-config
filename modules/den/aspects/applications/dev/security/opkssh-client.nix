# opkssh CLIENT tooling for the machines you SSH *from* (workstations + darwin).
# Installs the `opkssh` CLI plus provider config so `opkssh login` mints an
# OIDC-backed short-lived SSH cert against kanidm (default) or Google. The
# server-side verifier lives in core/security/opkssh.nix; this is the client
# counterpart. Attached via roles.workstation / roles.darwin-workstation only
# (NOT roles.dev — that reaches slab/droid, which has no opkssh).
{ ... }:
let
  # `opkssh-login` wrapper: authenticate, then load the freshly-minted cert into
  # the standard ssh-agent (an ssh-agent-mux backend). opkssh writes the OIDC
  # cert to ~/.ssh/id_ecdsa(+-cert.pub) and adds it to NO agent, so on its own
  # the cert only reaches consumers that name the file explicitly. That breaks
  # colmena, which targets a bare IP (host.ipv4) matching no ssh `Host` block.
  # Loading it into the agent makes it available to every SSH_AUTH_SOCK consumer
  # — colmena and plain ssh alike — with no per-host ssh-config dependency.
  loginScript =
    pkgs: lib: kanidmIssuer: standardSock:
    pkgs.writeShellScript "opkssh-login" ''
      set -euo pipefail

      # Point at the standard agent, not the mux: opkssh/ssh-add write keys and
      # the mux is a read-only aggregator that cannot accept adds.
      export SSH_AUTH_SOCK="${standardSock}"

      ${lib.getExe pkgs.opkssh} login --provider=${kanidmIssuer},opkssh "$@"

      # ssh-add loads the private key and automatically picks up the adjacent
      # id_ecdsa-cert.pub certificate.
      ${pkgs.openssh}/bin/ssh-add "$HOME/.ssh/id_ecdsa"
    '';
in
{
  den.aspects.applications.dev.security.opkssh-client = {
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
        # Moved shellAliases to OS-specific blocks below to handle socket paths
      };

    homeLinux =
      {
        pkgs,
        lib,
        environment,
        ...
      }:
      let
        idmDomain = environment.getDomainFor "kanidm";
        kanidmIssuer = "https://${idmDomain}/oauth2/openid/opkssh";
        standardSock = "\${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/standard-ssh-agent.sock";
      in
      {
        home.shellAliases = {
          opkssh-login = "${loginScript pkgs lib kanidmIssuer standardSock}";
        };
      };

    homeDarwin =
      {
        pkgs,
        lib,
        environment,
        ...
      }:
      let
        idmDomain = environment.getDomainFor "kanidm";
        kanidmIssuer = "https://${idmDomain}/oauth2/openid/opkssh";
        standardSock = "$(getconf DARWIN_USER_TEMP_DIR)/standard-ssh-agent.sock";
      in
      {
        home.shellAliases = {
          opkssh-login = "${loginScript pkgs lib kanidmIssuer standardSock}";
        };
      };
  };
}
