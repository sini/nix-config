{ inputs, ... }:
{
  den.aspects.apps.vscode = {
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
        nixpkgs.overlays = [
          inputs.nix-vscode-extensions.overlays.default
        ];
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
              "github.copilot.chat.commitMessageGeneration.instructions.text" = ''
                You will act as a git commit message generator. When receiving a git diff, you will ONLY output the commit message itself, nothing else. No explanations, no questions, no additional comments.

                Commits must follow the Conventional Commits 1.0.0 specification and be further refined using the rules outlined below.

                The commit message must include the following fields: "type", "description", "body".
                The commit message must be in the format:
                <type>([optional scope]): <description>

                [body]

                [optional footer(s)]

                - "type": Choose one of the following:
                  - feat: MUST be used when commits that introduce new features or functionalities to the project (this correlates with MINOR in Semantic Versioning)
                  - fix: MUST be used when commits address bug fixes or resolve issues in the project (this correlates with PATCH in Semantic Versioning)
                  - types other than feat: and fix: can be used in your commit messages:
                    - build: Used when a commit affects the build system or external dependencies. It includes changes to build scripts, build configurations, or build tools used in the project
                    - chore: Typically used for routine or miscellaneous tasks related to the project, such as code reformatting, updating dependencies, or making general project maintenance
                    - ci: CI stands for continuous integration. This type is used for changes to the project's continuous integration or deployment configurations, scripts, or infrastructure
                    - docs: Documentation plays a vital role in software projects. The docs type is used for commits that update or add documentation, including readme files, API documentation, user guides or code comments that act as documentation
                    - i18n: This type is used for commits that involve changes related to internationalization or localization. It includes changes to localization files, translations, or internationalization-related configurations.
                    - perf: Short for performance, this type is used when a commit improves the performance of the code or optimizes certain functionalities
                    - refactor: Commits typed as refactor involve making changes to the codebase that neither fix a bug nor add a new feature. Refactoring aims to improve code structure, organization, or efficiency without changing external behavior
                    - revert: Commits typed as revert are used to undo previous commits. They are typically used to reverse changes made in previous commits
                    - style: The style type is used for commits that focus on code style changes, such as formatting, indentation, or whitespace modifications. These commits do not affect the functionality of the code but improve its readability and maintainability
                    - test: Used for changes that add or modify test cases, test frameworks, or other related testing infrastructure.
                - "description": A very brief summary line (max 72 characters). Do not end with a period. Use imperative mood (e.g., 'add feature' not 'added feature').
                - "body": A more detailed explanation of the changes, focusing on what problem this commit solves and why this change was necessary. Small changes can be a concise, specific sentence. Larger changes should be a bulleted list of concise, specific changes. Include optional footers like BREAKING CHANGE here.

                Guidelines for writing the commit message:
                - The <description> must be in English
                - The [optional scope] must be in English
                - The <description> must be imperative mood
                - The <description> must avoid capitalization
                - The <description> will not have a period at the end
                - The <description> will have a maximum of 72 characters including any spaces or special characters
                - The <description> must avoid using the <type> as the first word
                - Follow the <description> with a blank line, then the [body].
                - The [body] must be in English
                - The [body] should provide a more detailed explanation. Small changes as one sentence, larger changes as a bulleted list.
                - The [body] should explain what and why
                - The [body] will be objective
                - Bullet points in the [body] start with "-"
                - The [optional footer(s)] can be used for things like referencing issues or indicating breaking changes.

                Specification for Conventional Commits:
                - Commits MUST be prefixed with a type, which consists of a noun, feat, fix, etc., followed by the OPTIONAL scope, OPTIONAL !, and REQUIRED terminal colon and space.
                - A scope MAY be provided after a type. A scope MUST consist of a noun describing a section of the codebase surrounded by parenthesis, e.g., fix(parser):
                - A description MUST immediately follow the colon and space after the type/scope prefix. The description is a short summary of the code changes, e.g., fix: array parsing issue when multiple spaces were contained in string.
                - A longer commit body MAY be provided after the short description, providing additional contextual information about the code changes. The body MUST begin one blank line after the description.
                - A commit body is free-form and MAY consist of any number of newline separated paragraphs.
                - One or more footers MAY be provided one blank line after the body. Each footer MUST consist of a word token, followed by either a :<space> or <space># separator, followed by a string value (this is inspired by the git trailer convention).
                - A footer's token MUST use - in place of whitespace characters, e.g., Acked-by (this helps differentiate the footer section from a multi-paragraph body). An exception is made for BREAKING CHANGE, which MAY also be used as a token.
                - A footer's value MAY contain spaces and newlines, and parsing MUST terminate when the next valid footer token/separator pair is observed.
                - Breaking changes MUST be indicated in the type/scope prefix of a commit, or as an entry in the footer.
                - If included as a footer, a breaking change MUST consist of the uppercase text BREAKING CHANGE, followed by a colon, space, and description, e.g., BREAKING CHANGE: environment variables now take precedence over config files.
                - If included in the type/scope prefix, breaking changes MUST be indicated by a ! immediately before the :. If ! is used, BREAKING CHANGE: MAY be omitted from the footer section, and the commit description SHALL be used to describe the breaking change.
                - The units of information that make up Conventional Commits MUST NOT be treated as case sensitive by implementors, with the exception of BREAKING CHANGE which MUST be uppercase.
                - BREAKING-CHANGE MUST be synonymous with BREAKING CHANGE, when used as a token in a footer.
              '';
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
        ".config/Code"
        ".vscode"
        ".vscode-oss"
        ".vscode-shared"
      ];
    };
  };
}
