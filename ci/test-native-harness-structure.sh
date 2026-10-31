#!/usr/bin/env bash
# Source-only, fail-closed check of native receipt harness structure.
# Never compiles or executes a real Oreslang guest.
set -euo pipefail
export LC_ALL=C
root="$(git rev-parse --show-toplevel)"
harness="$root/ci/run-native-fixtures.sh"
[[ -f "$harness" && ! -L "$harness" ]] || { echo "ORIE_STRUCTURE_REJECT harness" >&2; exit 1; }
count_lines() { grep -Fc -- "$1" "$2" || true; }
valid() {
  local f="$1"
  bash -n "$f" >/dev/null 2>&1 || return 1
  [[ "$(count_lines "while IFS= read -r line" "$f")" = 1 ]] || return 1
  [[ "$(count_lines "read -r name source expected_exit expected_output; do" "$f")" = 1 ]] || return 1
  [[ "$(count_lines "done < ci/native-feature-probes.tsv" "$f")" = 1 ]] || return 1
  [[ "$(count_lines "done < ci/guest-fixtures.tsv" "$f")" = 1 ]] || return 1
  [[ "$(count_lines "NATIVE_GUEST_EXACT_STDOUT_13_OF_13" "$f")" = 1 ]] || return 1
  [[ "$(count_lines 'feature_total=$((feature_total + 1))' "$f")" = 1 ]] || return 1
  grep -Fq '[[ "$total" -eq 13 && "$ok" -eq 13 && "$feature_total" -eq 6 && "$feature_ok" -eq 6 ]] ||' "$f" || return 1
}
valid "$harness" || { echo "ORIE_STRUCTURE_REJECT canonical" >&2; exit 1; }
echo "ORIE_STRUCTURE_ACCEPT canonical"
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
cp -- "$harness" "$scratch/modified.sh"
printf '%s\n' '# NATIVE_GUEST_EXACT_STDOUT_13_OF_13' >> "$scratch/modified.sh"
if valid "$scratch/modified.sh"; then echo "ORIE_STRUCTURE_FALSE_ACCEPT duplicate marker" >&2; exit 1; fi
echo "ORIE_STRUCTURE_REJECT duplicate marker"
cp -- "$harness" "$scratch/modified.sh"
printf '%s\n' '# while IFS= read -r line' >> "$scratch/modified.sh"
if valid "$scratch/modified.sh"; then echo "ORIE_STRUCTURE_FALSE_ACCEPT duplicate guest loop" >&2; exit 1; fi
echo "ORIE_STRUCTURE_REJECT duplicate guest loop"
cp -- "$harness" "$scratch/modified.sh"
sed -i '/\[\[ "\$total" -eq 13 \&\& "\$ok" -eq 13 \&\& "\$feature_total" -eq 6 \&\& "\$feature_ok" -eq 6 \]\] ||/d' "$scratch/modified.sh"
if valid "$scratch/modified.sh"; then echo "ORIE_STRUCTURE_FALSE_ACCEPT missing six-probe gate" >&2; exit 1; fi
echo "ORIE_STRUCTURE_REJECT missing six-probe gate"
echo "ORIE_SOURCE_HARNESS_STRUCTURE_4_OF_4 (no native execution)"
