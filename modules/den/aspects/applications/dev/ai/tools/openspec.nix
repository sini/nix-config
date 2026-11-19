# OpenSpec (github:Fission-AI/OpenSpec): Spec-Driven Development (SDD) framework
# for AI coding assistants. Provides `openspec` CLI, `openspecui` Web UI, and full
# suite of 12 workflow skills generated at build time by its own skill generator.
{
  den.aspects.applications.dev.ai.tools.openspec = {
    agent-extensions =
      {
        inputs',
        pkgs,
        lib,
        ...
      }:
      let
        openspecPkg = inputs'.llm-agents.packages.openspec;

        # Declared, not read from the bundle: readDir on it is IFD, which forces the
        # bundle to build for the host platform at eval time (a darwin host then needs
        # a darwin builder just to evaluate). The bundle build checks this list.
        skillNames = [
          "openspec-apply-change"
          "openspec-archive-change"
          "openspec-bulk-archive-change"
          "openspec-continue-change"
          "openspec-explore"
          "openspec-ff-change"
          "openspec-new-change"
          "openspec-onboard"
          "openspec-propose"
          "openspec-sync-specs"
          "openspec-update-change"
          "openspec-verify-change"
        ];

        # The skills, written by openspec's own generator. `openspec init` fetches them
        # from GitHub with git (2.x), which the sandbox cannot reach, and then checks
        # each fetched SKILL.md equals what expectedSkillContents generates; this
        # writes that content directly.
        openspecBundle =
          pkgs.runCommand "openspec-bundle"
            {
              nativeBuildInputs = [
                pkgs.nodejs
                pkgs.coreutils
              ];
              pkgDir = "${openspecPkg}/lib/node_modules/@fission-ai/openspec";
            }
            ''
              mkdir -p "$out"
              node --input-type=module -e '
                import { readFileSync, mkdirSync, writeFileSync } from "node:fs";
                const dir = process.env.pkgDir, out = process.env.out;
                const { version } = JSON.parse(readFileSync(dir + "/package.json", "utf8"));
                const { expectedSkillContents } = await import(dir + "/dist/core/skill-installer.js");
                for (const [name, content] of expectedSkillContents(version)) {
                  mkdirSync(out + "/" + name, { recursive: true });
                  writeFileSync(out + "/" + name + "/SKILL.md", content);
                }
              '

              actual=$(cd "$out" && for d in */; do [ -f "$d/SKILL.md" ] && echo "''${d%/}"; done | sort)
              expected=$(printf '%s\n' ${lib.escapeShellArgs skillNames} | sort)
              if [ "$actual" != "$expected" ]; then
                echo "openspec skill set drifted from skillNames:" >&2
                diff <(echo "$expected") <(echo "$actual") >&2
                exit 1
              fi
            '';

        openspecSkills = lib.genAttrs skillNames (name: "${openspecBundle}/${name}");
      in
      {
        type = "skill";
        skills = openspecSkills;
      };

    homeManager =
      { inputs', ... }:
      {
        home.packages = [
          inputs'.llm-agents.packages.openspec
          inputs'.llm-agents.packages.openspecui
        ];

        programs.claude-code = {
          settings.permissions.allow = [
            "Bash(openspec *)"
            "Bash(openspecui *)"
          ];
        };
      };
  };
}
