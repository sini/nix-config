# pi-coding-agent (https://pi.dev, github:earendil-works/pi-mono):
# Terminal AI coding agent with Stylix theme generation & Plan Mode extensions.
{ ... }:
{
  den.aspects.applications.dev.ai.pi = {
    homeManager =
      {
        config,
        pkgs,
        lib,
        ...
      }:
      let
        # Check if stylix colors are available
        hasStylix = config ? lib.stylix && config.lib.stylix ? colors;
        s =
          if hasStylix then
            config.lib.stylix.colors.withHashtag
          else
            {
              base00 = "#1e1e2e";
              base01 = "#181825";
              base02 = "#313244";
              base03 = "#45475a";
              base04 = "#585b70";
              base05 = "#cdd6f4";
              base08 = "#f38ba8";
              base09 = "#fab387";
              base0A = "#f9e2af";
              base0B = "#a6e3a1";
              base0C = "#94e2d5";
              base0D = "#89b4fa";
              base0E = "#cba6f7";
            };

        stylixTheme = pkgs.writeText "stylix.json" (
          builtins.toJSON {
            "$schema" =
              "https://raw.githubusercontent.com/badlogic/pi-mono/main/packages/coding-agent/src/modes/interactive/theme/theme-schema.json";
            name = "stylix";
            vars = {
              bg = s.base00;
              bgLight = s.base01;
              selection = s.base02;
              comment = s.base03;
              fgDark = s.base04;
              fg = s.base05;
              red = s.base08;
              orange = s.base09;
              yellow = s.base0A;
              green = s.base0B;
              cyan = s.base0C;
              blue = s.base0D;
              magenta = s.base0E;
            };
            colors = {
              accent = "blue";
              border = "comment";
              borderAccent = "blue";
              borderMuted = "fgDark";
              success = "green";
              error = "red";
              warning = "yellow";
              muted = "fgDark";
              dim = "comment";
              text = "";
              thinkingText = "fgDark";
              selectedBg = "selection";
              userMessageBg = "bgLight";
              userMessageText = "";
              customMessageBg = "bgLight";
              customMessageText = "";
              customMessageLabel = "blue";
              toolPendingBg = "bgLight";
              toolSuccessBg = "bgLight";
              toolErrorBg = "bgLight";
              toolTitle = "blue";
              toolOutput = "";
              mdHeading = "yellow";
              mdLink = "blue";
              mdLinkUrl = "fgDark";
              mdCode = "cyan";
              mdCodeBlock = "";
              mdCodeBlockBorder = "fgDark";
              mdQuote = "fgDark";
              mdQuoteBorder = "fgDark";
              mdHr = "comment";
              mdListBullet = "cyan";
              toolDiffAdded = "green";
              toolDiffRemoved = "red";
              toolDiffContext = "fgDark";
              syntaxComment = "comment";
            };
          }
        );
      in
      {
        home.packages = [
          pkgs.pi-coding-agent
        ];

        programs.git.ignores = [
          "/.pi/"
        ];

        # Deploy Stylix theme for pi
        home.file.".pi/agent/themes/stylix.json".source = stylixTheme;

        # Deploy Plan Mode & Security Guard extensions for pi
        home.file.".pi/agent/extensions/plan-mode.ts".source = ./pi/extensions/plan-mode.ts;
        home.file.".pi/agent/extensions/plan-tracker.ts".source = ./pi/extensions/plan-tracker.ts;
        home.file.".pi/agent/extensions/security-guard.ts".source = ./pi/extensions/security-guard.ts;

        # Configure default settings to use stylix theme and local endpoints
        home.file.".pi/agent/settings.json".text = builtins.toJSON {
          defaultProvider = "ollama";
          defaultModel = "qwen3.8:27b";
          defaultThinkingLevel = "medium";
          defaultProjectTrust = "never";
          theme = "stylix";
          extensions = [
            "~/.pi/agent/extensions/plan-mode.ts"
            "~/.pi/agent/extensions/plan-tracker.ts"
            "~/.pi/agent/extensions/security-guard.ts"
          ];
        };
      };

    persistHome = {
      directories = [
        ".pi"
      ];
    };
  };
}
