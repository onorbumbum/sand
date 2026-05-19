# Backend error/log validation

Captured 2026-05-19 on this host with Apple `container` CLI 0.12.3.

## Real backend log/error path

Command:

```bash
container logs sand-does-not-exist-011
```

Raw backend stderr:

```text
Error: failed to get logs for container sand-does-not-exist-011 (cause: "internalError: "failed to open container logs: notFound: "container with ID sand-does-not-exist-011 not found""")
```

The same stderr is stored as deterministic fixture:

- `Tests/SandCoreTests/Fixtures/apple-container/missing-runtime-logs.stderr`

Sand translation path verified with:

```bash
swift run sand sand-does-not-exist-011 logs
```

User-facing stderr:

```text
sand: Sandbox VM `sand-does-not-exist-011` was not found. Create it with `sand create sand-does-not-exist-011` before reading logs.
```
