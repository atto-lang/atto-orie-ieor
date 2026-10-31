#!/usr/bin/env bash
# Actual Oreslang -> LLVM IR -> Clang -> native guest only. No mock fallback.
# Must run inside an authorized security boundary; does not confer export approval.
set -euo pipefail
export LC_ALL=C
# Guest IR, native executables, compiler diagnostics and provenance may
# contain private source details. Never publish world/group-readable receipts
# on shared trusted runners: mkdir and every later redirection inherit 0700/
# 0600 permissions, independently of the runner's default umask.
umask 077

die() { printf 'ORIE_NATIVE_GATE_BLOCKED: %s\n' "$*" >&2; exit 1; }
[[ "$#" -eq 5 ]] || die "usage: bash ci/run-native-fixtures.sh <llvmc-absolute-path> <compiler-git-root> <output-dir-outside-repo> <orie-head-sha> <llvm-head-sha>"
compiler="$1"
compiler_root="$2"
output_dir="$3"
expected_orie="$4"
expected_llvm="$5"
[[ "$compiler" = /* && -f "$compiler" && -x "$compiler" ]] ||
  die "native compiler must be a prebuilt absolute executable"
[[ "$compiler_root" = /* && -d "$compiler_root/.git" ]] ||
  die "LLVM compiler Git checkout must be an absolute path"
[[ "$output_dir" = /* ]] || die "output directory must be an absolute path"
[[ "$expected_orie" =~ ^[0-9a-f]{40}$ && "$expected_llvm" =~ ^[0-9a-f]{40}$ ]] ||
  die "both compiler and ORIE source SHAs must be full 40-character hashes"
command -v clang >/dev/null || die "clang missing"
command -v timeout >/dev/null || die "GNU timeout missing"
command -v sha256sum >/dev/null || die "sha256sum missing"
command -v realpath >/dev/null || die "realpath missing"

root="$(realpath "$(git rev-parse --show-toplevel)")"
compiler_root="$(realpath "$compiler_root")"
cd "$root"
[[ "$(git rev-parse HEAD)" = "$expected_orie" ]] || die "ORIE head does not match requested SHA"
[[ "$(git -C "$compiler_root" rev-parse HEAD)" = "$expected_llvm" ]] ||
  die "LLVM compiler source head does not match requested SHA"
[[ -z "$(git status --porcelain --untracked-files=normal)" ]] ||
  die "ORIE worktree is dirty; cannot claim exact-head execution"
[[ -z "$(git -C "$compiler_root" status --porcelain --untracked-files=no)" ]] ||
  die "LLVM source worktree contains uncommitted tracked changes"
output_dir="$(realpath -m "$output_dir")"
case "$output_dir/" in
  "$root/"*) die "output must be outside ORIE repository";;
  "$compiler_root/"*) die "output must be outside LLVM source repository";;
esac
bash ci/validate-guest-inventory.sh >/dev/null ||
  die "source inventory rejected; no compilation attempted"

[[ -d "$(dirname "$output_dir")" ]] ||
  die "receipt directory parent must already exist"
# Atomic exclusive creation: no check-then-mkdir race and no overwrite.
mkdir -- "$output_dir" ||
  die "receipt directory already exists or could not be created"
compiler_digest="$(sha256sum "$compiler" | cut -d' ' -f1)"
{
  printf 'evidence_class=NATIVE_ATTEMPT_NOT_NUMERICAL_CERTIFICATE\n'
  printf 'orie_commit=%s\n' "$expected_orie"
  printf 'orie_tree=%s\n' "$(git rev-parse HEAD^{tree})"
  printf 'llvm_commit=%s\n' "$expected_llvm"
  printf 'llvm_tree=%s\n' "$(git -C "$compiler_root" rev-parse HEAD^{tree})"
  printf 'compiler_binary_sha256=%s\n' "$compiler_digest"
  printf 'clang_version=%s\n' "$(clang --version | sed -n '1p')"
  printf 'clang_binary_sha256=%s\n' "$(sha256sum "$(command -v clang)" | cut -d' ' -f1)"
  printf 'runner_run_id=%s\n' "${GITHUB_RUN_ID:-NOT_CI}"
  printf 'runner_attempt=%s\n' "${GITHUB_RUN_ATTEMPT:-NOT_CI}"
  printf 'runner_job=%s\n' "${GITHUB_JOB:-NOT_CI}"
  printf 'warning=Runner steps and build provenance require independent verification.\n'
} > "$output_dir/provenance.txt"
# A scalar-only probe separates compiler/toolchain admission from the
# 13 application fixtures (which require f64, Array, class, Result, imports).
smoke_source="ci/scalar-llvm-smoke.ores"
[[ -f "$smoke_source" && ! -L "$smoke_source" ]] ||
  die "missing/linked native scalar smoke fixture"
printf 'scalar_smoke_source_sha256=%s\n' \
  "$(sha256sum "$smoke_source" | cut -d' ' -f1)" >> "$output_dir/provenance.txt"
smoke_rc=0
timeout --signal=TERM --kill-after=2s 60s "$compiler" "$smoke_source" \
  > "$output_dir/scalar-smoke.ll" 2> "$output_dir/scalar-smoke.compiler.stderr" ||
  smoke_rc=$?
printf '%s\n' "$smoke_rc" > "$output_dir/scalar-smoke.compiler.exitcode"
[[ "$smoke_rc" -eq 0 && -s "$output_dir/scalar-smoke.ll" &&
   ! -s "$output_dir/scalar-smoke.compiler.stderr" ]] ||
  die "scalar source -> IR compiler admission failed; 13 ORIE guests not attempted"

smoke_link_rc=0
timeout --signal=TERM --kill-after=2s 30s clang -x ir "$output_dir/scalar-smoke.ll" \
  -o "$output_dir/scalar-smoke.native" \
  > "$output_dir/scalar-smoke.link.stdout" 2> "$output_dir/scalar-smoke.link.stderr" ||
  smoke_link_rc=$?
printf '%s\n' "$smoke_link_rc" > "$output_dir/scalar-smoke.link.exitcode"
[[ "$smoke_link_rc" -eq 0 && -x "$output_dir/scalar-smoke.native" &&
   ! -s "$output_dir/scalar-smoke.link.stdout" &&
   ! -s "$output_dir/scalar-smoke.link.stderr" ]] ||
  die "scalar IR -> native link failed; 13 ORIE guests not attempted"

smoke_guest_rc=0
timeout --signal=TERM --kill-after=2s 10s "$output_dir/scalar-smoke.native" \
  > "$output_dir/scalar-smoke.stdout" 2> "$output_dir/scalar-smoke.stderr" ||
  smoke_guest_rc=$?
printf '%s\n' "$smoke_guest_rc" > "$output_dir/scalar-smoke.guest.exitcode"
[[ "$smoke_guest_rc" -eq 42 &&
   ! -s "$output_dir/scalar-smoke.stdout" &&
   ! -s "$output_dir/scalar-smoke.stderr" ]] ||
  die "scalar native guest must exit 42 with empty stdout/stderr"

{
  printf 'scalar_smoke_ir_sha256=%s\n' \
    "$(sha256sum "$output_dir/scalar-smoke.ll" | cut -d' ' -f1)"
  printf 'scalar_smoke_executable_sha256=%s\n' \
    "$(sha256sum "$output_dir/scalar-smoke.native" | cut -d' ' -f1)"
  printf 'scalar_smoke_result=SCALAR_COMPILER_NATIVE_PASS_NOT_ORIE_GUEST\n'
} >> "$output_dir/provenance.txt"
printf '%s\n' 'SCALAR_COMPILER_NATIVE_PASS (not an ORIE algorithm test)'

printf 'fixture\texpected_stdout\tresult\tguest_sha256\tllvm_ir_sha256\tnative_binary_sha256\n' > "$output_dir/results.tsv"

ok=0
total=0
while IFS= read -r line || [[ -n "$line" ]]; do
  fixture="${line%%$'\t'*}"
  marker="${line#*$'\t'}"
  pkg_dir="$(dirname "$(dirname "$fixture")")"
  name="$(basename "$fixture" .ores)"
  id="${pkg_dir##*/}--$name"
  guest="tests/$name.ores"
  guest_digest="$(sha256sum "$fixture" | cut -d' ' -f1)"
  ir="$output_dir/$id.ll"
  native="$output_dir/$id.native"
  compiler_stderr="$output_dir/$id.compiler.stderr"
  link_stderr="$output_dir/$id.link.stderr"
  stdout="$output_dir/$id.stdout"
  stderr="$output_dir/$id.stderr"
  total=$((total + 1))
  printf 'compiler_command=(cd %q && timeout --signal=TERM --kill-after=2s 60s %q %q)\n' "$pkg_dir" "$compiler" "$guest" > "$output_dir/$id.commands"
  printf 'native_link_command=timeout --signal=TERM --kill-after=2s 30s clang -x ir %q -o %q\n' "$ir" "$native" >> "$output_dir/$id.commands"
  printf 'guest_command=timeout --signal=TERM --kill-after=2s 10s %q\n' "$native" >> "$output_dir/$id.commands"
  result="COMPILER_REJECTED_UNCLASSIFIED"
  ir_digest="NONE"
  bin_digest="NONE"
  compile_rc=0
  (cd "$pkg_dir" && timeout --signal=TERM --kill-after=2s 60s "$compiler" "$guest") > "$ir" 2> "$compiler_stderr" ||
    compile_rc=$?
  printf '%s\n' "$compile_rc" > "$output_dir/$id.compiler.exitcode"
  if [[ "$compile_rc" -eq 0 ]]; then
    if [[ -s "$ir" && ! -s "$compiler_stderr" ]]; then
      ir_digest="$(sha256sum "$ir" | cut -d' ' -f1)"
      result="NATIVE_LINK_FAILED"
      link_rc=0
      timeout --signal=TERM --kill-after=2s 30s clang -x ir "$ir" -o "$native" > "$output_dir/$id.link.stdout" 2> "$link_stderr" ||
        link_rc=$?
      printf '%s\n' "$link_rc" > "$output_dir/$id.link.exitcode"
      if [[ "$link_rc" -eq 124 ]]; then
        result="NATIVE_LINK_TIMEOUT"
      fi
      if [[ "$link_rc" -eq 0 && -f "$native" && -x "$native" &&
            ! -s "$link_stderr" && ! -s "$output_dir/$id.link.stdout" ]]; then
        bin_digest="$(sha256sum "$native" | cut -d' ' -f1)"
        result="GUEST_EXIT_OR_OUTPUT_MISMATCH"
        guest_rc=0
        timeout --signal=TERM --kill-after=2s 10s "$native" > "$stdout" 2> "$stderr" ||
          guest_rc=$?
        printf '%s\n' "$guest_rc" > "$output_dir/$id.guest.exitcode"
        if [[ "$guest_rc" -eq 124 ]]; then
          result="GUEST_TIMEOUT"
        fi
        printf '%s\n' "$marker" > "$output_dir/$id.expected.stdout"
        if [[ "$guest_rc" -eq 0 && ! -s "$stderr" ]] &&
           cmp -s "$output_dir/$id.expected.stdout" "$stdout"; then
          result="NATIVE_GUEST_EXACT_STDOUT"
          ok=$((ok + 1))
        fi
      fi
    else
      result="COMPILER_INVALID_IR_OR_DIAGNOSTIC"
    fi
  elif [[ "$compile_rc" -eq 124 ]]; then
    result="COMPILER_TIMEOUT"
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$fixture" "$marker" "$result" \
    "$guest_digest" "$ir_digest" "$bin_digest" >> "$output_dir/results.tsv"
  printf '%s %s\n' "$result" "$fixture"
done < ci/guest-fixtures.tsv

printf 'NATIVE_GUEST_RECEIPT_COUNT=%d/%d\n' "$ok" "$total"
[[ "$total" -eq 13 && "$ok" -eq 13 ]] ||
  die "not all 13 native guests executed with exact stdout; see preserved per-case diagnostics"
printf '%s\n' 'NATIVE_GUEST_EXACT_STDOUT_13_OF_13 (does not prove numerical certificates or governance)'
