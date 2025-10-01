{
  flake.modules.homeManager.obsidian =
    { pkgs, ... }:
    {
      home.packages = with pkgs; [ obsidian ];
      programs.obsidian = {
        enable = true;
        vaults = {
          Obsidian = {
            enable = true;
            target = "Documents/obsidian";
          };
        };
        defaultSettings = {
          app = {
            vimMode = true;
            spellcheck = true;
            showLineNumber = true;
            propertiesInDocument = "hidden";
          };

          corePlugins = [
            "audio-recorder"
            "backlink"
            "bookmarks"
            "canvas"
            "command-palette"
            "daily-notes"
            "editor-status"
            "file-explorer"
            "file-recovery"
            "global-search"
            "graph"
            "markdown-importer"
            "note-composer"
            "outgoing-link"
            "outline"
            "page-preview"
            "properties"
            "publish"
            "random-note"
            "slash-command"
            "slides"
            "switcher"
            "sync"
            "tag-pane"
            "templates"
            "word-count"
            "workspaces"
            "zk-prefixer"
          ];

          # TODO: Enable community plugins if needed
          # communityPlugins = [ "obsidian-livesync" ];

          hotkeys = {
            "editor:delete-paragraph" = [ ];
          };
        };
      };
    };
}
