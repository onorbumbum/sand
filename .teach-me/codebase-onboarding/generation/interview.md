# Interview — codebase-onboarding

## Transcript

**Q1. Main success outcome?**

User chose: all three, balanced.

Course must onboard:
- a new user to use the app,
- a new developer to understand and modify the codebase,
- a maintainer to debug failures confidently.

**Q2. Assumed level?**

User answered: beginner.

Interpretation:
- Beginner-friendly for Swift/XCTest, CLI tooling, and `sand` product knowledge.
- Do not skip core concepts, but avoid patronizing explanations.

**Q3. Preferred examples/materials?**

User likes the Django tutorial style:
- project-based,
- everything builds on previous steps,
- use repo files and commands,
- include toy examples where useful,
- start with app walkthroughs,
- explain concepts with graphs/mental models before or around code.

**Q4. What should be avoided?**

Avoid wrong timing, not whole categories.

Swift syntax, docs process, architecture theory, and internals are all acceptable when they appear at the right moment and support the current task.

**Q5. Tangible wins?**

By the end, learner should be able to:
- run a Sandbox VM end-to-end,
- map/read/write folders safely,
- run Pi inside `sand`,
- trace a CLI command from router → coordinator → backend,
- add/change a command with tests,
- debug a failing ephemeral run,
- hold a good mental model of what lives where and what modules do,
- feel as if they wrote the thing.

**Q6. Extra materials?**

Only this repo.

**Q7. Web research?**

Local repo is sufficient. Avoid web research.

## Final brief

Build a local-first course for beginner learners that combines app-user onboarding, developer onboarding, and maintainer/debugger onboarding. Use a Django-tutorial-like progression: start by using the product, then explain the mental model, then trace the implementation, then make and verify a small change, then debug realistic failures. The course should use real repo files and commands, with small toy examples only when they clarify a concept before applying it to the real code.
