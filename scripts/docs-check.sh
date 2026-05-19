#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
input_manifest_arg="${DOCS_INPUT_MANIFEST:-docs/docs-input-manifest.txt}"
generated_manifest_arg="${GENERATED_DOCS_MANIFEST:-docs/generated-docs-manifest.txt}"

resolve_repo_path() {
  local path="$1"
  if [[ "$path" = /* ]]; then
    printf '%s' "$path"
  else
    printf '%s/%s' "$repo_root" "$path"
  fi
}

input_manifest_path="$(resolve_repo_path "$input_manifest_arg")"
generated_manifest_path="$(resolve_repo_path "$generated_manifest_arg")"

if [[ ! -f "$generated_manifest_path" ]]; then
  echo "docs-check: missing Generated Documentation registry: $generated_manifest_arg" >&2
  echo "docs-check: create docs/generated-docs-manifest.txt or set GENERATED_DOCS_MANIFEST." >&2
  exit 1
fi

current_hash="$($script_dir/docs-input-hash.sh "$input_manifest_path")"
failures=0
checked=0

trim() {
  local value="$1"
  value="${value#"${value%%[!$' \t']*}"}"
  value="${value%"${value##*[!$' \t']}"}"
  printf '%s' "$value"
}

extract_recorded_hash() {
  local doc_path="$1"
  local line
  line="$(grep -E 'docs-input-hash:|docs_input_hash:' "$doc_path" | head -n 1 || true)"
  if [[ -z "$line" ]]; then
    return 1
  fi
  printf '%s\n' "$line" \
    | sed -E 's/.*docs[-_]input[-_]hash:[[:space:]]*"?([0-9a-fA-F]+)"?.*/\1/' \
    | tr 'A-F' 'a-f'
}

report_failure() {
  failures=$((failures + 1))
  echo "$1" >&2
}

while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
  line="$(trim "$raw_line")"
  [[ -z "$line" ]] && continue
  [[ "$line" == \#* ]] && continue

  read -r doc_path extra <<< "$line"
  if [[ -n "${extra:-}" ]]; then
    report_failure "docs-check: invalid generated docs registry line: $raw_line"
    continue
  fi

  if [[ "$doc_path" = /* || "$doc_path" == *..* ]]; then
    report_failure "docs-check: generated doc paths must be repo-relative and cannot contain '..': $doc_path"
    continue
  fi

  checked=$((checked + 1))
  full_doc_path="$repo_root/$doc_path"

  if [[ ! -f "$full_doc_path" ]]; then
    report_failure "docs-check: missing Generated Documentation '$doc_path'. Create it with the Documentation Refresh Workflow, or remove it from ${generated_manifest_path#"$repo_root/"} if it is not generated."
    continue
  fi

  if ! recorded_hash="$(extract_recorded_hash "$full_doc_path")"; then
    report_failure "docs-check: '$doc_path' is missing docs input hash metadata. Add '<!-- docs-input-hash: $current_hash -->' when refreshing Generated Documentation."
    continue
  fi

  if [[ "$recorded_hash" != "$current_hash" ]]; then
    report_failure "docs-check: '$doc_path' has stale docs input hash '$recorded_hash'; expected '$current_hash'. Refresh Generated Documentation, then rerun make docs-check."
    continue
  fi

  echo "docs-check: ok $doc_path"
done < "$generated_manifest_path"

if [[ "$checked" -eq 0 ]]; then
  echo "docs-check: no Generated Documentation registered yet; current docs input hash is $current_hash"
fi

if [[ "$failures" -gt 0 ]]; then
  echo "docs-check: Documentation Freshness Gate failed with $failures problem(s)." >&2
  exit 1
fi

echo "docs-check: Documentation Freshness Gate passed."
