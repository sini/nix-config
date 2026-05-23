_:
{
  den.aspects.hardware.keyboard = {
    nixos = {
      boot.kernelModules = [ "hid_apple" ];
      boot.extraModprobeConfig = "options hid_apple fnmode=2 swap_opt_cmd=0";
    };
  };
}
