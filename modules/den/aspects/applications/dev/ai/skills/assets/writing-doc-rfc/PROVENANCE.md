# writing-doc-rfc: what the rules rest on

Not loaded at invocation. Maintainer's record.

The section skeleton is the Rust RFC template (`rust-lang/rfcs`,
`0000-template.md`), with the Rust-specific references dropped: the compiler,
the language, Rust teams, and the rust-lang issue tracker.

## What was removed from the lifted version

- "It is tuned to Roshan's working voice" -- another author.
- A **good** example whose open question was framed as a decision contract
  (`Owner: … · By: … · Done when: …`), carrying another person's handle as the
  owner. That apparatus appears zero times in this author's measured corpus and
  was presented as the shape to imitate. Replaced with the plain-sentence form.
- The same `Owner:/By:/Done when:` template in Unresolved questions.
- `<!-- include: doc-voice.md -->` and `<!-- include: doc-destination.md -->`,
  **neither of which exists anywhere in this repository**.
- Notion and `.sysinit/` as doc destinations.
- Em-dashes in the template lines.
