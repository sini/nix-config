{ config, ... }:
let
  readmeText = config.text.readme;
in
{
  text.readme = {
    order = [
      "logo"
      "header"
      "hosts"
      "flake-options"
      "colmena"
      "users"
      "automatic-import"
      "files"
      "disallow-warnings"
      "links"
    ];

    parts = {
      header =
        # markdown
        ''
          <br>

          # ${config.flake.meta.repo.owner}/${config.flake.meta.repo.name}

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

          ${config.users.sini.name}'s [NixOS](https://nix.dev) homelab and workstation configuration repository.

          > [!NOTE]
          > If you have any questions or suggestions, feel free to contact me via e-mail `jason <at> json64 <dot> dev`.

        '';

      disallow-warnings =
        # markdown
        ''
          ## Trying to disallow warnings

          This at the top level of the `flake.nix` file:

          ```nix
          nixConfig.abort-on-warn = true;
          ```

          > [!NOTE]
          > It does not currently catch all warnings Nix can produce, but perhaps only evaluation warnings.

        '';

      automatic-import =
        # markdown
        ''
          ## Automatic import

          Nix files (they're all flake-parts modules) are automatically imported.
          Nix files prefixed with an underscore are ignored.
          No literal path imports are used.
          This means files can be moved around and nested in directories freely.

          > [!NOTE]
          > This pattern has been the inspiration of [an auto-imports library, import-tree](https://github.com/vic/import-tree).

        '';
    };
  };

  perSystem =
    { pkgs, ... }:
    {
      files.files = [
        {
          path_ = "README.md";
          drv = pkgs.writeText "README.md" readmeText;
        }
      ];
    };
}
