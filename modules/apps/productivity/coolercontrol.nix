{
  flake.features.coolercontrol.linux =
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
