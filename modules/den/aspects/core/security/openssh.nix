{
  den.aspects.core.security.openssh = {
    nixos = {
      services.openssh = {
        enable = true;
        ports = [ 22 ];

        openFirewall = true;

        settings = {
          PermitRootLogin = "prohibit-password";
          PasswordAuthentication = false;
          KbdInteractiveAuthentication = false;

          KexAlgorithms = [
            "curve25519-sha256"
            "curve25519-sha256@libssh.org"
            "sntrup761x25519-sha512@openssh.com"
          ];
          Ciphers = [
            "chacha20-poly1305@openssh.com"
            "aes256-gcm@openssh.com"
            "aes128-gcm@openssh.com"
          ];
          Macs = [
            "hmac-sha2-512-etm@openssh.com"
            "hmac-sha2-256-etm@openssh.com"
            "umac-128-etm@openssh.com"
          ];
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
          KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,sntrup761x25519-sha512@openssh.com
          Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com
          MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,umac-128-etm@openssh.com
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
