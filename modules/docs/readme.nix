{ config, ... }:
{
  text.readme = {
    order = [
      "logo"
      "header"
      "colmena"
      "users"
      "automatic-import"
      "files"
      "disallow-warnings"
      "links"
    ];

    parts.header =
      # markdown
      ''
        <br>

        # sini/nix-config

        <br>
        <div align="center">
            <a href="https://github.com/sini/nix-config/stargazers">
                <img src="https://img.shields.io/github/stars/sini/nix-config?color=c14d26&labelColor=0b0b0b&style=for-the-badge&logo=starship&logoColor=c14d26">
            </a>
            <a href="https://github.com/sini/nix-config">
                <img src="https://img.shields.io/github/repo-size/sini/nix-config?color=c14d26&labelColor=0b0b0b&style=for-the-badge&logo=github&logoColor=c14d26">
            </a>
            <a href="https://nixos.org">
                <img src="https://img.shields.io/badge/NixOS-unstable-blue.svg?style=for-the-badge&labelColor=0b0b0b&logo=NixOS&logoColor=c14d26&color=c14d26">
            </a>
            <a href="https://github.com/sini/nix-config/blob/main/LICENSE">
                <img src="https://img.shields.io/static/v1.svg?style=for-the-badge&label=License&message=MIT&colorA=0b0b0b&colorB=c14d26&logo=unlicense&logoColor=c14d26"/>
            </a>
        </div>

        <br>

        # ${config.flake.meta.repo.owner}/${config.flake.meta.repo.name}

        ${config.flake.meta.owner.name}'s [NixOS](https://nix.dev) homelab and workstation configuration repository.
        > [!NOTE]
        > If you have any questions or suggestions, feel free to contact me via e-mail jason <at> json64 <dot> dev.
      '';
  };

  perSystem =
    { pkgs, ... }:
    {
      files.files = [
        {
          path_ = "README.md";
          drv = pkgs.writeText "README.md" config.text.readme;
        }
      ];
    };
}
