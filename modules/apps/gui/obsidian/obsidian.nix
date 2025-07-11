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
            spellcheck = false;
            showLineNumber = true;
            propertiesInDocument = "hidden";
          };
          appearance = {
            cssTheme = "Catppuccin";
            theme = "obsidian";
            showRibbon = false;
            nativeMenus = false;
            showInlineTitle = false;
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

          # communityPlugins = [
          #   {
          #     pkg = pkgs.nur.obsidian-tasks;
          #     enable = true;
          #   }
          #   {
          #     pkg = pkgs.nur.obsidian-minimal-settings;
          #     enable = true;
          #   }
          #   {
          #     pkg = pkgs.nur.obsidian-dataview;
          #     enable = true;
          #   }
          # ];

          hotkeys = {
            "editor:delete-paragraph" = [ ];
          };

          cssSnippets = [
            {
              name = "stop-blinking-cursor";
              source = ./_snippets/stop-blinking-cursor.css;
            }
          ];
        };
      };
    };
}
