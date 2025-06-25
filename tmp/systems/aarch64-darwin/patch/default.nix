{
  config,
  inputs,
  pkgs,
  ...
}:
{
  # environment.shells = [ pkgs.fish ];
  age.secrets.randomPassword = {
    rekeyFile = ./secrets/randomPassword.age;
    generator.script = "passphrase";
  };

  users.users.sini = {
    description = "Jason Bowman";
    home = "/Users/sini";
    # shell = pkgs.fish;
  };

  home-manager = {
    useUserPackages = true;
    useGlobalPkgs = true;
    users.sini = ../../../legacy-modules/home/home.nix;
    sharedModules = [ ];
    extraSpecialArgs = {
      inherit inputs;
    };
  };

  custom.dock = {
    enable = true;
    username = "sini";
    entries = [
      # { path = "/Applications/Slack.app/"; }
      { path = "/System/Applications/Messages.app/"; }
      { path = "/System/Applications/Facetime.app/"; }
      # { path = "/Applications/Telegram.app/"; }
      # { path = "${pkgs.alacritty}/Applications/Ghostty.app/"; }
      # { path = "/System/Applications/Music.app/"; }
      # { path = "/System/Applications/News.app/"; }
      # { path = "/System/Applications/Photos.app/"; }
      # { path = "/System/Applications/Photo Booth.app/"; }
      # { path = "/System/Applications/TV.app/"; }
      # { path = "${pkgs.jetbrains.phpstorm}/Applications/PhpStorm.app/"; }
      # { path = "/Applications/TablePlus.app/"; }
      # { path = "/Applications/Asana.app/"; }
      # { path = "/Applications/Drafts.app/"; }
      # { path = "/System/Applications/Home.app/"; }
      # { path = "/Applications/iPhone Mirroring.app/"; }
      # {
      # path    = toString myEmacsLauncher;
      # section = "others";
      # }
      {
        path = "${config.users.users.sini.home}/.local/share/";
        section = "others";
        options = "--sort name --view grid --display folder";
      }
      {
        path = "${config.users.users.sini.home}/.local/share/downloads";
        section = "others";
        options = "--sort name --view grid --display stack";
      }
    ];
  };

  environment.systemPackages = with pkgs; [
    mosh
    age-plugin-yubikey
    ssh-to-pgp
    yj
    sops
    nix-fast-build
    iperf3
    iperf
  ];

  # ======================== DO NOT CHANGE THIS ========================
  system.stateVersion = 6;
  # ======================== DO NOT CHANGE THIS ========================
}
