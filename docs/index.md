# sand Documentation

This is the web-readable landing page for the `sand` Documentation System. It is intentionally plain Markdown so it works on GitHub or any static Markdown renderer without a documentation site generator.

## Start here

- [Project README](../README.md) — product overview, prerequisites, install instructions, quickstart, and command surface summary.
- [Onboarding Guide](onboarding.md) — first files to read, repo map, and local verification flow for humans and agents.
- [CLI Reference](cli-reference.md) — generated command reference for the v1 `sand` Control Surface.
- [Developer Guide](developer-guide.md) — architecture, testing strategy, command-change workflow, and local Definition of Done.
- [Sandbox VM language](../issues/sand/CONTEXT.md) — canonical domain language for **Sandbox VM**, **Allowed Folder**, **Guest Path**, **Guest State**, **Sandbox Session**, and **Workload Command**.

## Product and v1 delivery docs

- [v1 PRD](../issues/sand/prd-sand-sandbox-vm.md) — product scope, user stories, implementation decisions, testing decisions, and out-of-scope boundaries.
- [Final v1 acceptance evidence](../issues/sand/013-final-v1-acceptance-evidence.md)
- [Final v1 acceptance pass](../issues/sand/013-final-v1-acceptance-pass.md)
- [Documentation Freshness Gate issue](../issues/sand/015-documentation-freshness-gate.md)
- [Documentation Refresh Workflow issue](../issues/sand/016-documentation-refresh-workflow-prompt.md)
- [Generated CLI Reference issue](../issues/sand/017-generated-cli-reference.md)
- [Generated Onboarding Guide issue](../issues/sand/018-generated-onboarding-guide.md)
- [Generated Developer Guide issue](../issues/sand/019-generated-developer-guide.md)
- [README Managed Sections issue](../issues/sand/020-readme-managed-sections.md)
- [Docs landing page and final gate issue](../issues/sand/021-docs-web-landing-and-final-gate.md)

## Document ownership

| Document | Ownership | Notes |
| --- | --- | --- |
| [`README.md`](../README.md) | Section-managed | Human-authored narrative with marked Managed Sections refreshed by the Documentation Refresh Workflow. |
| [`docs/cli-reference.md`](cli-reference.md) | Fully generated | Regenerated from current `sand` help/version output by `scripts/generate-cli-reference.sh`. |
| [`docs/onboarding.md`](onboarding.md) | Generated | Start-here guide refreshed through the Documentation Refresh Workflow. |
| [`docs/developer-guide.md`](developer-guide.md) | Generated | Contributor guide refreshed through the Documentation Refresh Workflow. |
| [`issues/sand/CONTEXT.md`](../issues/sand/CONTEXT.md) | Hand-authored source of truth | Canonical Sandbox VM language and relationships. |
| [`docs/index.md`](index.md) | Hand-authored landing page | Plain Markdown navigation and documentation workflow summary. |
| [`docs/prompts/refresh-docs.md`](prompts/refresh-docs.md) | Hand-authored workflow prompt | Defines the manual agent-run Documentation Refresh Workflow. |

## Refresh docs and check freshness

Generated Documentation records a `docs-input-hash` near the top of each registered document. The hash is computed from [`docs/docs-input-manifest.txt`](docs-input-manifest.txt), which lists the curated source-of-truth inputs for public behavior, command help, tests, scripts, README hand-authored content, and domain language.

When a change affects those inputs:

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

## Final local flow

For agents and humans, the normal completion path is:

1. Change code, tests, scripts, or docs.
2. If the Documentation Input Manifest hash changes, run the Documentation Refresh Workflow and update registered Generated Documentation.
3. Run the full local gate:

   ```sh
   make check
   ```

`make check` runs `swift test` and then `make docs-check`. There is no Bosun dependency in the v1 documentation flow.
