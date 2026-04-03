{ den, ... }:
{
  den.aspects.openssh = den.lib.perHost {
    nixos = {
      services.openssh = {
        enable = true;
        ports = [ 22 ];

        openFirewall = true;

        settings = {
          PermitRootLogin = "prohibit-password";
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
