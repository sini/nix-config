# writing-code-comments: what the rules rest on

Not loaded at invocation. Maintainer's record.

The no-comment default is this project's standing rule. The prose voice comes
from the `writing-tone` skill.

## What was removed from the lifted version

- A citation of `~/.claude/CLAUDE.md`, which **does not exist on this machine**.
- A third-party corpus of 295 PRs and 504 commits, belonging to another author.
- Eight em-dashes in the file's own examples, while the file itself carried the
  rule "No em-dashes for elaboration".

## The gen-library exception is measured

588 comments across `gen-*/lib/*.nix` cite a published result (`Bracha 1990
§2.2`, `Palmer §2.3`, `Leijen 2005 §2`) out of roughly 17,000 comment lines. The
citation habit is real and is a documentation gate, so the blanket no-comment
default would have been wrong for the main codebase.
