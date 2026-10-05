#!/usr/bin/env bash
set -euo pipefail

version=${1:?Usage: release-notes.sh VERSION [CHANGELOG]}
changelog=${2:-CHANGELOG.md}
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  printf 'Invalid release version: expected MAJOR.MINOR.PATCH\n' >&2
  exit 1
fi

notes=$(awk -v version="$version" '
  /^## / {
    if (found) exit
    heading = $0
    sub(/^##[[:space:]]+/, "", heading)
    split(heading, parts, /[[:space:]]+/)
    if (parts[1] == "[" version "]" || parts[1] == version) found = 1
    next
  }
  found { print }
' "$changelog")
if [[ ! $notes =~ [^[:space:]] ]]; then
  printf 'No release notes found for %s in %s\n' "$version" "$changelog" >&2
  exit 1
fi
printf '%s\n' "$notes"
