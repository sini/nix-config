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

  den.aspects.applications.dev.ai.hermes = {
    homeManagerModules =
      { inputs', ... }:
      [
        inputs'.hermes-agent.homeManagerModules.default
      ];

    homeManager =
      {
        host,
        inputs',
        lib,
        ninfer-endpoints,
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

        # Hermes takes the NInfer engine while pi stays on llama-cpp, so the two
        # agents form the side-by-side comparison on one GPU. Endpoint, model id
        # and the context/output bounds all come off the ninfer-endpoints quirk:
        # NInfer rejects a `model` field that is not its `--model-id`, and its
        # context ceiling is a VRAM-derived property of the server rather than a
        # number a client may assert (Hermes would otherwise probe /v1/models
        # for it).
        # ponytail: first endpoint wins — key by hostname if a second inference
        # host ever appears.
        ninfer = if ninfer-endpoints == [ ] then null else builtins.head ninfer-endpoints;
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
            # `custom` is Hermes' provider class for any OpenAI-compatible
            # endpoint; with a base_url and no credential it resolves the key to
            # "no-key-required", which is what both local servers want.
            model = {
              provider = "custom";
              base_url =
                if ninfer != null then
                  "http://${ninfer.ip}:${toString ninfer.port}/v1"
                else
                  "http://10.9.2.2:8080/v1";
              default = if ninfer != null then ninfer.modelId else "qwen3.8-27b-q4-256k";
              context_length = if ninfer != null then ninfer.maxContext else 262144;
              max_tokens = if ninfer != null then ninfer.maxTokens else 32768;
            };

            # The loaded Qwen3.8 chat template only exposes low/medium/xhigh
            # (plus none); Hermes' minimal/high levels come back 400 from NInfer.
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
