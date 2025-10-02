{
  flake.features.coolercontrol.nixos =
    { pkgs, ... }:
    {
      environment.systemPackages = with pkgs; [ liquidctl ];

      programs = {
        coolercontrol = {
          enable = true;
        };
      };
    };
}
