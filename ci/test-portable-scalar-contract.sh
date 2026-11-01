#!/usr/bin/env bash
# Source-only conformance fixture integrity; NO compiler or guest execution.
set -euo pipefail
export LC_ALL=C
root="$(git rev-parse --show-toplevel)"
directory="$root/ci/portable-scalar"

verify() {
  local base="$1" x
  [[ -d "$base" && ! -L "$base" ]] || return 1
  for x in entry_42.ores checked_overflow.ores fixtures.tsv backends.tsv; do
    [[ -f "$base/$x" && ! -L "$base/$x" ]] || return 1
  done
  [[ "$(find "$base" -mindepth 1 -maxdepth 1 -type f | wc -l)" -eq 4 ]] || return 1
  [[ -z "$(find "$base" -mindepth 1 -maxdepth 1 -type l -print -quit)" ]] || return 1
  cmp -s "$base/entry_42.ores" <(printf '%s\n' \
    '// Portable scalar subset: source-only candidate, not a cross-backend receipt.' \
    'pub fnc main(): int { return 6 * 7; }') || return 1
  cmp -s "$base/checked_overflow.ores" <(printf '%s\n' \
    '// A checked-i64 backend must not silently wrap this addition.' \
    'pub fnc main(): int { return 9223372036854775807 + 1; }') || return 1
  cmp -s "$base/fixtures.tsv" <(printf '%s\n' \
    $'entry_42.ores\tSCALAR_42' \
    $'checked_overflow.ores\tCHECKED_OVERFLOW') || return 1
  cmp -s "$base/backends.tsv" <(printf '%s\n' \
    $'java\tGUEST_RESULT_42' \
    $'llvm\tNATIVE_EXIT_42' \
    $'wasm\tWASM_I64_RESULT_42' \
    $'cranelift\tJIT_STDOUT_42' \
    $'net\tNATIVE_AOT_EXIT_42') || return 1
}

verify "$directory" || { echo 'ORIE_PORTABLE_SCALAR_REJECT canonical' >&2; exit 1; }
printf '%s\n' 'ORIE_PORTABLE_SCALAR_ACCEPT canonical'
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
reject() {
  local label="$1"
  if verify "$scratch/cases"; then
    printf 'ORIE_PORTABLE_SCALAR_FALSE_ACCEPT %s\n' "$label" >&2
    exit 1
  fi
  printf 'ORIE_PORTABLE_SCALAR_REJECT %s\n' "$label"
}
reset_case() { rm -rf -- "$scratch/cases"; cp -R -- "$directory" "$scratch/cases"; }
reset_case; sed -i 's/6 \* 7/7 * 7/' "$scratch/cases/entry_42.ores"; reject changed_arithmetic
reset_case; sed -i 's/NATIVE_AOT_EXIT_42/NATIVE_AOT_EXIT_0/' "$scratch/cases/backends.tsv"; reject false_backend_expected_exit
reset_case; sed -i 's/9223372036854775807 + 1/9223372036854775807 - 1/' "$scratch/cases/checked_overflow.ores"; reject weakened_overflow
reset_case; rm -- "$scratch/cases/checked_overflow.ores"; reject missing_overflow
reset_case; mv -- "$scratch/cases/entry_42.ores" "$scratch/cases/real.ores"; ln -s real.ores "$scratch/cases/entry_42.ores"; reject symlinked_guest
reset_case; printf '%s\n' 'unexpected' > "$scratch/cases/extra.ores"; reject extra_source
reset_case; printf '%s\n' 'extra\tSCALAR_42' >> "$scratch/cases/fixtures.tsv"; reject injected_manifest_row
printf '%s\n' 'ORIE_PORTABLE_SCALAR_SOURCE_ONLY_TESTS_PASS=8 (no compiler or guest executed)'
