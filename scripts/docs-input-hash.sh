#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"
manifest_arg="${1:-${DOCS_INPUT_MANIFEST:-docs/docs-input-manifest.txt}}"

if [[ "$manifest_arg" = /* ]]; then
  manifest_path="$manifest_arg"
else
  manifest_path="$repo_root/$manifest_arg"
fi

if [[ ! -f "$manifest_path" ]]; then
  echo "docs-input-hash: missing Documentation Input Manifest: ${manifest_arg}" >&2
  exit 2
fi

hash_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

trim() {
  local value="$1"
  value="${value#"${value%%[!$' \t']*}"}"
  value="${value%"${value##*[!$' \t']}"}"
  printf '%s' "$value"
}

normalize_full() {
  awk '{ sub(/\r$/, ""); print }' "$1"
}

normalize_managed_markdown() {
  awk '
    {
      sub(/\r$/, "")
    }
    /^<!--[[:space:]]*docs-input-hash:/ { next }
    /^docs_input_hash:/ { next }
    /^<!--[[:space:]]*docs:managed:start/ {
      if (!inManaged) {
        print "<!-- docs:managed:content omitted from docs input hash -->"
      }
      inManaged = 1
      next
    }
    /^<!--[[:space:]]*docs:managed:end/ {
      inManaged = 0
      next
    }
    !inManaged { print }
  ' "$1"
}

emit_normalized_file() {
  local path="$1"
  local mode="$2"
  case "$mode" in
    full)
      normalize_full "$path"
      ;;
    managed-markdown)
      normalize_managed_markdown "$path"
      ;;
    *)
      echo "docs-input-hash: unknown hash mode '$mode' for $path" >&2
      exit 2
      ;;
  esac
}

payload="$(mktemp "${TMPDIR:-/tmp}/sand-docs-input-hash.XXXXXX")"
trap 'rm -f "$payload"' EXIT

{
  printf 'sand-docs-input-hash-v1\n'
  printf 'manifest:%s\n' "${manifest_path#"$repo_root/"}"
  printf -- '--- manifest begin ---\n'
  normalize_full "$manifest_path"
  printf -- '--- manifest end ---\n'

  while IFS= read -r raw_line || [[ -n "$raw_line" ]]; do
    line="$(trim "$raw_line")"
    [[ -z "$line" ]] && continue
    [[ "$line" == \#* ]] && continue

    read -r status path mode extra <<< "$line"
    if [[ "$status" != "required" && "$status" != "optional" ]]; then
      mode="${path:-full}"
      path="$status"
      status="required"
    fi
    mode="${mode:-full}"

    if [[ -n "${extra:-}" ]]; then
      echo "docs-input-hash: invalid manifest line with too many fields: $raw_line" >&2
      exit 2
    fi

    if [[ -z "${path:-}" ]]; then
      echo "docs-input-hash: invalid manifest line: $raw_line" >&2
      exit 2
    fi

    if [[ "$path" = /* || "$path" == *..* ]]; then
      echo "docs-input-hash: manifest paths must be repo-relative and cannot contain '..': $path" >&2
      exit 2
    fi

    file_path="$repo_root/$path"
    if [[ ! -f "$file_path" ]]; then
      if [[ "$status" == "optional" ]]; then
        printf -- '--- optional file missing: %s mode:%s ---\n' "$path" "$mode"
        continue
      fi
      echo "docs-input-hash: missing required input '$path' listed in ${manifest_path#"$repo_root/"}" >&2
      exit 2
    fi

    printf -- '--- file begin: %s mode:%s ---\n' "$path" "$mode"
    emit_normalized_file "$file_path" "$mode"
    printf '\n--- file end: %s ---\n' "$path"
  done < "$manifest_path"
} > "$payload"

hash_file "$payload"
