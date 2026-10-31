#!/usr/bin/env bash
# Source-layout inventory gate only. Never reports native compiler/guest PASS.
set -euo pipefail
export LC_ALL=C

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"
inventory="ci/guest-fixtures.tsv"

fail() { printf 'ORIE_LAYOUT_REJECT: %s\n' "$*" >&2; exit 1; }
[[ -f "$inventory" && ! -L "$inventory" ]] || fail "missing or linked fixture inventory"
[[ ! -e .ores.pkg.toml && ! -L .ores.pkg.toml ]] || fail "unexpected root manifest"
[[ -d packages && ! -L packages ]] || fail "missing or linked packages root"
if find packages -type l -print -quit | grep -q .; then
  fail "symlink inside packages"
fi

declare -A seen_path=()
declare -A seen_marker=()
count=0
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" == *$'\t'* ]] || fail "invalid TSV row (no tab)"
  path="${line%%$'\t'*}"
  marker="${line#*$'\t'}"
  [[ -n "$path" && -n "$marker" && "$marker" != *$'\t'* &&
     "$line" != *$'\r'* ]] || fail "invalid TSV row (blank/extra column/CRLF)"
  [[ "$path" =~ ^packages/(orie-numerics|orie-opt|orie-sim|orie-plan)/tests/[a-z][a-z0-9_]*\.ores$ ]] ||
    fail "invalid package fixture path: $path"
  [[ "$marker" =~ ^PASS:orie-[a-z0-9-]+$ ]] ||
    fail "invalid expected stdout marker: $marker"
  [[ ! -v seen_path["$path"] ]] || fail "duplicate fixture: $path"
  [[ ! -v seen_marker["$marker"] ]] || fail "duplicate stdout marker: $marker"
  seen_path["$path"]=1
  seen_marker["$marker"]=1
  [[ -f "$path" && ! -L "$path" ]] || fail "missing or linked fixture: $path"
  grep -Fq -- "Expected: $marker" "$path" ||
    fail "missing declared oracle in $path"
  # Structural oracle declaration must appear exactly once. A duplicate
  # expected PASS emission would make the exact-one-line guest contract
  # ambiguous even though no parser or guest has run at this stage.
  [[ "$(grep -Fc -- "stdio.stdout.println(\"$marker\");" "$path")" -eq 1 ]] ||
    fail "missing or duplicated guest stdout marker in $path"
  count=$((count + 1))
done < "$inventory"

[[ "$count" -eq 13 ]] || fail "expected exactly 13 fixture rows, got $count"
for pkg in orie-numerics orie-opt orie-sim orie-plan; do
  [[ -f "packages/$pkg/.ores.pkg.toml" &&
     -f "packages/$pkg/README.md" ]] || fail "missing package manifest/readme: $pkg"
done
[[ "$(find packages -type f -name '.ores.pkg.toml' | wc -l)" -eq 4 ]] ||
  fail "expected 4 manifests"
[[ "$(find packages -type f -name '*.ores' | wc -l)" -eq 27 ]] ||
  fail "expected 27 Oreslang source files"
if ! diff -u <(printf '%s\n' "${!seen_path[@]}" | sort) \
  <(find packages -type f -path '*/tests/*.ores' | sort); then
  fail "fixture inventory does not match the tree"
fi
printf 'ORIE_SOURCE_INVENTORY_PASS fixture_rows=%d manifests=4 ores_files=27\n' "$count"
printf '%s\n' 'SOURCE_LAYOUT only; no compiler or guest execution occurred'
