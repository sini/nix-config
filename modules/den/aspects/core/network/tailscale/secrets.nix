# Tailscale auth key — generated against the headscale host, shared by the
# Linux and Darwin concerns of the tailscale aspect.
{ ... }:
{
  den.aspects.core.network.tailscale.age-secrets =
    { environment, host, ... }:
    let
      rekeyFile = host.secretPath + "/tailscale-preauthkey.age";
    in
    {
      age.secrets.tailscale-auth-key = {
        inherit rekeyFile;
        settings = {
          headscaleHost = environment.getDomainFor "headscale";
          user = host.name;
        };
        generator.script = "tailscale-preauthkey";
      };
    };
}
