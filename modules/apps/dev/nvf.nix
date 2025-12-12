{
  inputs,
  ...
}:
{
  flake.features.nvf.home = {
    imports = [ inputs.nvf.homeManagerModules.default ];
    programs.nvf = {
      enable = true;
      settings.vim = {
        theme = {
          enable = true;
        };
        options = {
          tabstop = 2;
          shiftwidth = 2;
          softtabstop = 2;
          expandtab = false;
        };
        maps = {
          normal."<leader><Left>" = {
            silent = true;
            action = "<cmd>bprev<CR>";
          };
          normal."<leader><Right>" = {
            silent = true;
            action = "<cmd>bnext<CR>";
          };
          visual."<" = {
            action = "<gv";
            desc = "Unindent and reselect";
          };
          visual.">" = {
            action = ">gv";
            desc = "Indent and reselect";
          };
        };
        viAlias = true;
        vimAlias = true;
        preventJunkFiles = true;

        # Debug Mode (optional)
        debugMode = {
          enable = false;
        };

        # Language Server Protocol (LSP) settings
        lsp = {
          enable = true;
          formatOnSave = true;
          lightbulb.enable = true;
          trouble.enable = true;
          lspSignature.enable = true;
        };

        # Debugger
        debugger = {
          nvim-dap = {
            enable = true;
            ui.enable = true;
          };
        };

        # Languages and Formatters
        languages = {
          enableFormat = true;
          enableTreesitter = true;
          enableExtraDiagnostics = true;
          nix = {
            enable = true;
            format = {
              enable = true;
              type = "nixfmt";
            };
            lsp = {
              enable = true;
              servers = [ "nixd" ];
            };
            treesitter.enable = true;
          };

          markdown.enable = true;
          bash.enable = true;
          python.enable = true;
          css.enable = true;
          rust.enable = true;
          # Language modules that are not as common.
          assembly.enable = false;
          astro.enable = false;
          nu.enable = false;
          csharp.enable = false;
          julia.enable = false;
          vala.enable = false;
          scala.enable = false;
          r.enable = false;
          gleam.enable = false;
          dart.enable = false;
          ocaml.enable = false;
          elixir.enable = false;
          haskell.enable = false;
          ruby.enable = false;

          tailwind.enable = false;
          svelte.enable = false;
        };

        # Visuals and UI
        visuals = {
          nvim-web-devicons.enable = true;
          cinnamon-nvim.enable = true;
          fidget-nvim.enable = true;
          highlight-undo.enable = false;
          indent-blankline.enable = true;
          nvim-cursorline = {
            enable = true;
            setupOpts.line_timeout = 0;
          };
        };

        # Statusline & Theme
        statusline = {
          lualine = {
            enable = true;
            #          theme = "catppuccin";
            #          theme = "base16";
            #          theme = "auto";
          };
        };
        # General features
        autopairs.nvim-autopairs.enable = true;
        autocomplete.nvim-cmp.enable = true;

        # Disable filetree for now
        # filetree = {
        #   nvimTree = {
        #     enable = true;
        #   };
        # };

        tabline = {
          nvimBufferline.enable = true;
        };
        treesitter.context.enable = true;

        # Miscellaneous Features
        binds = {
          whichKey.enable = true;
          cheatsheet.enable = true;
        };
        telescope.enable = true;

        # Git & Version Control
        git = {
          enable = true;
          gitsigns.enable = true;
          gitsigns.codeActions.enable = false;
        };

        # Minimap & Dashboard
        minimap = {
          minimap-vim.enable = false;
        };
        dashboard = {
          startify.enable = true;
        };

        # Notifications & Utility
        notify = {
          nvim-notify.enable = true;
        };
        utility = {
          diffview-nvim.enable = true;
          motion = {
            hop.enable = true;
            leap.enable = true;
            precognition.enable = true;
          };
        };

        # Notes & Comments
        notes = {
          todo-comments.enable = true;
        };

        comments = {
          comment-nvim.enable = true;
        };

        # Terminal & Session Management
        terminal = {
          toggleterm = {
            enable = true;
            lazygit.enable = true;
          };
        };

        # UI Enhancements
        ui = {
          borders.enable = true;
          noice.enable = true;
          colorizer.enable = true;
          illuminate.enable = true;
          modes-nvim.enable = false;
          smartcolumn = {
            enable = true;
            setupOpts.custom_colorcolumn = {
              nix = "110";
              ruby = "120";
              java = "130";
              go = [
                "90"
                "130"
              ];
            };
          };
          fastaction.enable = true;
          breadcrumbs = {
            enable = true;
            navbuddy.enable = true;
          };
        };

        # Disable unnecessary features
        assistant = {
          chatgpt.enable = false;
          copilot.enable = false;
        };

        session = {
          nvim-session-manager.enable = false;
        };

        gestures = {
          gesture-nvim.enable = false;
        };

        presence = {
          neocord.enable = false;
        };
      };
    };

    home.sessionVariables = {
      EDITOR = "nvim";
    };
  };
}
