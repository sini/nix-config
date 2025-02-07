{ config, pkgs, ... }:
{

  # The homeDirectory is configured by each host's configuration because it's
  # not constant between linux and macos

  home = {
    username = "sini";

    packages = with pkgs; [
      # Editors that I sometimes want to play with
      vim
      neovim

      # Find me stuff
      fd
      ripgrep
      comma
      amber
      sad
      delta

      # bitwarden-cli

      # File stuff
      eza
      jq
      jnv
      glow

      # File transfer stuff
      curl
      croc
      wget

      nodejs

      # Other stuff
      git-open
      asciinema
      parallel
      #_1password-cli
      nix-output-monitor

    ];
    homeDirectory = "/Users/sini";
    stateVersion = "24.11";
  };
  # Interestingly this is actually broken in macOS! I went on a deep-dive
  # and eventually found that the Zed team has run into this issue as well.
  # https://github.com/zed-industries/community/issues/1373#issuecomment-1499033975
  #   home.file.".hushlogin".text = "";

  # If the system should have Touch ID enabled for sudo, also enable the check
  # in my fish config. It runs every time a new shell starts, but this is a
  # pretty cheap check because the file it checks is small.
  #   my.programs.fish.enableGreetingTouchIdCheck = osConfig.security.pam.enableSudoTouchIdAuth;

  #   my.programs.fish.setupNixEnv = true;

  # This is under programs because it does technically install kitty, but that's
  # an implementation detail, I use the kitty installed with brew. I just didn't
  # want to bother copying the module to my own modules folder just to remove
  # one line from it.
  #   my.programs.kitty.enable = false;

  #my.programs.ghostty.enable = true;
  # my.programConfig.zed.enable = true;

  # Might move this to the fish module one day but for now it's specific to
  # this system. If there's another Mac or a NixOS system to care about, that
  # would be a good time to refactor into something that can be shared.
  # programs.fish.interactiveShellInit = language "fish" ''
  #   # 1Password SSH agent should only be used if not in an SSH session
  #   if not set -q SSH_TTY
  #     set -gx SSH_AUTH_SOCK ~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
  #   end
  # '';

  programs = {
    home-manager.enable = true;

    broot = {
      enable = true;
      settings = {
        imports = [ "skins/dark-gruvbox.hjson" ];
        # NOTE: In Ghostty, this breaks shift. Not sure why and haven't looked into it.
        # enable_kitty_keyboard = lib.mkForce true;
      };
    };

    direnv = {
      enable = true;
      nix-direnv.enable = true;
      silent = true;
    };

    jujutsu.enable = true;

    # TODO: figure out why this is breaking in nushell
    zoxide = {
      enable = true;
      enableNushellIntegration = false;
    };

    zellij.enable = true;

    nushell = {
      enable = true;
    };

    fzf = {
      enable = true;
      defaultOptions = [
        # "--height ~40%"
      ];
    };

    gh = {
      enable = true;

      # Required because of a settings migration
      settings.version = 1;
    };

    bat = {
      enable = true;
      config.theme = "gruvbox-dark";
    };
    # --
    git = {
      enable = true;
      userEmail = "Jason Bowman <jason@json64.dev>";
      signing.key = "0xA3CDE710F034AB0B";
      # package = pkgs.gitFull;
      ignores = [
        "*~"
        "*.swp"
        "result"
        ".DS_Store"
        "/.helix"
        ".flake"
        ".pkgs"
      ];
      extraConfig = {
        commit.gpgsign = true;
        init.defaultBranch = "main";
        push.autoSetupRemote = true;
      };
      delta.enable = true;
    };

    gpg = {
      enable = true;

      # https://support.yubico.com/hc/en-us/articles/4819584884124-Resolving-GPG-s-CCID-conflicts
      scdaemonSettings = {
        disable-ccid = true;
      };

      # https://github.com/drduh/config/blob/master/gpg.conf
      settings = {
        personal-cipher-preferences = "AES256 AES192 AES";
        personal-digest-preferences = "SHA512 SHA384 SHA256";
        personal-compress-preferences = "ZLIB BZIP2 ZIP Uncompressed";
        default-preference-list = "SHA512 SHA384 SHA256 AES256 AES192 AES ZLIB BZIP2 ZIP Uncompressed";
        cert-digest-algo = "SHA512";
        s2k-digest-algo = "SHA512";
        s2k-cipher-algo = "AES256";
        charset = "utf-8";
        fixed-list-mode = true;
        no-comments = true;
        no-emit-version = true;
        keyid-format = "0xlong";
        list-options = "show-uid-validity";
        verify-options = "show-uid-validity";
        with-fingerprint = true;
        require-cross-certification = true;
        no-symkey-cache = true;
        use-agent = true;
        throw-keyids = true;
      };
    };
  };

  services = {
    gpg-agent = {
      enable = true;
      enableSshSupport = true;

      # https://github.com/drduh/config/blob/master/gpg-agent.conf
      defaultCacheTtl = 60;
      maxCacheTtl = 120;
      pinentryPackage = pkgs.pinentry_mac;
      extraConfig = ''
        ttyname $GPG_TTY
      '';
    };
  };
  programs.fish.shellInit = ''
    set -gx GPG_TTY (tty)
    set -e SSH_AUTH_SOCK
    set -gx SSH_AUTH_SOCK (${config.programs.gpg.package}/bin/gpgconf --list-dirs agent-ssh-socket)
  '';
}
