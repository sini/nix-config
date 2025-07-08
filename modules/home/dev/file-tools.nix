{
  flake.modules.homeManager.file-tools =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [
        atool
        du-dust
        fd
        file
        jq
        ripgrep
        ripgrep-all
        unzip
        tokei
      ];

      programs = {
        bat.enable = true;
        fzf.enable = true;
        zoxide = {
          enable = true;
          options = [
            "--cmd"
            "j"
          ];
        };
      };
    };
}
