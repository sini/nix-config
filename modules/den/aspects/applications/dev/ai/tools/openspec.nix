# OpenSpec (github:Fission-AI/OpenSpec): Spec-Driven Development (SDD) framework
# for AI coding assistants. Provides `openspec` CLI, `openspecui` Web UI, and full
# suite of 12 workflow skills built statically via sandboxed CLI execution.
{
  den.aspects.applications.dev.ai.tools.openspec = {
    agent-extensions =
      { inputs', pkgs, lib, ... }:
      let
        openspecPkg = inputs'.llm-agents.packages.openspec;

        # Sandboxed execution of `openspec init` to produce the full 12 skills
        openspecBundle = pkgs.runCommand "openspec-bundle" {
          nativeBuildInputs = [
            openspecPkg
            pkgs.nodejs
            pkgs.coreutils
          ];
        } ''
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
        '';

        discoverDirectorySkills =
          skillsDir:
          lib.mapAttrs' (name: _: lib.nameValuePair name "${skillsDir}/${name}") (
            lib.filterAttrs (
              name: type: type == "directory" && builtins.pathExists "${skillsDir}/${name}/SKILL.md"
            ) (builtins.readDir skillsDir)
          );

        openspecSkills = discoverDirectorySkills openspecBundle;
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
