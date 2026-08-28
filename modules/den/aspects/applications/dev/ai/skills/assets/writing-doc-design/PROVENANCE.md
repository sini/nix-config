# writing-doc-design: what the rules rest on

Not loaded at invocation. Maintainer's record.

The section skeleton is the Kubernetes KEP template
(`kubernetes/enhancements`, `keps/NNNN-kep-template`), with the
Kubernetes-specific machinery dropped: release signoff, graduation criteria,
version skew, the production-readiness questionnaire, and feature gates.

## What was removed from the lifted version

- "It is tuned to Roshan's working voice" -- another author. The voice now comes
  from the `writing-tone` skill.
- `<!-- include: doc-voice.md -->` and `<!-- include: doc-destination.md -->`,
  **neither of which exists anywhere in this repository**. The skill had been
  shipping with no voice or destination guidance at all.
- Notion and `.sysinit/` as doc destinations. Replaced with the verified
  `den-ag-design` layout.
- Em-dashes in the template lines.
