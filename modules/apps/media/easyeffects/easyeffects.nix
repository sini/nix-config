{
  flake.features.easyeffects.home = {
    xdg.configFile = {
      "easyeffects/output/HD650.json".source = ./presets/HD650.json;
      "easyeffects/autoload/output/alsa_output.usb-Topping_D10-00.HiFi__Headphones__sink.json".text =
        builtins.toJSON
          {
            device = "alsa_output.usb-Topping_D10-00.HiFi__Headphones__sink";
            device-description = "Created by Home Manager";
            device-profile = "[Out] Headphones";
            preset-name = "HD650";
          };
      "easyeffects/output/GalaxyBuds.json".source = ./presets/GalaxyBuds.json;
      "easyeffects/autoload/output/bluez_output.38_8F_30_F0_D1_9D.1.json".text = builtins.toJSON {
        device = "bluez_output.38_8F_30_F0_D1_9D.1";
        device-description = "Created by Home Manager";
        device-profile = "headset-output";
        preset-name = "GalaxyBuds";
      };
    };
  };
}
