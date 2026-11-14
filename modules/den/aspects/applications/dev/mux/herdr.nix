{
  den.aspects.applications.dev.mux.herdr = {
    homeLinux =
      { inputs', ... }:
      {
        home.packages = [ inputs'.llm-agents.packages.herdr ];
      };

    # shortcut: llm-agents' herdr fails on darwin. Its vendored libghostty-vt runs
    # tools by absolute path, which the darwin sandbox refuses ("Operation not
    # permitted", "PermissionDenied"): `/bin/cp ... && /usr/bin/ranlib` (LibtoolStep.zig),
    # `/usr/bin/xcrun` for the dylib link (pkg/apple-sdk/native_link.zig) and `/bin/ln`
    # for its symlinks (GhosttyLibVt.zig). Use the build's own tools from PATH instead:
    # xcbuild's xcrun and cctools' ranlib are already darwin inputs, and its
    # libsystem_override.sh calls plain `xcrun` that way already.
    # Remove once llm-agents fixes it.
    homeDarwin =
      { inputs', ... }:
      {
        home.packages = [
          (inputs'.llm-agents.packages.herdr.overrideAttrs (o: {
            postPatch = (o.postPatch or "") + ''
              substituteInPlace vendor/libghostty-vt/src/build/LibtoolStep.zig \
                --replace-fail '"/bin/cp \"$1\" \"$2\" && /usr/bin/ranlib \"$2\""' \
                  '"cp \"$1\" \"$2\" && chmod u+w \"$2\" && ranlib \"$2\""'
              substituteInPlace vendor/libghostty-vt/pkg/apple-sdk/native_link.zig \
                --replace-fail '"/usr/bin/xcrun",' '"xcrun",'
              substituteInPlace vendor/libghostty-vt/src/build/GhosttyLibVt.zig \
                --replace-fail '"/bin/ln",' '"ln",'
            '';
          }))
        ];
      };

    homeManager =
      { inputs', ... }:
      {

        # Source the Claude Code skill straight from the herdr package's own
        # source tree (upstream ships SKILL.md at its root) rather than vendoring
        # a copy in-repo. Inert unless the claude aspect enables programs.claude-code.

        # TODO: Restore at next touch
        # programs.claude-code.skills.herdr = "${inputs'.llm-agents.packages.herdr.src}/SKILL.md";
      };

    # Saved sessions, snapshots and server state.
    persistHome.directories = [
      ".config/herdr"
      ".local/state/herdr"
    ];
  };
}
