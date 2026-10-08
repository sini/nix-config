{ lib, ... }:
{
  den.aspects.core.security.openssh = {
    settings = {
      exposure = lib.mkOption {
        type = lib.types.enum [
          "tailnet"
          "public"
        ];
        default = "tailnet";
        description = "SSH exposure: tailnet/LAN only (default) or public (break-glass jumpbox).";
      };
      externalPort = lib.mkOption {
        type = lib.types.port;
        default = 22;
        description = ''
          WAN port the gateway forwards to this host's sshd (port 22) when exposure
          is public. Give each public host a distinct port; the forward renderer
          refuses two forwards on the same WAN port.
        '';
      };
    };

    # Publishing sshd is the exposure choice, so a public host also gets the
    # gateway forward to it.
    port-forwards =
      { environment, host, ... }:
      lib.optional (host.settings.core.security.openssh.exposure == "public") {
        environment = environment.name;
        name = "ssh-to-${host.name}";
        protocol = "tcp";
        wanPort = toString host.settings.core.security.openssh.externalPort;
        forward = {
          ip = environment.addressOn "default" host;
          port = "22";
        };
      };

    nixos =
      {
        host,
        environment,
        ...
      }:
      {
        services.openssh = {
          enable = true;
          ports = [ 22 ];

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

        # sshd is public only on the break-glass jumpbox (exposure = "public");
        # every other host is reachable over tailnet/LAN only.
        services.openssh.openFirewall = lib.mkForce (
          host.settings.core.security.openssh.exposure == "public"
        );

        # tailscale0 is already a trusted interface (set by the tailscale aspect),
        # so tailnet SSH works with the firewall closed. Also allow the host's LAN
        # CIDR so uplink can ProxyJump to targets over the LAN when the tailnet
        # control plane is down (the break-glass path).
        networking.firewall.extraInputRules =
          lib.mkIf (host.settings.core.security.openssh.exposure == "tailnet")
            ''
              ip saddr ${environment.networks.default.cidr} tcp dport 22 accept
            '';
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
