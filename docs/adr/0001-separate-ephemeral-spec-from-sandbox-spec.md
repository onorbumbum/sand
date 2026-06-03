# Separate Ephemeral Specs from durable Sandbox Specs

Ephemeral Sandbox Runs use a separate Ephemeral Spec and immutable Ephemeral Run Record rather than adding lifecycle hooks and foreground workload fields to the durable Sandbox Spec. Durable Sandbox Specs describe reusable Sandbox VMs, while Ephemeral Specs describe bounded create-run-stop-hook-delete workflows; keeping them separate avoids making normal lifecycle commands surprising while preserving a record of exactly what ran.

**Considered Options**

- Add lifecycle hooks and workload fields to `~/.sand/specs/<name>.yaml`
- Use a separate Ephemeral Spec plus run records under Host Metadata

**Consequences**

- Normal `create`, `start`, `stop`, `run`, and `shell` behavior remains boring and unchanged.
- Ephemeral history is preserved through run records without keeping completed ephemeral sandboxes as active reusable Sandbox VMs.
