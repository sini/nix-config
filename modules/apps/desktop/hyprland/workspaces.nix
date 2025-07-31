{
  flake.modules.homeManager.hyprland = {
    wayland.windowManager.hyprland.settings = {

      # workspace =
      #   let
      #     monitors = [
      #       # order matters
      #       "desc:Dell Inc. DELL P2422H 8WRR0V3"
      #       "desc:BOE 0x0747"
      #       "desc:^(Dell Inc. DELL P2422H 6FZG7N3|Lenovo Group Limited M14t V309WMZ3)$"
      #     ];
      #   in
      #   [
      #     "1, monitor:${builtins.elemAt monitors 0}, default:yes"
      #     "2, monitor:${builtins.elemAt monitors 0}"
      #     "3, monitor:${builtins.elemAt monitors 0}"
      #     "4, monitor:${builtins.elemAt monitors 0}"
      #     "5, monitor:${builtins.elemAt monitors 1}, default:yes"
      #     "6, monitor:${builtins.elemAt monitors 1}"
      #     "7, monitor:${builtins.elemAt monitors 1}"
      #     "8, monitor:${builtins.elemAt monitors 1}"
      #     "9, monitor:${builtins.elemAt monitors 1}"
      #     "10, monitor:${builtins.elemAt monitors 2}, default:yes"
      #     "11, monitor:${builtins.elemAt monitors 2}"
      #     "12, monitor:${builtins.elemAt monitors 2}"
      #     "13, monitor:${builtins.elemAt monitors 2}"
      #     "14, monitor:${builtins.elemAt monitors 2}"
      #   ];

      # binds = {
      #   # NOTE: no effect
      #   workspace_back_and_forth = false;
      #   allow_workspace_cycles = false;
      #   movefocus_cycles_fullscreen = false;
      # };

    };
  };
}
