{
  flake.features.openssh.nixos = {
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
}
