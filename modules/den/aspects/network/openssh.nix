_:
{
  den.aspects.network.openssh = {
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

    persist = {
      files = [
        "/etc/ssh/ssh_host_ed25519_key"
        "/etc/ssh/ssh_host_ed25519_key.pub"
        "/etc/ssh/ssh_host_rsa_key"
        "/etc/ssh/ssh_host_rsa_key.pub"
      ];
    };
  };
}
