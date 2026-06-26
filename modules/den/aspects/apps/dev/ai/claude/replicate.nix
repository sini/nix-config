{
  # Lives in claude/ (a sibling of the still-single claude.nix, which keeps the
  # blanket persistHome for now); both files merge into the same `claude` aspect
  # via dendritic auto-import. Landed ahead of the claude.nix split (Task 4) so a
  # replicating user exists for the device-identity mint (Task 1).
  den.aspects.apps.dev.ai.claude.replicateHome.directories = [
    ".claude/memory"
    ".claude/projects"
  ];
}
