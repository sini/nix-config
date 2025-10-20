{ ... }:
{
  flake.hosts.spike = {
    ipv4 = [ "10.9.3.1" ];
    ipv6 = [ "2001:5a8:608c:4a00::31/64" ];
    environment = "dev";
    roles = [
      "workstation"
      "laptop"
      "gaming"
      "dev"
      "dev-gui"
      "media"
    ];
    features = [
      "cpu-intel"
      "gpu-intel"
      "gpu-nvidia"
      "gpu-nvidia-prime"
      "network-manager"
      "razer"
    ];
    extra_modules = [
      ./_local
    ];
    users = {
      "sini" = {
        "features" = [
          "spotify-player"
        ];
      };
    };
    facts = ./facter.json;
  };
}
