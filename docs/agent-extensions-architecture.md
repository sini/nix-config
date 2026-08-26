# Design Specification: Unified AI Agent Extension Architecture

**Author:** Sini Nix Architecture Team  
**Status:** ACCEPTED  
**Target Path:** `docs/agent-extensions-architecture.md`  
**Date:** 2026-08-26  

---

## 1. Executive Summary

As our AI toolchain expands across multiple agent harnesses (**Claude Code**, **Antigravity IDE**, **Gemini CLI**, **Pi Coding Agent**, **Hermes**, and **OpenSkills**), we require a unified, conflict-free architecture for declaring AI capabilities in Den aspects.

Historically, aspects declared agent-specific options (e.g. `programs.claude-code.mcpServers`, `programs.claude-code.marketplaces`, or hardcoded `home.file.".gemini/config/skills/..."` paths). This created tight coupling, duplicated configurations, and threatened runtime conflicts (such as duplicate stdio MCP process spawning or prompt-cache thrashing).

This document specifies the **Unified AI Agent Extension Architecture** based on a single Den quirk: `agent-extensions`. Every skill, MCP tool, or plugin aspect declares its capabilities **once** under a structured payload, and individual agent harness aspects (`claude.nix`, `gemini.nix`, `pi.nix`, `hermes.nix`) consume and translate these declarations into harness-native runtime configurations.

---

## 2. Problem Statement & Runtime Hazards

### 2.1 The Extension Spectrum
AI capabilities across our fleet fall into three distinct functional shapes:

1. **Universal Markdown Skills (`type = "skill"`)**: Repositories or directories whose primary artifact is one or more `SKILL.md` files (e.g., `gstack`, `hunk-review`, `codebase-memory`, `task-observer`, `diagram-design`).
2. **Stdio MCP Servers (`type = "mcp"`)**: Executable binaries or packages that spawn Model Context Protocol (MCP) stdio servers (e.g., `codebase-memory-mcp`, `codegraph`, `serena-agent`, `headroom-ai`, `graphify-mcp`).
3. **Plugin Marketplace Packages (`type = "plugin"`)**: Full plugin packages containing `.claude-plugin/marketplace.json` or plugin manifests, which bundle event hooks (`SessionStart`, `PreToolUse`, `CwdChanged`), subagents, settings, and embedded skills (e.g., `caveman`, `superpowers`, `mattpocock-skills`, `ponytail`, `ui-ux-pro-max`, `beads-rust`).

### 2.2 Runtime Hazards of Naive Coupling
* **Duplicate Process Spawning**: If an aspect registers a Claude Code plugin marketplace *and* manually declares a standalone `programs.claude-code.mcpServers` entry for the same tool, Claude Code will launch two independent server processes, causing state desynchronization and resource leaks.
* **Conflicting Hooks & Cache Busting**: Double-registering event hooks or tool definitions causes redundant prompt-cache invalidations and execution loops.
* **Non-Claude Incompatibility**: Headless or lightweight agents (Gemini CLI, Antigravity IDE, Pi, Hermes) cannot execute Claude-specific JavaScript/Bash plugin hooks, but **can** consume stdio MCP commands and markdown skills (`SKILL.md`).

---

## 3. Architecture Overview & Data Flow

```
                                 ┌────────────────────────┐
                                 │   Den Aspect (e.g.     │
                                 │   skills/caveman.nix)  │
                                 └───────────┬────────────┘
                                             │
                                             │ Emits `agent-extensions` Quirk
                                             ▼
                                 ┌────────────────────────┐
                                 │  den.quirks.agent-     │
                                 │      extensions        │
                                 └───────────┬────────────┘
                                             │
               ┌─────────────────────────────┼─────────────────────────────┐
               │                             │                             │
               ▼                             ▼                             ▼
   ┌───────────────────────┐     ┌───────────────────────┐     ┌───────────────────────┐
   │  agents/claude.nix    │     │   agents/gemini.nix   │     │  agents/pi/pi.nix     │
   ├───────────────────────┤     ├───────────────────────┤     ├───────────────────────┤
   │ • Marketplaces        │     │ • ~/.gemini/config/   │     │ • ~/.pi/agent/        │
   │ • Enabled Plugins     │     │   skills/<name>/      │     │   extensions/         │
   │ • Native MCP Servers  │     │ • ~/.gemini/config/   │     │ • ~/.pi/agent/        │
   │ • Standalone Skills   │     │   agents/<name>.md    │     │   models.json (MCP)   │
   │ • Subagents/Commands  │     │ • ~/.gemini/config/   │     │                       │
   │ • Context (CLAUDE.md) │     │   rules/GEMINI.md     │     │                       │
   └───────────────────────┘     └───────────────────────┘     └───────────────────────┘
```

### 3.1 Den Quirk Registration
The quirk file is registered at `modules/den/quirks/agent-extensions.nix`:

```nix
{
  den.quirks.agent-extensions.description = "AI agent skills, MCP servers, subagents, commands, and plugin marketplace packages collected from aspects";
}
```

---

## 4. Extension Schema Specification

An aspect emits the `agent-extensions` quirk attribute as a function returning an attrset (or direct attrset) keyed by extension identifier.

### 4.1 Supported Schema Fields

* **`type`** (Required): `"skill"` | `"mcp"` | `"plugin"`.
* **`skills`** (Optional): Attrset of `name -> path/storeSource` containing `SKILL.md`.
* **`mcpServers`** (Optional): Attrset of `name -> { command, args, env }`.
* **`marketplace`** (Optional for `type = "plugin"`): `{ name, src, pluginId, enabled }`.
* **`agents`** (Optional): Attrset of `name -> path` (subagent markdown prompts).
* **`commands`** (Optional): Attrset of `name -> path` (slash command markdown prompts).
* **`context`** (Optional): List or single path/string of shared system rules.

---

### 4.2 Type 1: Universal Skill (`type = "skill"`)
Used for aspects whose primary capability is a directory containing `SKILL.md`.

```nix
den.aspects.applications.dev.ai.skills.diagram-design = {
  agent-extensions = {
    diagram-design = {
      type = "skill";
      skills = {
        diagram-design = inputs.diagram-design;
      };
    };
  };
};
```

---

### 4.3 Type 2: Stdio MCP Server (`type = "mcp"`)
Used for aspects exposing a Model Context Protocol stdio server binary, along with optional companion skills.

```nix
den.aspects.applications.dev.ai.mcp.codegraph = {
  agent-extensions =
    { inputs', ... }:
    {
      codegraph = {
        type = "mcp";
        mcpServers = {
          codegraph = {
            command = "${inputs'.llm-agents.packages.codegraph}/bin/codegraph";
            args = [ "serve" "--mcp" ];
          };
        };
      };
    };

  homeManager = { inputs', ... }: {
    home.packages = [ inputs'.llm-agents.packages.codegraph ];
    programs.git.ignores = [ ".codegraph" ];
  };
};
```

---

### 4.4 Type 3: Plugin Package (`type = "plugin"`)
Used for composite Claude Code plugin marketplace repositories containing `.claude-plugin/marketplace.json` or full plugin manifests.

```nix
den.aspects.applications.dev.ai.skills.caveman = {
  agent-extensions = {
    caveman = {
      type = "plugin";
      marketplace = {
        name = "caveman";
        src = inputs.caveman;
        pluginId = "caveman@caveman";
        enabled = true;
      };
      skills = {
        caveman = inputs.caveman;
      };
    };
  };
};
```

---

## 5. Harness Translation Matrix

Each agent harness aspect receives `agent-extensions` directly as a function argument in `homeManager` or `nixos` and executes clean, non-overlapping translations:

| Extension Field | Claude Code (`agents/claude.nix`) | Antigravity / Gemini CLI (`agents/gemini.nix`) | Pi / Hermes / OpenSkills |
| :--- | :--- | :--- | :--- |
| **`skills`** | Registered in `programs.claude-code.skills.<name>` | Symlinked to `~/.gemini/config/skills/<name>` | Registered in skill search paths |
| **`mcpServers`** | Registered in `programs.claude-code.mcpServers.<name>` (type = "stdio") | Written to `~/.gemini/config/mcp_config.json` & `settings.json` | Emitted into provider config (`models.json`) |
| **`marketplace`** | Registered in `marketplaces.<name>` & `settings.enabledPlugins` | Uses `skills` fallback to link `~/.gemini/config/skills/<name>` | Uses `skills` fallback |
| **`agents`** | Registered in `programs.claude-code.agents` | Symlinked to `~/.gemini/config/agents/<name>.md` | Exposed to agent provider |
| **`commands`** | Registered in `programs.claude-code.commands` | Symlinked to `~/.gemini/config/commands/<name>.md` | Exposed to prompt palette |
| **`context`** | Rendered to `CLAUDE.md` via `programs.claude-code.context` | Written to `~/.gemini/config/rules/GEMINI.md` | Rendered to system prompt |

---

## 6. Detailed Harness Implementations

### 6.1 Claude Code Harness (`modules/den/aspects/applications/dev/ai/agents/claude.nix`)

```nix
homeManager =
  {
    agent-extensions,
    config,
    inputs',
    lib,
    pkgs,
    ...
  }:
  let
    extensionsList = lib.flatten agent-extensions;

    # Collect fields across all extension declarations
    claudeSkills = lib.foldl' (acc: e: if (e ? skills) then acc // e.skills else acc) { } extensionsList;
    claudeAgents = lib.foldl' (acc: e: if (e ? agents) then acc // e.agents else acc) { } extensionsList;
    claudeCommands = lib.foldl' (acc: e: if (e ? commands) then acc // e.commands else acc) { } extensionsList;

    mcpExts = lib.filter (e: e.type or "" == "mcp") extensionsList;
    claudeMcpServers = lib.foldl' (
      acc: e:
      acc // (lib.mapAttrs (_name: server: {
        type = "stdio";
        inherit (server) command;
        args = server.args or [ ];
        env = server.env or { };
      }) (e.mcpServers or { }))
    ) { } mcpExts;

    pluginExts = lib.filter (e: e.type or "" == "plugin") extensionsList;
    claudeMarketplaces = lib.foldl' (
      acc: e: acc // { ${e.marketplace.name} = e.marketplace.src; }
    ) { } pluginExts;
    claudeEnabledPlugins = lib.foldl' (
      acc: e: acc // { ${e.marketplace.pluginId} = e.marketplace.enabled or true; }
    ) { } pluginExts;
  in
  {
    programs.claude-code = {
      enable = true;
      package = inputs'.llm-agents.packages.claude-code;
      mcpServers = claudeMcpServers;
      skills = claudeSkills;
      agents = claudeAgents;
      commands = claudeCommands;

      marketplaces = {
        claude-plugins-official = inputs.claude-plugins-official;
      } // claudeMarketplaces;

      settings = {
        enabledPlugins = {
          "commit-commands@claude-plugins-official" = true;
          "skill-creator@claude-plugins-official" = true;
          "code-simplifier@claude-plugins-official" = true;
          "rust-analyzer-lsp@claude-plugins-official" = true;
        } // claudeEnabledPlugins;
        env = {
          CLAUDE_AUTOCOMPACT_PCT_OVERRIDE = "70";
          CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING = "1";
          CLAUDE_CODE_SUBAGENT_MODEL = "sonnet";
        };
      };
    };
  };
```

---

### 6.2 Antigravity / Gemini CLI Harness (`modules/den/aspects/applications/dev/ai/agents/gemini.nix`)

```nix
homeManager =
  {
    agent-extensions,
    config,
    inputs',
    lib,
    pkgs,
    ...
  }:
  let
    extensionsList = lib.flatten agent-extensions;

    # 1. Skills collection
    allSkillSources = lib.foldl' (acc: e: if (e ? skills) then acc // e.skills else acc) { } extensionsList;
    skillFiles = lib.mapAttrs' (
      name: source:
      lib.nameValuePair ".gemini/config/skills/${name}" { inherit source; }
    ) allSkillSources;

    # 2. Agents collection
    allAgentSources = lib.foldl' (acc: e: if (e ? agents) then acc // e.agents else acc) { } extensionsList;
    agentFiles = lib.mapAttrs' (
      name: source:
      lib.nameValuePair ".gemini/config/agents/${name}.md" { inherit source; }
    ) allAgentSources;

    # 3. Commands collection
    allCommandSources = lib.foldl' (acc: e: if (e ? commands) then acc // e.commands else acc) { } extensionsList;
    commandFiles = lib.mapAttrs' (
      name: source:
      lib.nameValuePair ".gemini/config/commands/${name}.md" { inherit source; }
    ) allCommandSources;

    # 4. MCP Servers
    mcpExts = lib.filter (e: e.type or "" == "mcp") extensionsList;
    allMcpServers = lib.foldl' (acc: e: acc // (e.mcpServers or { })) { } mcpExts;
    mcpConfig = {
      mcpServers = lib.mapAttrs (
        _name: server:
        lib.filterAttrs (_: v: v != [ ] && v != { }) {
          inherit (server) command args env;
        }
      ) allMcpServers;
    };
    mcpJson = (pkgs.formats.json { }).generate "antigravity-mcp-config.json" mcpConfig;
  in
  {
    home.file = skillFiles // agentFiles // commandFiles // {
      ".gemini/config/skills/.keep".text = "";
      ".gemini/config/rules/.keep".text = "";

      ".config/gemini/config.yaml".text = builtins.toJSON {
        model = "gemini-2.5-pro";
        temperature = 0.2;
      };

      ".gemini/config/mcp_config.json".source = mcpJson;
      ".gemini/antigravity/mcp_config.json".source = mcpJson;
      ".gemini/settings.json".source = mcpJson;
      ".config/gemini/settings.json".source = mcpJson;
      ".config/antigravity/mcp_config.json".source = mcpJson;
    };
  };
```
