#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
output_path="${1:-$repo_root/docs/cli-reference.md}"
manifest_path="${DOCS_INPUT_MANIFEST:-$repo_root/docs/docs-input-manifest.txt}"

if [[ "$manifest_path" != /* ]]; then
  manifest_path="$repo_root/$manifest_path"
fi

if [[ -n "${SAND_DOCS_BIN:-}" ]]; then
  sand_command=("$SAND_DOCS_BIN")
  sand_source_description="$SAND_DOCS_BIN"
else
  sand_command=(swift run --package-path "$repo_root" sand)
  sand_source_description="swift run --package-path <repo> sand"
fi

capture_sand() {
  "${sand_command[@]}" "$@"
}

current_hash="$($script_dir/docs-input-hash.sh "$manifest_path")"
version_output="$(capture_sand --version)"
top_help="$(capture_sand --help)"
doctor_help="$(capture_sand doctor --help)"
create_help="$(capture_sand create --help)"
ephemeral_help="$(capture_sand ephemeral --help)"
list_help="$(capture_sand list --help)"
apply_help="$(capture_sand apply --help)"
delete_help="$(capture_sand delete --help)"
folders_help="$(capture_sand folders --help)"
sandbox_help="$(capture_sand example --help)"

mkdir -p "$(dirname "$output_path")"

cat > "$output_path" <<EOF
<!-- generated-doc: true -->
<!-- generated-by: scripts/generate-cli-reference.sh -->
<!-- docs-input-hash: $current_hash -->

# sand CLI Reference

> Fully generated documentation. Do not hand-edit this file outside the Documentation Refresh Workflow. Regenerate it with \`scripts/generate-cli-reference.sh\` so usage stays aligned with actual \`sand\` help output.

This reference captures the v1 **Control Surface** for managing **Sandbox VMs**, **Allowed Folders**, **Sandbox Sessions**, and generic **Workload Commands**.

## Generation source

- Docs input hash: \`$current_hash\`
- Generator: \`scripts/generate-cli-reference.sh\`
- Help source command: \`$sand_source_description\`
- Usage sections below are captured from actual \`sand --help\`, \`sand <command> --help\`, \`sand <name> --help\`, and \`sand --version\` output.

## Supported v1 command surface

- Global: \`sand --help\`, \`sand --version\`
- Top-level commands: \`doctor\`, \`create\`, \`ephemeral --from <spec.yaml> [-- <command> [args...]]\`, \`list\`, \`apply\`, \`delete\`, \`folders\`
- Sandbox-first actions: \`sand <name> status\`, \`start\`, \`stop\`, \`shell\`, \`run <command> [args...]\`, \`logs\`, \`spec\`

## Current v1 boundaries

The v1 command surface is intentionally explicit and small:

- To clear a Sandbox VM completely, delete it and create a new one.
- To run Pi, use the same command shape as any other tool: \`sand <name> run pi [args...]\`.
- Network access is outbound-only from the Sandbox VM in v1; inbound browser/server callbacks need a handoff flow outside the command surface.
- Commands name the target Sandbox VM explicitly, so it is always clear which environment you are operating.

## \`sand --version\`

\`\`\`text
$version_output
\`\`\`

## \`sand --help\`

\`\`\`text
$top_help
\`\`\`

## \`sand doctor\`

\`\`\`text
$doctor_help
\`\`\`

## \`sand create\`

\`\`\`text
$create_help
\`\`\`

## \`sand ephemeral\`

\`\`\`text
$ephemeral_help
\`\`\`

## Ephemeral Spec lifecycle hooks

Ephemeral Specs may omit Host Mac lifecycle hook lists or provide empty lists with \`beforeProvision: []\` and \`afterStop: []\`. Hook entries use the same structured command shape as a Foreground Workload: a non-empty \`command\` plus optional \`args\`.

\`\`\`yaml
beforeProvision:
  - command: mkdir
    args:
      - -p
      - work
afterStop:
  - command: archive-output
    args:
      - work/output.txt
\`\`\`

\`beforeProvision\` hooks run on the Host Mac before Allowed Folder resolution and provisioning. \`afterStop\` hooks run on the Host Mac after the Foreground Workload exits and after \`sand\` attempts to stop the Sandbox VM, including when the workload exits nonzero or the stop attempt fails. Hook output is captured in the Ephemeral Run Record. A failing \`afterStop\` hook stops remaining after-stop hooks, but delete is still attempted.

## \`sand list\`

\`\`\`text
$list_help
\`\`\`

## \`sand apply\`

\`\`\`text
$apply_help
\`\`\`

## \`sand delete\`

\`\`\`text
$delete_help
\`\`\`

## \`sand folders\`

\`\`\`text
$folders_help
\`\`\`

## Sandbox-first actions

Use \`sand <name> --help\` to print the supported Sandbox Session and lifecycle actions for a named **Sandbox VM**.

\`\`\`text
$sandbox_help
\`\`\`
EOF

echo "generated ${output_path#"$repo_root/"} with docs input hash $current_hash"
