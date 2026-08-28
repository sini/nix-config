# writing-style: Unified suite for conventional commits, GitHub PR descriptions,
# non-obvious code comments, and KEP/RFC design docs.

{ den, ... }:

{
  den.aspects.applications.dev.ai.skills.writing-style = {
    # These skills name other skills in their prose, so the reference has to be
    # structural rather than a hope that whoever enables writing-style also
    # enabled them. writing-doc-design and writing-doc-rfc route figure work to
    # `diagram` and `diagram-mermaid-render`; writing-pr-description routes call
    # paths to `calldiff`, whose aspect ships both the skill and the binary.
    includes = [
      den.aspects.applications.dev.ai.skills.diagram-design
      den.aspects.applications.dev.ai.skills.diagram-mermaid-render
      den.aspects.applications.dev.ai.tools.calldiff
    ];

    agent-extensions = {
      type = "skill";
      skills = {
        writing-commit-message = ./assets/writing-commit-message;
        writing-pr-description = ./assets/writing-pr-description;
        writing-code-comments = ./assets/writing-code-comments;
        writing-doc-design = ./assets/writing-doc-design;
        writing-doc-rfc = ./assets/writing-doc-rfc;
        writing-tone = ./assets/writing-tone;
      };
    };
  };
}
