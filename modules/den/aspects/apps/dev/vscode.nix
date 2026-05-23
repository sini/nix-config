{ inputs, ... }:
{
  den.aspects.apps.vscode = {
    os =
      _:
      {
        nixpkgs.overlays = [
          inputs.nix-vscode-extensions.overlays.default
        ];
      };

    homeManager =
      {
        lib,
        pkgs,
        ...
      }:
      let
        inherit (pkgs.stdenv) isLinux;
      in
      {
        home.packages = [
          pkgs.bash-language-server
          pkgs.go
          pkgs.gopls
          pkgs.luaformatter
          pkgs.luajit
          pkgs.lua-language-server
          pkgs.nil
          pkgs.nixfmt
          pkgs.prettier
          pkgs.shellcheck
          pkgs.shfmt
          pkgs.stylua
        ];

        programs.vscode = {
          enable = true;
          package = pkgs.vscodium;
          mutableExtensionsDir = true;
          profiles.default = {
            enableExtensionUpdateCheck = false;
            enableUpdateCheck = false;
            userSettings = {
              "catppuccin-icons.hidesExplorerArrows" = false;
              "catppuccin-icons.specificFolders" = true;
              "catppuccin-icons.monochrome" = false;
              "chat.mcp.autostart" = "newAndOutdated";
              "chat.mcp.discovery.enabled" = {
                "claude-desktop" = true;
                "cursor-global" = true;
                "cursor-workspace" = true;
                "windsurf" = true;
              };
              "cSpell.userWords" = [
                "distro"
                "distrobox"
                "distroboxrc"
                "distros"
                "dkms"
                "Flatpak"
                "gphoto"
                "Keyer"
                "libnvidia"
                "localuser"
                "NVENC"
                "Pango"
                "Pipewire"
                "Quickemu"
                "quickget"
                "quickreport"
                "reqwest"
                "RIST"
                "RTMP"
                "RTSP"
                "shellcheck"
                "Syncthing"
                "ublue"
                "Vulkan"
                "Wimpress"
                "xhost"
                "Xwayland"
              ];
              "direnv.restart.automatic" = true;
              "editor.bracketPairColorization.independentColorPoolPerBracketType" = true;
              "editor.fontLigatures" = true;
              "editor.fontWeight" = "400";
              "editor.guides.bracketPairs" = true;
              "editor.guides.bracketPairsHorizontal" = true;
              "editor.inlineSuggest.enabled" = true;
              "editor.renderWhitespace" = "all";
              "editor.rulers" = [
                80
                120
              ];
              "editor.semanticHighlighting.enabled" = true;
              "explorer.confirmDragAndDrop" = false;
              "extensions.ignoreRecommendations" = true;
              "[lua]"."editor.defaultFormatter" = "JohnnyMorganz.stylua";
              "[nix]"."editor.defaultFormatter" = "jnoortheen.nix-ide";
              "[nix]"."editor.formatOnPaste" = true;
              "[nix]"."editor.formatOnSave" = true;
              "[nix]"."editor.tabSize" = 2;
              "[python]"."editor.formatOnType" = true;
              "[xml]"."editor.defaultFormatter" = "DotJoshJohnson.xml";
              "files.insertFinalNewline" = true;
              "files.trimTrailingWhitespace" = true;
              "git.openRepositoryInParentFolders" = "always";
              "github.copilot.chat.agent.thinkingTool" = true;
              "github.copilot.chat.codesearch.enabled" = true;
              "githubPullRequests.pullBranch" = "never";
              "markdown.preview.breaks" = true;
              "nix.enableLanguageServer" = true;
              "nix.serverPath" = "nil";
              "nix.serverSettings" = {
                "nil" = {
                  "formatting" = {
                    "command" = [ "nixfmt" ];
                  };
                };
              };
              "partialDiff.enableTelemetry" = false;
              "projectManager.git" = {
                baseFolders = [
                  "~/repos"
                ];
                maxDepthRecursion = 5;
              };
              "redhat.telemetry.enabled" = false;
              "security.workspace.trust.untrustedFiles" = "open";
              "shellcheck.run" = "onSave";
              "shellformat.useEditorConfig" = true;
              "telemetry.feedback.enabled" = false;
              "telemetry.telemetryLevel" = "off";
              "terminal.integrated.scrollback" = 10240;
              "terminal.integrated.copyOnSelection" = true;
              "terminal.integrated.cursorBlinking" = true;
              "update.mode" = "none";
              "vsicons.dontShowNewVersionMessage" = true;
              "workbench.tree.indent" = 20;
              "workbench.startupEditor" = "none";
              "workbench.editor.empty.hint" = "hidden";
            };
            extensions = [
              pkgs.vscode-marketplace.aaron-bond.better-comments
              pkgs.vscode-marketplace.alefragnani.project-manager
              pkgs.vscode-marketplace.alexgb.nelua
              pkgs.vscode-marketplace.anthropic.claude-code
              pkgs.vscode-marketplace.automatalabs.copilot-mcp
              pkgs.vscode-marketplace.bmalehorn.shell-syntax
              pkgs.vscode-marketplace.bmalehorn.vscode-fish
              pkgs.vscode-marketplace.budparr.language-hugo-vscode
              pkgs.vscode-marketplace.catppuccin.catppuccin-vsc-icons
              pkgs.vscode-marketplace.codezombiech.gitignore
              pkgs.vscode-marketplace.coolbear.systemd-unit-file
              pkgs.vscode-marketplace.dotjoshjohnson.xml
              pkgs.vscode-marketplace.editorconfig.editorconfig
              pkgs.vscode-marketplace.eliostruyf.vscode-front-matter
              pkgs.vscode-marketplace.esbenp.prettier-vscode
              pkgs.vscode-marketplace.evan-buss.font-switcher
              pkgs.vscode-marketplace.fill-labs.dependi
              pkgs.vscode-marketplace.foxundermoon.shell-format
              pkgs.vscode-marketplace.github.copilot
              pkgs.vscode-marketplace-release.github.copilot-chat
              pkgs.vscode-marketplace.github.vscode-github-actions
              pkgs.vscode-marketplace-release.github.vscode-pull-request-github
              pkgs.vscode-marketplace.golang.go
              pkgs.vscode-marketplace.griimick.vhs
              pkgs.vscode-marketplace.hoovercj.vscode-power-mode
              pkgs.vscode-marketplace.ismoh-games.second-local-lua-debugger-vscode
              pkgs.vscode-marketplace.jdemille.debian-control-vscode
              pkgs.vscode-marketplace.jeff-hykin.better-csv-syntax
              pkgs.vscode-marketplace.jeff-hykin.better-dockerfile-syntax
              pkgs.vscode-marketplace.jeff-hykin.better-nix-syntax
              pkgs.vscode-marketplace.jeff-hykin.better-shellscript-syntax
              pkgs.vscode-marketplace.jeff-hykin.polacode-2019
              pkgs.vscode-marketplace.jeroen-meijer.pubspec-assist
              pkgs.vscode-marketplace.jnoortheen.nix-ide
              pkgs.vscode-marketplace.johnnymorganz.stylua
              pkgs.vscode-marketplace.marp-team.marp-vscode
              pkgs.vscode-marketplace.mechatroner.rainbow-csv
              pkgs.vscode-marketplace.mkhl.direnv
              pkgs.vscode-marketplace.ms-python.debugpy
              pkgs.vscode-marketplace.ms-python.python
              pkgs.vscode-marketplace.ms-python.vscode-pylance
              pkgs.vscode-marketplace.ms-vscode.cmake-tools
              pkgs.vscode-marketplace.ms-vscode.hexeditor
              pkgs.vscode-extensions.ms-vscode-remote.vscode-remote-extensionpack
              pkgs.vscode-marketplace.nefrob.vscode-just-syntax
              pkgs.vscode-marketplace.nico-castell.linux-desktop-file
              pkgs.vscode-marketplace.pixelbyte-studios.pixelbyte-love2d
              pkgs.vscode-marketplace.pkief.material-product-icons
              pkgs.vscode-marketplace.prince781.vala
              pkgs.vscode-marketplace.pollywoggames.pico8-ls
              pkgs.vscode-marketplace.redhat.vscode-yaml
              pkgs.vscode-marketplace.rogalmic.bash-debug
              pkgs.vscode-marketplace.rust-lang.rust-analyzer
              pkgs.vscode-marketplace.ryu1kn.partial-diff
              pkgs.vscode-marketplace.s3anmorrow.openwithkraken
              pkgs.vscode-marketplace.sanjulaganepola.github-local-actions
              pkgs.vscode-marketplace.saoudrizwan.claude-dev
              pkgs.vscode-marketplace.slevesque.shader
              pkgs.vscode-marketplace.streetsidesoftware.code-spell-checker
              pkgs.vscode-marketplace.tamasfe.even-better-toml
              pkgs.vscode-marketplace.timonwong.shellcheck
              pkgs.vscode-marketplace.trond-snekvik.simple-rst
              pkgs.vscode-marketplace.twxs.cmake
              pkgs.vscode-marketplace.tobiashochguertel.just-formatter
              pkgs.vscode-marketplace.unifiedjs.vscode-mdx
              pkgs.vscode-marketplace.viktorzetterstrom.non-breaking-space-highlighter
              pkgs.vscode-marketplace.vscode-icons-team.vscode-icons
              pkgs.vscode-marketplace.xyc.vscode-mdx-preview
              pkgs.vscode-marketplace.yinfei.luahelper
              pkgs.vscode-marketplace.yzhang.markdown-all-in-one
              pkgs.vscode-marketplace.pinage404.nix-extension-pack
              pkgs.vscode-marketplace.mads-hartmann.bash-ide-vscode
              pkgs.vscode-marketplace.tamasfe.even-better-toml
              pkgs.vscode-marketplace.zainchen.json
              pkgs.vscode-marketplace.eamodio.gitlens
            ]
            ++ lib.optionals isLinux [
              pkgs.vscode-extensions.ms-vscode.cpptools-extension-pack
              pkgs.vscode-extensions.ms-vsliveshare.vsliveshare
              pkgs.vscode-extensions.vadimcn.vscode-lldb
            ];
          };
        };
      };

    persistHome = {
      directories = [
        ".config/VSCodium"
      ];
    };
  };
}
