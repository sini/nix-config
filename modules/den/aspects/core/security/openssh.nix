{ config, lib, ... }:
let
  # GitHub's SSH host keys, so a fresh host (or a microvm guest) can git-over-ssh with
  # StrictHostKeyChecking intact. From https://api.github.com/meta `ssh_keys` (HTTPS), whose
  # fingerprints equal the docs' published ones and the keys cortex already trusted, 2026-11-09:
  #   ed25519 SHA256:+DiY3wvvV6TuJJhbpZisF/zLDA0zPMSvHdkr4UvCOqU
  #   ecdsa   SHA256:p2QAMXNIC1TJYWeIOttrVc98/R1BUFWu3/LiyKgUfQM
  #   rsa     SHA256:uNiVztksCsDhcc0u9e8BujQXVUpKZIDTMczCvj3tD2s
  # GitHub rotates rarely and announces it; re-read the meta endpoint then.
  githubHostKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl"
    "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg="
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk="
  ];
in
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
        # One entry per key: a knownHosts entry carries a single publicKey.
        programs.ssh.knownHosts = lib.listToAttrs (
          lib.imap0 (i: key: {
            name = "github-${toString i}";
            value = {
              hostNames = [ "github.com" ];
              publicKey = key;
            };
          }) githubHostKeys
        );

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
        # CIDR, and those of the environments it admits (sshFrom), so uplink can
        # ProxyJump to targets over the LAN when the tailnet control plane is down
        # (the break-glass path).
        networking.firewall.extraInputRules =
          lib.mkIf (host.settings.core.security.openssh.exposure == "tailnet")
            (
              lib.concatMapStrings (cidr: "ip saddr ${cidr} tcp dport 22 accept\n") (
                [ environment.networks.default.cidr ]
                ++ map (e: config.den.environments.${e}.networks.default.cidr) environment.sshFrom
              )
            );
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
