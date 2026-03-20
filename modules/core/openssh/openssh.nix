{
  features.openssh = {
    linux = {
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

      impermanence.ignorePaths = [
        "/etc/ssh/authorized_keys.d/"
      ];
    };

    darwin = {
      services.openssh = {
        enable = true;

        extraConfig = ''
          PermitRootLogin prohibit-password
          PasswordAuthentication no
          KbdInteractiveAuthentication no
          AllowTcpForwarding yes
          AllowAgentForwarding yes
          AllowStreamLocalForwarding yes
          AuthenticationMethods publickey
        '';
      };
    };
  };
}
