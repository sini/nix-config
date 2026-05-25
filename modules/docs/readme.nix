{
  dag,
  config,
  lib,
  ...
}:
{
  options.flake.readme = lib.mkOption {
    type = lib.types.lazyAttrsOf lib.types.unspecified;
    default = { };
  };

  config = {
    flake.readme.header =
      dag.entryBefore [ "hosts" ]
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

          sini's [NixOS](https://nix.dev) homelab and workstation configuration repository.

          > [!NOTE]
          > If you have any questions or suggestions, feel free to contact me via e-mail `jason <at> json64 <dot> dev`.

        '';

    flake.readme.automatic-import = dag.entryBetween [ "files" ] [ "den" ] ''
        ## Automatic import

        Nix files (they're all flake-parts modules) are automatically imported.
        Nix files prefixed with an underscore are ignored.
        No literal path imports are used.
        This means files can be moved around and nested in directories freely.

        > [!NOTE]
        > This pattern has been the inspiration of [an auto-imports library, import-tree](https://github.com/vic/import-tree).

      '';

    flake.readme.disallow-warnings = dag.entryBetween [ "links" ] [ "files" ] ''
        ## Trying to disallow warnings

        This at the top level of the `flake.nix` file:

        ```nix
        nixConfig.abort-on-warn = true;
        ```

        > [!NOTE]
        > It does not currently catch all warnings Nix can produce, but perhaps only evaluation warnings.

      '';

    flake.readme.files = dag.entryBetween [ "disallow-warnings" ] [ "automatic-import" ] ''
        ## Generated files

        The following files in this repository are generated and checked
        using [the ENHANCED _files_ flake-parts module](https://github.com/sini/files):

        - `.gitignore`
        - `LICENSE`
        - `README.md`
        - `.sops.yaml`
        - `.secrets/secrets-manifest.md`

      '';

    perSystem =
      _:
      {
        files.file."README.md".text = dag.render {
          entries = config.flake.readme;
          separator = "\n";
        };
      };
  };
}
