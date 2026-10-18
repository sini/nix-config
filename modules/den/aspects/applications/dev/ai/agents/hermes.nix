# Hermes Agent (https://hermes-agent.nousresearch.com, github:NousResearch/hermes-agent):
# Autonomous terminal AI agent harness configured for local high-context inference.
#
# The CLI, the Electron app and the declarative config all come from upstream's
# own flake, which ships a home-manager module: `services.hermes-agent.settings`
# is a typed deep-merge into HERMES_HOME/config.yaml (mode 0600, a real file, so
# `hermes config set` and the TUI settings panes keep working underneath), and
# enabling the service marks the install managed so `hermes setup` / `config
# edit` refuse to drift away from this file. hermes-hud and hermes-one are
# third-party companions with no upstream packaging, so those two stay on the
# numtide llm-agents collection.
{ den, ... }:
{
  flake-file.inputs.hermes-agent.url = "github:NousResearch/hermes-agent";

  den.aspects.applications.dev.ai.agents.hermes = {
    # ninfer-client admits this host to the inference guest, hyperqwen's port included.
    includes = [
      den.aspects.services.ai.ninfer-client
      den.aspects.services.ai.hyperqwen-client
    ];

    homeManagerModules =
      { inputs', ... }:
      [
        inputs'.hermes-agent.homeManagerModules.default
      ];

    homeManager =
      {
        config,
        host,
        inputs',
        lib,
        ...
      }:
      let
        # The two Electron shells only land where there is a session to draw
        # into: roles.dev also reaches slab, which is a Termux env with no
        # display. The graphical pair is the same one gpg.nix tests against —
        # roles.dev-gui would be wrong here, it is a Linux dev-tools bundle that
        # a Mac workstation never includes.
        hasGui =
          host.hasAspect den.aspects.roles.workstation || host.hasAspect den.aspects.roles.darwin-workstation;

      in
      {
        programs.hermes-agent = {
          enable = true;
          desktop.enable = hasGui;
        };

        services.hermes-agent = {
          enable = true;

          # No messaging gateway — this is a terminal agent, and the unit would
          # need lingering to survive logout.
          gateway.enable = false;

          settings = {
            # hyperqwen is the resident engine on the inference guest (owner,
            # 2026-10-10), as for opencode and pi. A named provider, since only those
            # take `key_cmd`: the key is an agenix secret (services.ai.hyperqwen-client),
            # read at runtime so it never enters the store.
            providers.hyperqwen = {
              name = "HyperQwen (cortex-cuda)";
              api = "http://10.9.2.2:18020/v1";
              transport = "chat_completions";
              key_cmd = "cat ${config.age.secrets.hyperqwen-api-key.path}";
              default_model = "qwen3.8-27b";
              context_length = 150000;
            };
            model = {
              provider = "hyperqwen";
              default = "qwen3.8-27b";
              context_length = 150000;
              max_tokens = 32768;
            };

            # The loaded Qwen3.8 chat template only exposes low/medium/xhigh
            # (plus none); Hermes' minimal/high levels come back 400.
            agent.reasoning_effort = "medium";
          };
        };

        home.packages = [
          inputs'.llm-agents.packages.hermes-hud
        ]
        ++ lib.optionals hasGui [
          inputs'.llm-agents.packages.hermes-one
        ];

        programs.git.ignores = [
          "/.hermes/"
        ];
      };

    persistHome = {
      directories = [
        ".hermes"
      ];
    };
  };
}
