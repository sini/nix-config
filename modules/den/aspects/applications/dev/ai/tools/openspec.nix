# OpenSpec (github:Fission-AI/OpenSpec): Spec-Driven Development (SDD) framework
# for AI coding assistants. Provides `openspec` CLI, `openspecui` Web UI, and full
# suite of 12 workflow skills built statically via sandboxed CLI execution.
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

        # Sandboxed execution of `openspec init` to produce the full 12 skills
        openspecBundle =
          pkgs.runCommand "openspec-bundle"
            {
              nativeBuildInputs = [
                openspecPkg
                pkgs.nodejs
                pkgs.coreutils
              ];
            }
            ''
              work=$(mktemp -d)
              proj="$work/proj"
              home="$work/home"
              xdg="$work/xdg"
              mkdir -p "$proj" "$home" "$xdg/openspec" "$out"

              cat > "$xdg/openspec/config.json" << 'JSON'
              {
                "featureFlags": {},
                "profile": "custom",
                "delivery": "skills",
                "workflows": ["propose","explore","new","continue","apply","update","ff","sync","archive","bulk-archive","verify","onboard"]
              }
              JSON

              (
                cd "$proj"
                HOME="$home" XDG_CONFIG_HOME="$xdg" CI=true OPENSPEC_TELEMETRY=0 \
                OPENSPEC_NO_COMPLETIONS=1 DO_NOT_TRACK=1 \
                openspec init --tools claude --force --profile custom </dev/null
              )

              cp -r "$proj/.claude/skills"/* "$out/"

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
