# sand Documentation

`sand` gives Pi and other developer tools a safer place to work: a small Linux environment on your Mac with its own persistent state and only the project folders you choose to expose.

The short version:

1. Create a named Sandbox VM.
2. Add the Host Mac folders it is allowed to see.
3. Run Pi, a shell, or another command inside that sandbox.
4. Stop and start it without losing the guest setup.
5. Delete it when the workspace is no longer needed.

## Start here

- [Project README](https://github.com/onorbumbum/sand/blob/main/README.md) — best first read for why `sand` exists, what it solves, prerequisites, install instructions, and a quickstart.
- [CLI Reference](cli-reference.md) — exact command shapes and examples for creating sandboxes, adding folders, running commands, and inspecting state.
- [Onboarding Guide](onboarding.md) — orientation for humans and AI agents changing the project.
- [Developer Guide](developer-guide.md) — architecture, tests, command-change workflow, and local Definition of Done.
- [Sandbox VM language](https://github.com/onorbumbum/sand/blob/main/issues/sand/CONTEXT.md) — builder-facing product vocabulary used to keep implementation and documentation consistent.

## Product and v1 delivery docs

- [v1 PRD](https://github.com/onorbumbum/sand/blob/main/issues/sand/prd-sand-sandbox-vm.md) — product scope, user stories, implementation decisions, testing decisions, and out-of-scope boundaries.
- [Final v1 acceptance evidence](https://github.com/onorbumbum/sand/blob/main/issues/sand/013-final-v1-acceptance-evidence.md)
- [Final v1 acceptance pass](https://github.com/onorbumbum/sand/blob/main/issues/sand/013-final-v1-acceptance-pass.md)
- [Documentation Freshness Gate issue](https://github.com/onorbumbum/sand/blob/main/issues/sand/015-documentation-freshness-gate.md)
- [Documentation Refresh Workflow issue](https://github.com/onorbumbum/sand/blob/main/issues/sand/016-documentation-refresh-workflow-prompt.md)
- [Generated CLI Reference issue](https://github.com/onorbumbum/sand/blob/main/issues/sand/017-generated-cli-reference.md)
- [Generated Onboarding Guide issue](https://github.com/onorbumbum/sand/blob/main/issues/sand/018-generated-onboarding-guide.md)
- [Generated Developer Guide issue](https://github.com/onorbumbum/sand/blob/main/issues/sand/019-generated-developer-guide.md)
- [README Managed Sections issue](https://github.com/onorbumbum/sand/blob/main/issues/sand/020-readme-managed-sections.md)
- [Docs landing page and final gate issue](https://github.com/onorbumbum/sand/blob/main/issues/sand/021-docs-web-landing-and-final-gate.md)

## Document ownership

| Document | Ownership | Notes |
| --- | --- | --- |
| [`README.md`](https://github.com/onorbumbum/sand/blob/main/README.md) | Section-managed | Human-authored product narrative with generated factual sections for command examples and local checks. |
| [`docs/cli-reference.md`](cli-reference.md) | Fully generated | Regenerated from current `sand` help/version output by `scripts/generate-cli-reference.sh`. |
| [`docs/onboarding.md`](onboarding.md) | Generated | Start-here guide for humans and AI agents working on the project. |
| [`docs/developer-guide.md`](developer-guide.md) | Generated | Contributor guide for architecture, tests, command changes, and Definition of Done. |
| [`issues/sand/CONTEXT.md`](https://github.com/onorbumbum/sand/blob/main/issues/sand/CONTEXT.md) | Hand-authored source of truth | Canonical Sandbox VM language and relationships. |
| [`docs/index.md`](index.md) | Hand-authored landing page | Plain Markdown navigation and documentation workflow summary. |
| [`docs/prompts/refresh-docs.md`](prompts/refresh-docs.md) | Hand-authored workflow prompt | Defines the manual agent-run Documentation Refresh Workflow. |

## Refresh docs and check freshness

The docs are primarily onboarding and working instructions. The refresh machinery is a guardrail that keeps those instructions from drifting after public behavior changes.

Generated/managed docs record a `docs-input-hash` near the top of each registered document. The hash is computed from [`docs/docs-input-manifest.txt`](docs-input-manifest.txt), which lists the curated source-of-truth inputs for public behavior, command help, tests, scripts, README hand-authored content, and domain language.

When a change affects those inputs and has Documentation Impact:

1. Refresh docs using [`docs/prompts/refresh-docs.md`](prompts/refresh-docs.md).
2. Regenerate the CLI Reference when command help or version output changes:

   ```sh
   scripts/generate-cli-reference.sh
   ```

3. Check registered Generated Documentation:

   ```sh
   make docs-check
   ```

`make docs-check` runs `scripts/docs-check.sh`, recomputes the current docs input hash, and fails when any registered generated or section-managed document has missing or stale hash metadata. The registered v1 Generated Documentation set lives in [`docs/generated-docs-manifest.txt`](generated-docs-manifest.txt): `README.md`, `docs/cli-reference.md`, `docs/onboarding.md`, and `docs/developer-guide.md`.

## Publish on GitHub Pages

The fastest hosted docs path is GitHub Pages from the committed `docs/` directory:

1. Keep this documentation source in `docs/`.
2. Keep [`docs/_config.yml`](_config.yml) as the minimal Jekyll config.
3. In GitHub, choose **Settings → Pages → Deploy from branch → `main` / `docs`**.

No npm, MkDocs, VitePress, Bosun workflow, or separate generated website is required for v1.

## Final local flow

For agents and humans, the normal completion path is:

1. Understand the task, product language, relevant code, and tests.
2. Change code, tests, scripts, or docs.
3. If the change has Documentation Impact and the Documentation Input Manifest hash changes, run the Documentation Refresh Workflow and update registered generated/managed docs.
4. Run the full local gate:

   ```sh
   make check
   ```

`make check` runs `swift test` and then `make docs-check`. There is no Bosun dependency in the v1 documentation flow.
