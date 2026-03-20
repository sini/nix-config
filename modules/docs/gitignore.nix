{ config, ... }:
{
  # Nix git-ignores
  text.gitignore = ''
    /result
    /result.*
    .direnv
    .cache
    .claude
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
