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
bootstrap_help="$(capture_sand bootstrap --help)"
delete_help="$(capture_sand delete --help)"
folders_help="$(capture_sand folders --help)"
signing_help="$(capture_sand signing --help)"
status_help="$(capture_sand status --help)"
start_help="$(capture_sand start --help)"
stop_help="$(capture_sand stop --help)"
shell_help="$(capture_sand shell --help)"
run_help="$(capture_sand run --help)"
gui_help="$(capture_sand gui --help)"
logs_help="$(capture_sand logs --help)"
spec_help="$(capture_sand spec --help)"

mkdir -p "$(dirname "$output_path")"

cat > "$output_path" <<EOF
<!-- generated-doc: true -->
<!-- generated-by: scripts/generate-cli-reference.sh -->
<!-- docs-input-hash: $current_hash -->

# sand CLI Reference

> Fully generated documentation. Do not hand-edit this file outside the Documentation Refresh Workflow. Regenerate it with \`scripts/generate-cli-reference.sh\` so usage stays aligned with actual \`sand\` help output.

This reference captures the v1 **API Surface** for managing Linux and macOS **Sandbox VMs**, **Shared Folders**, **Sandbox Sessions**, and generic **Workload Commands**.

## Generation source

- Docs input hash: \`$current_hash\`
- Generator: \`scripts/generate-cli-reference.sh\`
- Help source command: \`$sand_source_description\`
- Usage sections below are captured from actual \`sand --help\`, \`sand <command> --help\`, and \`sand --version\` output.

## Supported v1 command surface

- Global: \`sand --help\`, \`sand --version\`
- Top-level commands: \`doctor\`, \`create\`, \`bootstrap\`, \`list\`, \`apply\`, \`delete\`, \`folders\`, \`signing\`, \`status\`, \`start\`, \`stop\`, \`shell\`, \`run\`, \`gui\`, \`logs\`, \`spec\`

## Current v1 boundaries

The v1 command surface is intentionally explicit and small:

- To clear a Sandbox VM completely, delete it and create a new one.
- To run Pi, use the same command shape as any other tool: \`sand run <name> pi [args...]\`.
- Network access is outbound-only from the Sandbox VM in v1; inbound browser/server callbacks need a handoff flow outside the command surface.
- Commands name the target Sandbox VM explicitly, so it is always clear which environment you are operating.

## macOS Sandbox VMs

macOS guests are first-class Sandbox VMs backed by Tart. Use \`sand create <name> --os macos --from <registry-image-or-local-sandbox>\` to clone an existing Tart-compatible image or stopped local sandbox. Use \`sand create <name> --from-ipsw <latest|path|url>\` for the macOS Install Flow, then complete first boot in \`sand gui <name>\` and run \`sand bootstrap <name>\`.

\`--disk <size>\` is a macOS-only create-time Disk Size field. The default macOS disk is about 100GB, clone disk size is grow-only, and in-place disk resize is not part of the v1 command surface.

\`sand gui <name>\` opens a macOS GUI Session through Tart VNC and the Host Mac Screen Sharing app. Screen Sharing may ask for credentials. For Cirrus Tart registry images, use username \`admin\` and password \`admin\`; for self-built IPSW VMs, use the Sandbox User credentials created during first boot. \`gui\` is for VM desktop setup and Apple-ID-gated work; it does not forward a host-connected physical iPhone or iPad into the Sandbox Guest.

macOS support requires the Tart CLI on \`PATH\` (\`brew install cirruslabs/cli/tart\`). \`sand\` itself remains an unsigned, entitlement-free CLI because Tart carries the Virtualization Framework entitlement.

Plan macOS Sandbox VMs as a handful, not dozens: Apple's macOS guest license allows roughly two concurrent macOS VMs per Host Mac, and each VM is heavy compared with a Linux Sandbox VM.

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

## \`sand bootstrap\`

\`\`\`text
$bootstrap_help
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

## \`sand gui\`


\`\`\`text
$gui_help
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
