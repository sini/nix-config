# writing-style: Unified suite for conventional commits, GitHub PR descriptions,
# non-obvious code comments, and KEP/RFC design docs.
{
  den.aspects.applications.dev.ai.skills.writing-style = {
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
