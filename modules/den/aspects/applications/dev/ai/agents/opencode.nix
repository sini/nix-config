# OpenCode (https://opencode.ai):
# Terminal AI coding agent with rich Home Manager configuration, MCP server routing,
# local inference patterning, and declarative skill/subagent deployment.
{ ... }:
{
  den.aspects.applications.dev.ai.agents.opencode = {
    homeManager =
      {
        config,
        inputs',
        lib,
        ninfer-endpoints ? [ ],
        agent-extensions ? { },
        ...
      }:
      let
        # ponytail: first endpoint wins — key by hostname if a second inference host appears.
        ninfer = if ninfer-endpoints == [ ] then null else builtins.head ninfer-endpoints;

        # Extract collected extensions.
        # ★ `agent-extensions` is a LIST (the quirk collects one entry per contributing
        # aspect), so it must be flattened and FOLDED — not attribute-selected. The prior
        # form `agent-extensions.skills or { }` was an attr-select against a list, which
        # silently resolved to the `or` default: opencode received ZERO skills, ZERO
        # subagents and ZERO MCP servers, with no error. claude.nix and antigravity-cli.nix both
        # already fold; this brings opencode onto the same read.
        extensionsList = lib.flatten agent-extensions;
        collectFrom = key: lib.foldl' (acc: e: acc // (e.${key} or { })) { } extensionsList;

        collectedSkills = collectFrom "skills";
        collectedAgents = collectFrom "agents";
        collectedMcp = collectFrom "mcpServers";

        # Unwrap flake input attrsets to pure Nix store paths
        resolveSrc = src: src.outPath or src;

        # Filter invalid MCP attributes
        formatMcpForOpencode =
          mcpMap:
          lib.mapAttrs (
            _: server:
            # A server declaring `url` is remote: there is no process to spawn,
            # so the local shape (which inherits `command`) would fail to
            # evaluate. opencode spells the two forms type=local/remote.
            if server ? url then
              {
                type = "remote";
                inherit (server) url;
              }
            else
              # McpLocalConfig requires `type`, and `command` is ONE array of the
              # executable followed by its arguments — not a command string beside
              # a separate `args`. The env key is `environment`. toList so a server
              # that already states a full argv is not re-wrapped into a nested one.
              {
                type = "local";
                command = lib.toList server.command ++ (server.args or [ ]);
              }
              // lib.optionalAttrs ((server.env or { }) != { }) {
                environment = server.env;
              }
          ) mcpMap;

        # ★ `provider` is a MAP of provider-id -> ProviderConfig, and the id is the
        # key. `baseURL` lives under `options`, and the model is an entry in the
        # provider's `models` map — not a `model` field on the provider. The prior
        # flat `{ name, baseUrl, model }` shape parsed as THREE providers named
        # "name", "baseUrl" and "model", each a bare string where the schema wants
        # an object, and with no top-level `model` there was nothing selected: no
        # provider loaded, no error raised. Same silent shape as the
        # agent-extensions fold above. Checked against opencode's own
        # https://opencode.ai/config.json ($defs/ProviderConfig).
        providerKey = if ninfer != null then "ninfer" else "ollama";
        modelKey = if ninfer != null then ninfer.modelId else "qwen3.8:27b";

        opencodeConfig = {
          "$schema" = "https://opencode.ai/config.json";

          provider.${providerKey} = {
            # A provider that is not in models.dev must name the SDK that speaks
            # to it. openai-compatible is the /v1/chat/completions client, which
            # is what both of these serve (@ai-sdk/openai is for /v1/responses).
            npm = "@ai-sdk/openai-compatible";
            name = if ninfer != null then "NInfer (${ninfer.hostname})" else "Ollama (cortex-cuda)";
            options.baseURL =
              if ninfer != null then
                "http://${ninfer.ip}:${toString ninfer.port}/v1"
              else
                "http://10.9.2.2:11434/v1";
            models.${modelKey} = {
              name = if ninfer != null then "Qwen 3.8 27B (NInfer sm_86, MTP3)" else "Qwen 3.8 27B (Ollama)";
              reasoning = true;
            }
            // lib.optionalAttrs (ninfer != null) {
              # models.dev supplies these for known providers; a custom one has to
              # state them or opencode cannot track remaining context. Both come
              # off the ninfer-endpoints quirk, as they do for pi and hermes.
              limit = {
                context = ninfer.maxContext;
                output = ninfer.maxTokens;
              };
            };
          };

          # `provider-id/model-id`. Without `model` nothing is selected; without
          # `small_model` opencode routes its auxiliary calls to a hosted default
          # (gpt-5-nano on Zen), i.e. off-box — which defeats a local endpoint.
          model = "${providerKey}/${modelKey}";
          small_model = "${providerKey}/${modelKey}";
          permission = {
            bash = "allow";
            edit = "allow";
            read = "allow";
            web_fetch = "allow";
          };
          mcp = formatMcpForOpencode collectedMcp;
        };

        tuiConfig = {
          "$schema" = "https://opencode.ai/tui.json";
          theme = "dark";
        };

        # Convert collected skills to Home Manager file definitions
        skillFiles = lib.mapAttrs' (
          name: src:
          lib.nameValuePair ".config/opencode/skills/${name}" {
            source = resolveSrc src;
          }
        ) collectedSkills;

        # Convert collected subagents to Home Manager file definitions
        agentFiles = lib.mapAttrs' (
          name: src:
          lib.nameValuePair ".config/opencode/agent/${name}.md" {
            source = resolveSrc src;
          }
        ) collectedAgents;
      in
      {
        home.packages = [
          inputs'.llm-agents.packages.opencode
        ];

        programs.git.ignores = [
          "/.opencode/"
        ];

        # Deploy config files, skills, and subagents in single merged home.file block
        home.file = {
          ".config/opencode/opencode.json".text = builtins.toJSON opencodeConfig;
          ".config/opencode/tui.json".text = builtins.toJSON tuiConfig;
        }
        // skillFiles
        // agentFiles;
      };

    persistHome = {
      directories = [
        ".config/opencode"
      ];
    };
  };
}
