{
  options,
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.system.shell;
in
{
  options.system.shell = with types; {
    shell = mkOpt (enum [
      "nushell"
      "fish"
      "zsh"
    ]) "nushell" "What shell to use";
  };

  config = {
    environment.systemPackages = with pkgs; [
      eza
      bat
      nitch
      zoxide
      starship
    ];

    users.defaultUserShell = pkgs.${cfg.shell};
    users.users.root.shell = pkgs.bashInteractive;

    environment.shellAliases = {
      ".." = "cd ..";
      neofetch = "nitch";
    };

    home = {
      configFile."starship.toml".source = ./starship.toml;
      programs = {
        starship = {
          enable = true;
          enableFishIntegration = true;
          enableNushellIntegration = true;
        };

        zoxide = {
          enable = true;
          enableNushellIntegration = true;
        };

        # Actual Shell Configurations
        fish = mkIf (cfg.shell == "fish") {
          enable = true;
          shellAliases = {
            ls = "eza -la --icons --no-user --no-time --git -s type";
            cat = "bat";
          };
          shellInit = ''
            ${mkIf apps.tools.direnv.enable ''
              direnv hook fish | source
            ''}

            zoxide init fish | source

            function , --description 'add software to shell session'
                  nix shell nixpkgs#$argv[1..-1]
            end
          '';
        };

        # Enable all if nushell
        nushell = mkIf (cfg.shell == "nushell") {
          enable = true;
          shellAliases = config.environment.shellAliases // {
            ls = "ls";
          };
          envFile.text = "";
          extraConfig = ''
            $env.config = {
              show_banner: false,
            }

            def , [...packages] {
                nix shell ($packages | each {|s| $"nixpkgs#($s)"})
            }
          '';
        };
      };
    };
  };
}
