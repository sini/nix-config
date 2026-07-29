{
  den.aspects.applications.dev.editor.codium.core = {
    nixpkgs-overlays =
      { inputs', ... }:
      [ inputs'.nix-vscode-extensions.overlays.default ];

    homeManager =
      {
        lib,
        pkgs,
        ...
      }:
      {
        home.packages = [
          pkgs.prettier
        ];
      };

    codium-settings = [
      {
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
        "claudeCode.preferredLocation" = "panel";
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
        "extensions.autoCheckUpdates" = false;
        "extensions.ignoreRecommendations" = true;
        "[xml]"."editor.defaultFormatter" = "DotJoshJohnson.xml";
        "files.insertFinalNewline" = true;
        "files.trimTrailingWhitespace" = true;
        "git.openRepositoryInParentFolders" = "always";
        "github.copilot.chat.agent.thinkingTool" = true;
        "github.copilot.chat.codesearch.enabled" = true;
        "githubPullRequests.pullBranch" = "never";
        "partialDiff.enableTelemetry" = false;
        "projectManager.git" = {
          baseFolders = [
            "~/repos"
          ];
          maxDepthRecursion = 5;
        };
        "redhat.telemetry.enabled" = false;
        "security.workspace.trust.untrustedFiles" = "open";
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
      }
    ];

    codium-extensions =
      { pkgs, ... }:
      [
        pkgs.vscode-marketplace.aaron-bond.better-comments
        pkgs.vscode-marketplace.alefragnani.project-manager
        pkgs.vscode-marketplace.anthropic.claude-code
        pkgs.vscode-marketplace.automatalabs.copilot-mcp
        pkgs.vscode-marketplace.catppuccin.catppuccin-vsc-icons
        pkgs.vscode-marketplace.codezombiech.gitignore
        pkgs.vscode-marketplace.coolbear.systemd-unit-file
        pkgs.vscode-marketplace.dotjoshjohnson.xml
        pkgs.vscode-marketplace.editorconfig.editorconfig
        pkgs.vscode-marketplace.esbenp.prettier-vscode
        pkgs.vscode-marketplace.evan-buss.font-switcher
        pkgs.vscode-marketplace.fill-labs.dependi
        pkgs.vscode-marketplace.github.copilot
        pkgs.vscode-marketplace-release.github.copilot-chat
        pkgs.vscode-marketplace.github.vscode-github-actions
        pkgs.vscode-marketplace-release.github.vscode-pull-request-github
        pkgs.vscode-marketplace.griimick.vhs
        pkgs.vscode-marketplace.hoovercj.vscode-power-mode
        pkgs.vscode-marketplace.jdemille.debian-control-vscode
        pkgs.vscode-marketplace.jeff-hykin.better-csv-syntax
        pkgs.vscode-marketplace.jeff-hykin.better-dockerfile-syntax
        pkgs.vscode-marketplace.jeroen-meijer.pubspec-assist
        pkgs.vscode-marketplace.mechatroner.rainbow-csv
        pkgs.vscode-marketplace.mkhl.direnv
        pkgs.vscode-extensions.ms-vscode-remote.vscode-remote-extensionpack
        pkgs.vscode-marketplace.nefrob.vscode-just-syntax
        pkgs.vscode-marketplace.nico-castell.linux-desktop-file
        pkgs.vscode-marketplace.pkief.material-product-icons
        pkgs.vscode-marketplace.redhat.vscode-yaml
        pkgs.vscode-marketplace.ryu1kn.partial-diff
        pkgs.vscode-marketplace.s3anmorrow.openwithkraken
        pkgs.vscode-marketplace.sanjulaganepola.github-local-actions
        pkgs.vscode-marketplace.saoudrizwan.claude-dev
        pkgs.vscode-marketplace.streetsidesoftware.code-spell-checker
        pkgs.vscode-marketplace.tamasfe.even-better-toml
        pkgs.vscode-marketplace.trond-snekvik.simple-rst
        pkgs.vscode-marketplace.tobiashochguertel.just-formatter
        pkgs.vscode-marketplace.viktorzetterstrom.non-breaking-space-highlighter
        pkgs.vscode-marketplace.vscode-icons-team.vscode-icons
        pkgs.vscode-marketplace.zainchen.json
        pkgs.vscode-marketplace.eamodio.gitlens
      ];
  };
}
