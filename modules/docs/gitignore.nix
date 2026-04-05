{ config, ... }:
{
  # Nix git-ignores
  text.gitignore = ''
    /result
    /result.*
    .direnv
    .cache
    .claude
    CLAUDE.md
    docs/superpowers/
  '';

  perSystem =
    { pkgs, ... }:
    {
      files.files = [
        {
          path_ = ".gitignore";
          drv = pkgs.writeText ".gitignore" config.text.gitignore;
        }
      ];
    };
}
