{ rootPath, ... }:
{
  flake.features.tailscale.nixos =
    { config, environment, ... }:
    {
      # sudo headscale preauthkeys create --user 1 --reusable -e 10y
      age.secrets.tailscale-auth-key = {
        rekeyFile = rootPath + "/.secrets/services/tailscale.age";
      };

      services.tailscale = {
        enable = true;
        openFirewall = true;
        authKeyFile = config.age.secrets.tailscale-auth-key.path;
        extraUpFlags = [ "--login-server=https://hs.${environment.domain}" ];
        extraDaemonFlags = [ "--no-logs-no-support" ];
      };

      networking = {
        firewall = {
          checkReversePath = "loose";
          trustedInterfaces = [ config.services.tailscale.interfaceName ];
          allowedUDPPorts = [ config.services.tailscale.port ];
        };
      };

      environment.persistence."/persist".directories = [
        "/var/lib/tailscale"
      ];
    };
}
