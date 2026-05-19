# Documentation Refresh Workflow Prompt

You are refreshing `sand` Generated Documentation. `sand` manages **Sandbox VMs** on a **Host Mac** with explicit **Allowed Folders**, **Guest State**, and generic **Workload Commands**. Use the domain language in `issues/sand/CONTEXT.md` exactly.

This workflow is manual and agent-run for v1. It must not require Bosun, network access, or a separate LLM quality gate.

## Required inputs

Read these files first:

1. `docs/docs-input-manifest.txt` — the **Documentation Input Manifest**.
2. `docs/generated-docs-manifest.txt` — the registry of **Generated Documentation** to refresh/check.
3. Every required existing file listed in the Documentation Input Manifest.
4. Every optional file listed in the Documentation Input Manifest when it exists.
5. Every generated document listed in `docs/generated-docs-manifest.txt` when it already exists, so preserved human-authored sections are not lost.

Compute the current docs input hash before editing:

```sh
scripts/docs-input-hash.sh docs/docs-input-manifest.txt
```

Use that exact hash value as the recorded freshness metadata in every registered generated document you refresh.

## Source-of-truth rules

- Public behavior comes from executable specs, CLI parser/application code, actual `sand` help output, and the domain language file.
- Prefer real `sand --help`, `sand <command> --help`, and `sand <name> --help` output when producing command examples or option lists. If the binary cannot be built or run, derive the command surface from command definitions and tests, and say so in the evidence.
- Do not invent features. If source files and tests disagree, document the conflict in your final evidence and do not guess.
- Use **Sandbox VM**, **Allowed Folder**, **Guest Path**, **Guest State**, **Runtime Instance**, **Sandbox Session**, **Workload Command**, and other terms from `issues/sand/CONTEXT.md`.
- Avoid banned or misleading terms from the context file, such as generic Docker/container wording for user-facing product concepts.
- The docs website is published from the repository `docs/` directory. Links from pages under `docs/` must not point to `../README.md` or `../issues/...` because those files are outside the GitHub Pages source and will 404. Use repository links such as `https://github.com/onorbumbum/sand/blob/main/README.md` for files outside `docs/`, or link to a site-visible page under `docs/`.

## Metadata conventions

Each registered generated Markdown document must record the current docs input hash near the top of the file using one of these forms:

```md
<!-- docs-input-hash: <64-character-sha256> -->
```

or, when YAML front matter is already present:

```yaml
docs_input_hash: <64-character-sha256>
```

Prefer the HTML comment for Markdown documents without front matter. Keep the recorded hash in exactly one obvious place per document.

Recommended metadata block for generated Markdown without front matter:

```md
<!-- generated-doc: true -->
<!-- generated-by: docs/prompts/refresh-docs.md -->
<!-- docs-input-hash: <64-character-sha256> -->
```

For section-managed documents, place document-level freshness metadata near the top of the file, outside any managed section.

## Managed Section conventions

A **Managed Section** is the only region that this workflow may replace inside a section-managed document. Use explicit HTML markers:

```md
<!-- docs:managed:start id="stable-section-id" source="brief source description" -->
Generated content goes here.
<!-- docs:managed:end -->
```

Rules:

- Preserve the markers.
- Replace only the content between matching `docs:managed:start` and `docs:managed:end` markers.
- Do not overwrite unmarked human-authored prose.
- Use stable, lowercase, hyphenated `id` values.
- Keep one logical topic per Managed Section.
- If a required Managed Section is missing, add the smallest section needed and note it in evidence.

`README.md` is section-managed. Never regenerate or overwrite the full README.

## Documents to refresh

Refresh every non-comment path listed in `docs/generated-docs-manifest.txt`.

Expected v1 Generated Documentation set:

- `README.md` — section-managed. Preserve human-authored sections and update only Managed Sections plus freshness metadata.
- `docs/cli-reference.md` — fully generated from real `sand` help output when available, or from command definitions/tests when help output cannot be produced.
- `docs/onboarding.md` — may combine generated Managed Sections with preserved human-authored sections.
- `docs/developer-guide.md` — may combine generated Managed Sections with preserved human-authored sections.

If a listed document does not exist yet, create it according to these conventions. If `docs/generated-docs-manifest.txt` has no registered documents yet, do not invent registry entries unless the current issue explicitly asks for them.

## Refresh procedure

1. Read the manifests and all relevant source, test, script, README, and existing docs files listed above.
2. Compute the current docs input hash.
3. Build `sand` if needed to obtain real help output.
4. Refresh each registered generated document using the document-specific rules.
5. Record the current docs input hash in every refreshed registered document.
6. Preserve human-authored sections and Managed Section markers exactly where required.
7. Run verification:

```sh
make docs-check
swift test
```

8. In your final evidence, include:
   - the docs input hash used,
   - documents refreshed,
   - whether CLI reference content came from real help output or command definitions/tests,
   - verification commands and results,
   - any conflicts or skipped documents.

## Constraints

- No Bosun requirement.
- No network access requirement.
- No external LLM review or quality gate.
- Generated Documentation must be committed human-facing documentation, not ephemeral output.
- The Documentation Freshness Gate must remain deterministic and cheap.
