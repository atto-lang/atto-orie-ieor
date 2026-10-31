#!/usr/bin/env bash
# Synthetic NEGATIVE harness preflight regressions only.
# The tripwire executable below MUST NEVER run; these tests prove fail-closed
# argument, source-head, path, and binary-digest guards. No native guest test.
set -euo pipefail
export LC_ALL=C
umask 077

root="$(git rev-parse --show-toplevel)"
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT
orie="$scratch/orie"
llvm="$scratch/llvm"
mkdir -p "$orie/ci" "$llvm/bin"
cp "$root/ci/run-native-fixtures.sh" "$orie/ci/run-native-fixtures.sh"
printf 'synthetic-llvm-source\n' > "$llvm/README"
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'printf "%s\n" UNEXPECTED_COMPILER_EXECUTION >> "$ORIE_TRIPWIRE"' \
  'exit 97' > "$llvm/bin/oreslang-llvmc"
chmod 0700 "$llvm/bin/oreslang-llvmc"
for dir in "$orie" "$llvm"; do
  git init -q "$dir"
  git -C "$dir" add .
  git -C "$dir" -c user.email=synthetic@example.invalid \
    -c user.name=synthetic-preflight commit -qm 'synthetic preflight test'
done
orie_sha="$(git -C "$orie" rev-parse HEAD)"
llvm_sha="$(git -C "$llvm" rev-parse HEAD)"
bad_sha="$(printf '%040d' 0)"
bad_digest="$(printf '%064d' 0)"
real_digest="$(sha256sum "$llvm/bin/oreslang-llvmc" | cut -d' ' -f1)"
tripwire="$scratch/UNEXPECTED_COMPILER_EXECUTION"
export ORIE_TRIPWIRE="$tripwire"
count=0

reject() {
  local label="$1" expected_message="$2"
  shift 2
  local out="$scratch/$label.receipt"
  local log="$scratch/$label.log"
  if (cd "$orie" && bash ci/run-native-fixtures.sh "$@") >"$log" 2>&1; then
    echo "ORIE_PREFLIGHT_FALSE_ACCEPT: $label" >&2
    exit 1
  fi
  if ! grep -Fq -- "$expected_message" "$log"; then
    printf 'ORIE_PREFLIGHT_WRONG_DIAGNOSTIC: %s\n' "$label" >&2
    cat "$log" >&2
    exit 1
  fi
  [[ ! -e "$out" && ! -e "$tripwire" ]] ||
    { printf 'ORIE_PREFLIGHT_SIDE_EFFECT: %s\n' "$label" >&2; exit 1; }
  count=$((count + 1))
  printf 'ORIE_PREFLIGHT_REJECT %s\n' "$label"
}

reject missing_arguments 'usage: bash ci/run-native-fixtures.sh'
reject malformed_digest 'must be exactly 64 lowercase hex characters' \
  "$llvm/bin/oreslang-llvmc" "$llvm" "$scratch/malformed_digest.receipt" \
  "$orie_sha" "$llvm_sha" 'NOT-SHA256'
reject nonexistent_compiler 'native compiler must be a prebuilt absolute executable' \
  "$llvm/bin/does-not-exist" "$llvm" "$scratch/nonexistent_compiler.receipt" \
  "$orie_sha" "$llvm_sha" "$real_digest"
reject wrong_orie_sha 'ORIE head does not match requested SHA' \
  "$llvm/bin/oreslang-llvmc" "$llvm" "$scratch/wrong_orie_sha.receipt" \
  "$bad_sha" "$llvm_sha" "$real_digest"
reject wrong_llvm_sha 'LLVM compiler source head does not match requested SHA' \
  "$llvm/bin/oreslang-llvmc" "$llvm" "$scratch/wrong_llvm_sha.receipt" \
  "$orie_sha" "$bad_sha" "$real_digest"
reject wrong_compiler_digest 'compiler binary digest differs' \
  "$llvm/bin/oreslang-llvmc" "$llvm" "$scratch/wrong_compiler_digest.receipt" \
  "$orie_sha" "$llvm_sha" "$bad_digest"
reject compiler_outside_llvm_checkout 'compiler executable must physically reside' \
  /bin/true "$llvm" "$scratch/compiler_outside_llvm_checkout.receipt" \
  "$orie_sha" "$llvm_sha" "$real_digest"
ln -s /bin/true "$llvm/bin/escaped"
reject compiler_symlink_escape 'compiler executable must physically reside' \
  "$llvm/bin/escaped" "$llvm" "$scratch/compiler_symlink_escape.receipt" \
  "$orie_sha" "$llvm_sha" "$real_digest"
printf 'dirty\n' > "$orie/untracked"
reject dirty_orie_checkout 'ORIE worktree is dirty' \
  "$llvm/bin/oreslang-llvmc" "$llvm" "$scratch/dirty_orie_checkout.receipt" \
  "$orie_sha" "$llvm_sha" "$real_digest"
rm "$orie/untracked"
printf 'dirty\n' >> "$llvm/README"
reject dirty_llvm_checkout 'LLVM source worktree contains uncommitted tracked changes' \
  "$llvm/bin/oreslang-llvmc" "$llvm" "$scratch/dirty_llvm_checkout.receipt" \
  "$orie_sha" "$llvm_sha" "$real_digest"

[[ "$count" -eq 10 ]] ||
  { echo 'ORIE_PREFLIGHT_COUNT_MISMATCH' >&2; exit 1; }
printf 'ORIE_SYNTHETIC_NATIVE_PREFLIGHT_REJECTIONS=%d (no compiler invoked)\n' "$count"
