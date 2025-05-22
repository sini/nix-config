{
  inputs,
  lib,
  pkgs,
  ...
}:
{
  nixpkgs.config = {
    allowUnfree = true;
  };

  nix = {
    enable = true;
    linux-builder = {
      enable = true;
      # ephemeral = false;
      maxJobs = 8;
      package = pkgs.darwin.linux-builder-x86_64;
    };

    nixPath = lib.mkForce [
      "nixpkgs=${inputs.nixpkgs}"
      "home-manager=${inputs.home-manager}"
    ];

    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      # This seems to cause issues:
      # https://github.com/NixOS/nix/issues/7273
      #auto-optimise-store = true;
      trusted-substituters = [
        "https://helix.cachix.org"
        "https://cache.nixos.org"
      ];
      trusted-public-keys = [
        "helix.cachix.org-1:ejp9KQpR1FBI2onstMQ34yogDm4OgU2ru6lIwPvuCVs="
      ];
      trusted-users = [
        "root"
        "@admin"
      ];
    };

    channel.enable = false;
  };

  # https://nixcademy.com/posts/macos-linux-builder/
  launchd.daemons.linux-builder = {
    serviceConfig = {
      StandardOutPath = "/var/log/darwin-builder.log";
      StandardErrorPath = "/var/log/darwin-builder.log";
    };
  };

}
