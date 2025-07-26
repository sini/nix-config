{
  flake.modules.nixos.coolercontrol =
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
