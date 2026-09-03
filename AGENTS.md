# Implementation guidance

When a task becomes ambiguous, stop editing and ask a read-only advisor subagent running `gpt-5.6-terra` at medium reasoning effort. Give it the exact evidence, competing approaches, and security constraints; ask for one recommendation and do not allow it to edit the repository. Verify its recommendation against the pinned Paseo source and official Home Assistant documentation before applying it.

