#!/usr/bin/env bash
# Source-free negative tests for the inventory gate. This creates only
# synthetic fixture stubs; it does not compile or execute Oreslang guests.
set -euo pipefail
export LC_ALL=C

source_root="$(git rev-parse --show-toplevel)"
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
sandbox="$scratch/synthetic"
checks=0

setup() {
  rm -rf -- "$sandbox"
  mkdir -p "$sandbox/ci" "$sandbox/packages"
  git init -q "$sandbox"
  cp -- "$source_root/ci/validate-guest-inventory.sh" "$sandbox/ci/"
  cp -- "$source_root/ci/guest-fixtures.tsv" "$sandbox/ci/"
  for pkg in orie-numerics orie-opt orie-sim orie-plan; do
    mkdir -p "$sandbox/packages/$pkg/src" "$sandbox/packages/$pkg/tests"
    printf '%s\n' 'schema_version = "1"' > "$sandbox/packages/$pkg/.ores.pkg.toml"
    printf '%s\n' 'Synthetic package; not a native execution receipt.' \
      > "$sandbox/packages/$pkg/README.md"
  done
  while IFS=$'\t' read -r file marker; do
    [[ -n "$file" ]] || continue
    mkdir -p -- "$sandbox/$(dirname "$file")"
    printf '%s\n' \
      "// Expected: $marker" \
      'pub routine main(): void {' \
      "  stdio.stdout.println(\"$marker\");" \
      '}' > "$sandbox/$file"
  done < "$sandbox/ci/guest-fixtures.tsv"
  # 13 synthetic test files + 14 synthetic implementation files = 27.
  for n in $(seq 1 14); do
    printf 'define module synthetic_%s as\nend\n' "$n" \
      > "$sandbox/packages/orie-opt/src/synthetic_$n.ores"
  done
}

accept() {
  local name="$1"
  if ! (cd "$sandbox" && bash ci/validate-guest-inventory.sh) \
    > "$scratch/output" 2>&1; then
    printf 'INVENTORY_TEST_FAIL expected accept: %s\n' "$name" >&2
    cat "$scratch/output" >&2
    exit 1
  fi
  grep -Fq 'ORIE_SOURCE_INVENTORY_PASS fixture_rows=13' "$scratch/output" ||
    { printf 'INVENTORY_TEST_FAIL no layout marker: %s\n' "$name" >&2; exit 1; }
  checks=$((checks + 1))
  printf 'INVENTORY_TEST_ACCEPT %s\n' "$name"
}

reject() {
  local name="$1"
  if (cd "$sandbox" && bash ci/validate-guest-inventory.sh) \
    > "$scratch/output" 2>&1; then
    printf 'INVENTORY_TEST_FAIL false acceptance: %s\n' "$name" >&2
    exit 1
  fi
  grep -Fq 'ORIE_LAYOUT_REJECT:' "$scratch/output" ||
    { printf 'INVENTORY_TEST_FAIL wrong rejection: %s\n' "$name" >&2
      cat "$scratch/output" >&2; exit 1; }
  checks=$((checks + 1))
  printf 'INVENTORY_TEST_REJECT %s\n' "$name"
}

setup; accept baseline
setup; head -n 1 "$sandbox/ci/guest-fixtures.tsv" >> "$sandbox/ci/guest-fixtures.tsv"
reject duplicate_fixture_row
setup; sed -i '1s/$/\tEXTRA/' "$sandbox/ci/guest-fixtures.tsv"
reject extra_tsv_column
setup; sed -i '1s/\t/ /' "$sandbox/ci/guest-fixtures.tsv"
reject missing_tab
setup; sed -i '1s@/tests/@/tests/../tests/@' "$sandbox/ci/guest-fixtures.tsv"
reject parent_traversal
setup; sed -i '1s/$/\r/' "$sandbox/ci/guest-fixtures.tsv"
reject crlf
setup
file="$(head -n 1 "$sandbox/ci/guest-fixtures.tsv" | cut -f1)"
rm -- "$sandbox/$file"
ln -s /etc/passwd "$sandbox/$file"
reject symlinked_guest
setup; sed -i 's/stdio.stdout.println/stdio.stdout.print/' \
  "$sandbox/packages/orie-numerics/tests/linear_solve_contract.ores"
reject absent_stdout_marker
setup; printf '%s\n' 'unexpected' > "$sandbox/packages/orie-opt/tests/unlisted.ores"
reject unlisted_guest
setup
first_marker="$(head -n 1 "$sandbox/ci/guest-fixtures.tsv" | cut -f2)"
sed -i "2s/PASS:orie-[a-z-]*/$first_marker/" "$sandbox/ci/guest-fixtures.tsv"
reject duplicate_marker
setup
mv -- "$sandbox/ci/guest-fixtures.tsv" "$sandbox/ci/real-ledger.tsv"
ln -s real-ledger.tsv "$sandbox/ci/guest-fixtures.tsv"
reject symlinked_ledger
setup
mv -- "$sandbox/packages" "$sandbox/packages.real"
ln -s packages.real "$sandbox/packages"
reject symlinked_packages_root
setup; rm -- "$sandbox/packages/orie-plan/.ores.pkg.toml"
reject missing_manifest
setup; printf '%s\n' 'schema_version = "1"' \
  > "$sandbox/packages/orie-opt/src/.ores.pkg.toml"
reject extra_manifest
setup; accept restored_baseline

[[ "$checks" -eq 15 ]] || { echo 'INVENTORY_TEST_FAIL incorrect check count' >&2; exit 1; }
printf 'ORIE_SYNTHETIC_LAYOUT_TESTS_PASS=%d (source-free; no native guests)\n' "$checks"
