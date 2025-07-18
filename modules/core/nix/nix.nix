{
  flake.modules.nixos.nix = {
    nix =
      let
        users = [
          "root"
          "@wheel"
        ];
      in
      {
        settings = {
          experimental-features = "nix-command flakes pipe-operators";

          max-jobs = "auto";

          # Make legacy nix commands use the XDG base directories instead of creating directories in $HOME.
          use-xdg-base-directories = true;

          # The maximum number of parallel TCP connections used to fetch files from binary caches and by other downloads.
          # It defaults to 25. 0 means no limit.
          http-connections = 128;

          # This option defines the maximum number of substitution jobs that Nix will try to run in
          # parallel. The default is 16. The minimum value one can choose is 1 and lower values will be
          # interpreted as 1.
          max-substitution-jobs = 128;

          # The number of lines of the tail of the log to show if a build fails.
          log-lines = 25;

          # When free disk space in /nix/store drops below min-free during a build, Nix performs a
          # garbage-collection until max-free bytes are available or there is no more garbage.
          # A value of 0 (the default) disables this feature.
          min-free = 128000000; # 128 MB
          max-free = 1000000000; # 1 GB

          # Automatically detect files in the store that have identical contents, and replaces
          # them with hard links to a single copy. This saves disk space.
          auto-optimise-store = true;

          # Whether to warn about dirty Git/Mercurial trees.
          warn-dirty = false;

          ################
          # Substituters #
          ################
          substituters = [
            "https://cache.nixos.org/"
            "https://nix-community.cachix.org"
            "https://chaotic-nyx.cachix.org/"
          ];

          trusted-public-keys = [
            "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
            "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
            "chaotic-nyx.cachix.org-1:HfnXSw4pj95iI/n17rIDy40agHj12WfF+Gqk6SonIT8="
          ];

          # The timeout (in seconds) for establishing connections in the binary cache substituter.
          # It corresponds to curl’s –connect-timeout option. A value of 0 means no limit.
          connect-timeout = 5;

          # Allow the use of cachix
          trusted-users = users;
          allowed-users = users;

          builders-use-substitutes = true;

          sandbox = "relaxed";

          # If set to true, Nix will fall back to building from source if a binary substitute
          # fails. This is equivalent to the –fallback flag. The default is false.
          fallback = true;
        };

        gc = {
          automatic = true;
          dates = "05:00";
          options = "--delete-older-than 8d";
        };
      };
  };
}
