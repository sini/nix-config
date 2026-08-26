{ den, ... }:
{
  den.aspects.roles.dev = {
    includes = with den.aspects; [
      hardware.adb
      applications.dev.ai.claude
      applications.dev.ai.tools.beads
      applications.dev.ai.tools.hunk
      applications.dev.ai.tools.rtk
      applications.dev.ai.llm-agents
      applications.dev.ai.skills.caveman
      applications.dev.ai.skills.superpowers
      applications.dev.ai.skills.mattpocock
      applications.dev.ai.skills.gstack
      applications.dev.ai.skills.ponytail
      applications.dev.ai.skills.diagram-design
      applications.dev.ai.skills.ui-ux-pro-max
      applications.dev.ai.skills.one-skill-to-rule-them-all
      applications.dev.ai.mcp.graphify
      applications.dev.ai.mcp.headroom
      applications.dev.ai.mcp.codegraph
      applications.dev.ai.mcp.codebase-memory
      applications.dev.ai.mcp.serena
      applications.dev.ai.pi
      applications.dev.ai.agents.hermes

      applications.shell.nix-index

      applications.dev.editor.nvf

      applications.dev.security.gpg
      applications.dev.security.ssh
      applications.dev.security.bitwarden
      applications.dev.security.ssh-agent-mux
      applications.dev.security.signing-key

      applications.dev.shell.bat
      applications.dev.shell.bottom
      applications.dev.shell.btop
      applications.dev.shell.direnv
      applications.dev.shell.eza
      applications.dev.shell.starship

      applications.shell.yazi
      applications.shell.archive
      applications.shell.data
      applications.shell.disk
      applications.shell.process
      applications.shell.search
      applications.shell.zoxide

      applications.dev.git
      applications.dev.git.delta
      applications.dev.git.github
      applications.dev.git.jujutsu
      applications.dev.git.lazygit
      applications.dev.git.mergiraf

      applications.dev.lang.go
      applications.dev.lang.rust
      applications.dev.lang.python
      applications.dev.lang.nix

      applications.dev.mux.herdr
      applications.dev.mux.sesh
      applications.dev.mux.tmux
      applications.dev.mux.zellij

      applications.dev.k8s.k9s
    ];
  };
}
