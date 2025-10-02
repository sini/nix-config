{
  flake.features.openssh.nixos =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    {
      services.openssh = {
        enable = true;
        ports = [ 22 ];

        openFirewall = true;

        settings.PermitRootLogin = "prohibit-password";

        settings = {
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;
        };

        extraConfig = ''
          AllowTcpForwarding yes
          X11Forwarding yes
          AllowAgentForwarding yes
          AllowStreamLocalForwarding yes
          AuthenticationMethods publickey
        '';
      };

      # Let all users with the "wheel" group have their keys in the authorized_keys for root.
      users.users.root.openssh.authorizedKeys.keys =
        with lib;
        concatLists (
          mapAttrsToList (
            _name: user: if elem "wheel" user.extraGroups then user.openssh.authorizedKeys.keys else [ ]
          ) config.users.users
        );

      age.secrets.initrd_host_ed25519_key.generator.script = "ssh-ed25519-tmpdir";

      # Make sure that there is always a valid initrd hostkey available that can be installed into
      # the initrd. When bootstrapping a system (or re-installing), agenix cannot succeed in decrypting
      # whatever is given, since the correct hostkey doesn't even exist yet. We still require
      # a valid hostkey to be available so that the initrd can be generated successfully.
      # The correct initrd host-key will be installed with the next update after the host is booted
      # for the first time, and the secrets were rekeyed for the the new host identity.
      system.activationScripts.agenixEnsureInitrdHostkey = {
        text = ''
          [[ -e ${config.age.secrets.initrd_host_ed25519_key.path} ]] \
            || ${pkgs.openssh}/bin/ssh-keygen -t ed25519 -N "" -f ${config.age.secrets.initrd_host_ed25519_key.path}
        '';
        deps = [
          "agenixInstall"
          "users"
        ];
      };
      system.activationScripts.agenixChown.deps = [ "agenixEnsureInitrdHostkey" ];
    };
}
