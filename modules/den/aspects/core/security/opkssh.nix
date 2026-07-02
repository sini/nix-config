{
  # opkssh SERVER verifier.
  # - NixOS: the nixpkgs `services.opkssh` module wires sshd's AuthorizedKeysCommand
  #   + /etc/opk/{providers,auth_id} for us (nixos branch below).
  # - darwin: there is no nix-darwin module, so the `darwin` branch hand-rolls the same
  #   thing. Critically, nix-darwin ALREADY owns sshd's AuthorizedKeysCommand for static
  #   keys (101-authorized-keys.conf: `/bin/cat /etc/ssh/nix_authorized_keys.d/%u`), and
  #   sshd honours only the first AuthorizedKeysCommand — so we COMPOSE with it (a wrapper
  #   that runs opkssh verify AND cats that same static-key file), at 100- so it wins,
  #   without breaking key-based access.
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

    # macOS hand-rolled verifier (no nix-darwin services.opkssh). Builds auth_id from the
    # host's resolved users (via the resolved-users collection, which now carries
    # sshOidcPrincipals) instead of the nixos-only list option.
    darwin =
      {
        pkgs,
        lib,
        environment,
        resolved-users,
        ...
      }:
      let
        idmDomain = environment.getDomainFor "kanidm";
        issuerFor =
          p:
          if p.provider == "google" then
            "https://accounts.google.com"
          else
            "https://${idmDomain}/oauth2/openid/opkssh";
        authIdLines = lib.concatMap (
          u: map (p: "${u.name} ${p.email} ${issuerFor p}") (u.sshOidcPrincipals or [ ])
        ) resolved-users;
        providersFile = pkgs.writeText "opk-providers" ''
          https://accounts.google.com 206584157355-7cbe4s640tvm7naoludob4ut1emii7sf.apps.googleusercontent.com 24h
          https://${idmDomain}/oauth2/openid/opkssh opkssh 24h
        '';
        authIdFile = pkgs.writeText "opk-auth-id" (lib.concatStringsSep "\n" authIdLines + "\n");
        # Composite AuthorizedKeysCommand: emit opkssh-verified principals (if a valid
        # opkssh cert was presented) AND nix-darwin's static keys, then always exit 0 so
        # sshd uses the combined output regardless of opkssh's verdict. Reuses _sshd.
        # `cd /` first: sshd runs this in the login user's home, which _sshd can't stat
        # (noisy getcwd errors otherwise). It may reference store paths internally — sshd
        # only safe-path-checks the AuthorizedKeysCommand path, not what the script calls.
        authKeysCmd = pkgs.writeShellScript "opkssh-authorized-keys" ''
          cd /
          ${pkgs.opkssh}/bin/opkssh verify "$1" "$2" "$3" 2>/dev/null || true
          /bin/cat "/etc/ssh/nix_authorized_keys.d/$1" 2>/dev/null || true
          exit 0
        '';
        # sshd refuses an AuthorizedKeysCommand whose path (or any parent) is group/world
        # writable — and on macOS /nix/store IS group-writable ("Unsafe AuthorizedKeysCommand
        # ... bad ownership or modes for directory /nix/store"). nix-darwin sidesteps this with
        # /bin/cat; we must too, so the command is installed to a root-owned safe path below.
        authKeysCmdPath = "/etc/opk/authorized-keys-command";
      in
      {
        # 100- sorts before nix-darwin's 101-authorized-keys.conf, so sshd uses this composite
        # command (first value wins). Points at the safe /etc path, NOT the store (see above).
        environment.etc."ssh/sshd_config.d/100-opkssh.conf".text = ''
          AuthorizedKeysCommand ${authKeysCmdPath} %u %k %t
          AuthorizedKeysCommandUser _sshd
        '';

        # Materialise, via activation script (nix-darwin's environment.etc only makes 0444
        # store symlinks), two things that can't live in the store:
        #  - the AuthorizedKeysCommand at a root-owned safe path (store is group-writable → sshd
        #    rejects it);
        #  - the opkssh policy files as real 0640 files owned by _sshd — opkssh refuses a policy
        #    file that isn't mode 640 ("insecure permissions ... got (444)").
        system.activationScripts.postActivation.text = ''
          mkdir -p /etc/opk
          install -m 0755 ${authKeysCmd} ${authKeysCmdPath}
          rm -f /etc/opk/providers /etc/opk/auth_id
          install -m 0640 -o _sshd ${providersFile} /etc/opk/providers
          install -m 0640 -o _sshd ${authIdFile} /etc/opk/auth_id
        '';
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
