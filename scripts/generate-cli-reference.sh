#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
output_path="${1:-${repo_root}/docs/cli-reference.md}"
manifest_path="${DOCS_INPUT_MANIFEST:-${repo_root}/docs/docs-input-manifest.txt}"

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

current_hash="$("$script_dir/docs-input-hash.sh" "$manifest_path")"
version_output="$(capture_sand --version)"
top_help="$(capture_sand --help)"
doctor_help="$(capture_sand doctor --help)"
create_help="$(capture_sand create --help)"
list_help="$(capture_sand list --help)"
apply_help="$(capture_sand apply --help)"
delete_help="$(capture_sand delete --help)"
folders_help="$(capture_sand folders --help)"
signing_help="$(capture_sand signing --help)"
status_help="$(capture_sand status --help)"
start_help="$(capture_sand start --help)"
stop_help="$(capture_sand stop --help)"
shell_help="$(capture_sand shell --help)"
run_help="$(capture_sand run --help)"
logs_help="$(capture_sand logs --help)"
spec_help="$(capture_sand spec --help)"

mkdir -p "$(dirname "$output_path")"

cat > "$output_path" <<EOF
<!-- generated-doc: true -->
<!-- generated-by: scripts/generate-cli-reference.sh -->
<!-- docs-input-hash: $current_hash -->

# sand CLI Reference

> Fully generated documentation. Do not hand-edit this file outside the Documentation Refresh Workflow. Regenerate it with \`scripts/generate-cli-reference.sh\` so usage stays aligned with actual \`sand\` help output.

This reference captures the v1 **API Surface** for managing **Sandbox VMs**, **Allowed Folders**, **Sandbox Sessions**, and generic **Workload Commands**.

## Generation source

- Docs input hash: \`$current_hash\`
- Generator: \`scripts/generate-cli-reference.sh\`
- Help source command: \`$sand_source_description\`
- Usage sections below are captured from actual \`sand --help\`, \`sand <command> --help\`, and \`sand --version\` output.

## Supported v1 command surface

- Global: \`sand --help\`, \`sand --version\`
- Top-level commands: \`doctor\`, \`create\`, \`list\`, \`apply\`, \`delete\`, \`folders\`, \`signing\`, \`status\`, \`start\`, \`stop\`, \`shell\`, \`run\`, \`logs\`, \`spec\`

## Current v1 boundaries

The v1 command surface is intentionally explicit and small:

- To clear a Sandbox VM completely, delete it and create a new one.
- To run Pi, use the same command shape as any other tool: \`sand run <name> pi [args...]\`.
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

## \`sand signing\`

\`\`\`text
$signing_help
\`\`\`

## \`sand status\`

\`\`\`text
$status_help
\`\`\`

## \`sand start\`

\`\`\`text
$start_help
\`\`\`


## \`sand stop\`


\`\`\`text
$stop_help
\`\`\`

## \`sand shell\`


\`\`\`text
$shell_help
\`\`\`

## \`sand run\`


\`\`\`text
$run_help
\`\`\`

## \`sand logs\`

\`\`\`text
$logs_help
\`\`\`

## \`sand spec\`


\`\`\`text
$spec_help
\`\`\`
EOF

rel_path="${output_path#${repo_root}/}"
echo "generated $rel_path with docs input hash $current_hash"
