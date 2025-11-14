{
  flake.features.keyboard.nixos = {
    # Apple keyboard should behave like normal keyboards...
    boot.kernelModules = [ "hid_apple" ];
    boot.extraModprobeConfig = "options hid_apple fnmode=2 swap_opt_cmd=0";
  };
}
