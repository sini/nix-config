{
  den.aspects.applications.dev.lang.markdown = {
    codium-settings = [
      {
        "markdown.preview.breaks" = true;
      }
    ];

    codium-extensions =
      { pkgs, ... }:
      [
        pkgs.vscode-marketplace.bierner.markdown-checkbox
        pkgs.vscode-marketplace.bierner.markdown-emoji
        pkgs.vscode-marketplace.bierner.markdown-footnotes
        pkgs.vscode-marketplace.bierner.markdown-mermaid
        pkgs.vscode-marketplace.bierner.markdown-preview-github-styles
        pkgs.vscode-marketplace.bierner.markdown-yaml-preamble
        pkgs.vscode-marketplace.davidanson.vscode-markdownlint
        pkgs.vscode-marketplace.marp-team.marp-vscode
        pkgs.vscode-marketplace.unifiedjs.vscode-mdx
        pkgs.vscode-marketplace.xyc.vscode-mdx-preview
        pkgs.vscode-marketplace.yzhang.markdown-all-in-one
      ];
  };
}
