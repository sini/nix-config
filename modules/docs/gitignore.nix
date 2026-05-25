_: {
  perSystem = {
    files.file.".gitignore".text = ''
      /result
      /result.*
      .direnv
      .cache
      .claude
      CLAUDE.md
      docs/superpowers/
      .pre-commit-config.yaml
    '';
  };
}
