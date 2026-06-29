# Karabiner-Elements key remapping. The app is a cask (kernel/HID driver, no
# nixpkgs build); the config is generated declaratively into karabiner.json.
#
# First run needs manual approval of Karabiner's driver extension + Input
# Monitoring permission (System Settings prompts for both).
let
  hyper = [
    "left_command"
    "left_control"
    "left_option"
  ];

  rules = [
    {
      description = "Caps Lock: Escape on tap, Control on hold";
      manipulators = [
        {
          type = "basic";
          from = {
            key_code = "caps_lock";
            modifiers.optional = [ "any" ];
          };
          to = [ { key_code = "left_control"; } ];
          to_if_alone = [ { key_code = "escape"; } ];
        }
      ];
    }
    {
      description = "Right Command -> Hyper (Cmd+Ctrl+Opt+Shift)";
      manipulators = [
        {
          type = "basic";
          from = {
            key_code = "right_command";
            modifiers.optional = [ "any" ];
          };
          to = [
            {
              key_code = "left_shift";
              modifiers = hyper;
            }
          ];
        }
      ];
    }
  ];

  karabinerConfig = {
    global.show_in_menu_bar = false;
    profiles = [
      {
        name = "Default";
        selected = true;
        complex_modifications.rules = rules;
        virtual_hid_keyboard.keyboard_type_v2 = "ansi";
      }
    ];
  };
in
{
  den.aspects.macos.apps.karabiner = {
    homebrew-cask = [ "karabiner-elements" ];

    # Karabiner owns Caps Lock now (tap=escape, hold=control), so drop the
    # system-level caps->control remap (mkDefault in macos.defaults.keyboard).
    darwin.system.keyboard.remapCapsLockToControl = false;

    homeDarwin =
      { pkgs, ... }:
      {
        home.file.".config/karabiner/karabiner.json".source =
          (pkgs.formats.json { }).generate "karabiner.json"
            karabinerConfig;
      };
  };
}
