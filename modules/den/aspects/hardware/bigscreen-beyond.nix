# bigscreen-beyond — Bigscreen Beyond / Beyond 2e (Bigscreen Bigeye) support.
#
# No kernel patches here. The display and DSC fixes this headset needs are
# already carried by the CachyOS tree we build, as the 7.2/vesa-dsc-bpp series:
# drm/edid parses the VESA DSC bpp target, amdgpu_dm consumes it as
# dsc_fixed_bits_per_pixel_x16, and the DSC 1.1 flatness_max_qp limit is
# corrected. All three verified present in 7.2.5.
#
# The eye-tracking camera patch is deliberately left out — upstream recommends
# flashing eyetracking firmware >= 0.5.5 instead, which needs the Windows
# utility. https://vronlinux.org/docs/hardware/bigscreen-beyond/
{
  den.aspects.hardware.bigscreen-beyond = {
    nixos =
      { config, lib, ... }:
      lib.mkMerge [
        {
          # services.udev.extraRules lands in 99-local.rules, which runs after
          # 73-seat-late.rules — TAG+="uaccess" never fires from here, so access
          # is granted by group rather than by widening MODE to 0666.
          services.udev.extraRules = ''
            # Bigscreen Beyond
            KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0101", MODE="0660", GROUP="video"
            # Bigscreen Beyond Firmware Mode
            KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="4004", MODE="0660", GROUP="video"
            # Bigscreen Beyond Error Mode
            KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="1001", MODE="0660", GROUP="video"
            # Bigscreen Beyond Audio Strap
            KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0105", MODE="0660", GROUP="video"

            # Bigscreen Bigeye
            KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0202", MODE="0660", GROUP="video"
            SUBSYSTEM=="usb", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0202", MODE="0660", GROUP="video"
            # Bigscreen Bigeye DFU Mode
            KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="35bd", ATTRS{idProduct}=="0282", MODE="0660", GROUP="video"
          '';
        }

        # In its default 90 Hz mode the headset exposes no other mode to Monado
        # over Vulkan; the Windows utility has to switch it first. Index 0 is
        # whichever mode it was left in.
        (lib.mkIf config.services.monado.enable {
          systemd.user.services.monado.environment.XRT_COMPOSITOR_DESIRED_MODE = "0";
        })
      ];

    homeManager =
      { ... }:
      {
        # The Bigscreen Beyond Utility runs under Proton and needs hidraw
        # passthrough for each of the headset's device modes. Upstream documents
        # this as a per-title launch argument; one session variable covers all.
        home.sessionVariables.PROTON_ENABLE_HIDRAW = "0x35BD/0x0101,0x35BD/0x4004,0x35BD/0x1001,0x35BD/0x0202,0x35BD/0x0282";
      };
  };
}
