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
[[ "$#" -eq 6 ]] || die "usage: bash ci/run-native-fixtures.sh <compiler-inside-llvm-checkout> <compiler-git-root> <output-dir-outside-repo> <orie-head-sha> <llvm-head-sha> <expected-compiler-sha256>"
compiler="$1"
compiler_root="$2"
output_dir="$3"
expected_orie="$4"
expected_llvm="$5"
expected_compiler_digest="$6"
[[ "$compiler" = /* && -f "$compiler" && -x "$compiler" ]] ||
  die "native compiler must be a prebuilt absolute executable"
[[ "$compiler_root" = /* && -d "$compiler_root/.git" ]] ||
  die "LLVM compiler Git checkout must be an absolute path"
[[ "$output_dir" = /* ]] || die "output directory must be an absolute path"
[[ "$expected_orie" =~ ^[0-9a-f]{40}$ && "$expected_llvm" =~ ^[0-9a-f]{40}$ ]] ||
  die "both compiler and ORIE source SHAs must be full 40-character hashes"
[[ "$expected_compiler_digest" =~ ^[0-9a-f]{64}$ ]] ||
  die "expected compiler binary SHA-256 must be exactly 64 lowercase hex characters"
command -v clang >/dev/null || die "clang missing"
command -v timeout >/dev/null || die "GNU timeout missing"
command -v sha256sum >/dev/null || die "sha256sum missing"
command -v realpath >/dev/null || die "realpath missing"

# Resolve native linker identity once and invoke that physical executable.
# A later PATH entry cannot silently replace the compiler of LLVM IR.
clang_path="$(realpath "$(command -v clang)")"
[[ "$clang_path" = /* && -f "$clang_path" && -x "$clang_path" ]] ||
  die "resolved clang is not a regular executable"
clang_digest="$(sha256sum "$clang_path" | cut -d' ' -f1)"

root="$(realpath "$(git rev-parse --show-toplevel)")"
compiler_root="$(realpath "$compiler_root")"
compiler="$(realpath "$compiler")"
case "$compiler" in
  "$compiler_root"/*) ;;
  *) die "compiler executable must physically reside under the pinned LLVM Git checkout";;
esac
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
compiler_digest="$(sha256sum "$compiler" | cut -d' ' -f1)"
[[ "$compiler_digest" = "$expected_compiler_digest" ]] ||
  die "compiler binary digest differs from the independently pinned expected SHA-256"
bash ci/validate-guest-inventory.sh >/dev/null ||
  die "source inventory rejected; no compilation attempted"
# Mirror the pinned native LLVM scripts/compile-aot.sh link contract:
# --target=host and only the required native C runtime sources. The saved
# emitted IR file MUST be the file Clang consumes.
build_native_link_argv() {
  local ir="$1" native="$2"
  local -a runtime_sources=()
  if grep -Eq 'declare .*@ores_string_' "$ir"; then
    runtime_sources+=("$compiler_root/src/main/cpp/oreslang/runtime/NativeStringRegion.c")
  fi
  if grep -Eq 'declare .*@ores_record_' "$ir"; then
    runtime_sources+=("$compiler_root/src/main/cpp/oreslang/runtime/NativeRecordRegion.c")
  fi
  if grep -Eq 'declare .*@oreslang_int_array_' "$ir"; then
    runtime_sources+=("$compiler_root/src/main/cpp/oreslang/runtime/NativeIntArrayRegion.c")
  fi
  link_argv=("$clang_path" -O2 -x ir "$ir")
  if (( ${#runtime_sources[@]} > 0 )); then
    local source
    for source in "${runtime_sources[@]}"; do
      [[ -f "$source" && ! -L "$source" ]] ||
        die "missing or linked pinned LLVM native runtime source: $source"
    done
    link_argv+=(-x c -std=c11 -I "$compiler_root/src/main/cpp")
    link_argv+=("${runtime_sources[@]}")
    link_argv+=(-pthread)
  fi
  link_argv+=(-o "$native")
}

# Guest stdout is a pipe, not a regular file, as the native nonblocking
# stdout reactor requires. Record guest and capture process exits separately.
capture_native_guest() {
  local native="$1" stdout="$2" stderr="$3" exitcode_prefix="$4"
  local -a status
  set +e
  timeout --signal=TERM --kill-after=2s 10s "$native" 2> "$stderr" |
    cat > "$stdout"
  status=("${PIPESTATUS[@]}")
  set -e
  printf '%s\n' "${status[0]}" > "$exitcode_prefix.guest.exitcode"
  printf '%s\n' "${status[1]}" > "$exitcode_prefix.capture.exitcode"
  guest_rc="${status[0]}"
  capture_rc="${status[1]}"
}



[[ -d "$(dirname "$output_dir")" ]] ||
  die "receipt directory parent must already exist"
# Atomic exclusive creation: no check-then-mkdir race and no overwrite.
mkdir -- "$output_dir" ||
  die "receipt directory already exists or could not be created"
{
  printf 'evidence_class=NATIVE_ATTEMPT_NOT_NUMERICAL_CERTIFICATE\n'
  printf 'orie_commit=%s\n' "$expected_orie"
  printf 'orie_tree=%s\n' "$(git rev-parse HEAD^{tree})"
  printf 'llvm_commit=%s\n' "$expected_llvm"
  printf 'llvm_tree=%s\n' "$(git -C "$compiler_root" rev-parse HEAD^{tree})"
  printf 'compiler_binary_sha256=%s\n' "$compiler_digest"
  printf 'clang_version=%s\n' "$("$clang_path" --version | sed -n '1p')"
  printf 'clang_path=%s\n' "$clang_path"
  printf 'clang_binary_sha256=%s\n' "$clang_digest"
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
timeout --signal=TERM --kill-after=2s 60s "$compiler" --target=host "$smoke_source" \
  > "$output_dir/scalar-smoke.ll" 2> "$output_dir/scalar-smoke.compiler.stderr" ||
  smoke_rc=$?
printf '%s\n' "$smoke_rc" > "$output_dir/scalar-smoke.compiler.exitcode"
[[ "$smoke_rc" -eq 0 && -s "$output_dir/scalar-smoke.ll" &&
   ! -s "$output_dir/scalar-smoke.compiler.stderr" ]] ||
  die "scalar source -> IR compiler admission failed; 13 ORIE guests not attempted"

smoke_link_rc=0
build_native_link_argv "$output_dir/scalar-smoke.ll" "$output_dir/scalar-smoke.native"
printf '%q ' "${link_argv[@]}" > "$output_dir/scalar-smoke.link.command"
printf '\n' >> "$output_dir/scalar-smoke.link.command"
timeout --signal=TERM --kill-after=2s 30s "${link_argv[@]}" \
  > "$output_dir/scalar-smoke.link.stdout" 2> "$output_dir/scalar-smoke.link.stderr" ||
  smoke_link_rc=$?
printf '%s\n' "$smoke_link_rc" > "$output_dir/scalar-smoke.link.exitcode"
[[ "$smoke_link_rc" -eq 0 && -x "$output_dir/scalar-smoke.native" &&
   ! -s "$output_dir/scalar-smoke.link.stdout" &&
   ! -s "$output_dir/scalar-smoke.link.stderr" ]] ||
  die "scalar IR -> native link failed; 13 ORIE guests not attempted"

capture_native_guest "$output_dir/scalar-smoke.native" \
  "$output_dir/scalar-smoke.stdout" "$output_dir/scalar-smoke.stderr" \
  "$output_dir/scalar-smoke"
[[ "$guest_rc" -eq 42 && "$capture_rc" -eq 0 &&
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


# Six fixed feature probes precede one 13-case native guest loop.
[[ -f ci/native-feature-probes.tsv && ! -L ci/native-feature-probes.tsv ]] ||
  die "missing/linked native feature probe manifest"
expected_probes="$(printf '%s\n' 'module_scalar	ci/probes/module_scalar.ores	42	EMPTY' 'array_i64	ci/probes/array_i64.ores	42	EMPTY' 'f64_scalar	ci/probes/f64_scalar.ores	42	EMPTY' 'array_f64	ci/probes/array_f64.ores	42	EMPTY' 'result_class	ci/probes/result_class.ores	42	EMPTY' 'orie_stdio	ci/probes/orie_stdio.ores	0	PASS:orie-stdio')"
cmp -s ci/native-feature-probes.tsv <(printf '%s\n' "$expected_probes") ||
  die "native feature probe manifest differs from exact six-case contract"
printf 'feature\tpath\texpected_exit\texpected_stdout\tresult\tsource_sha256\tir_sha256\tbinary_sha256\n' > "$output_dir/feature-probes.tsv"
feature_ok=0
feature_total=0
while IFS=$'\t' read -r name source expected_exit expected_output; do
  feature_total=$((feature_total + 1))
  [[ -f "$source" && ! -L "$source" ]] ||
    die "missing/linked native feature probe source: $source"
  prefix="$output_dir/feature--$name"
  ir="$prefix.ll"
  native="$prefix.native"
  result="FEATURE_COMPILER_REJECTED_UNCLASSIFIED"
  ir_digest="NONE"
  bin_digest="NONE"
  source_digest="$(sha256sum "$source" | cut -d' ' -f1)"
  printf 'compiler_command=timeout --signal=TERM --kill-after=2s 60s %q --target=host %q\n' \
    "$compiler" "$source" > "$prefix.commands"
  compile_rc=0
  timeout --signal=TERM --kill-after=2s 60s "$compiler" --target=host "$source" \
    > "$ir" 2> "$prefix.compiler.stderr" || compile_rc=$?
  printf '%s\n' "$compile_rc" > "$prefix.compiler.exitcode"
  if [[ "$compile_rc" -eq 124 ]]; then
    result="FEATURE_COMPILER_TIMEOUT"
  elif [[ "$compile_rc" -eq 0 ]]; then
    if [[ -s "$ir" && ! -s "$prefix.compiler.stderr" ]]; then
      ir_digest="$(sha256sum "$ir" | cut -d' ' -f1)"
      result="FEATURE_NATIVE_LINK_FAILED"
      build_native_link_argv "$ir" "$native"
      printf '%q ' "${link_argv[@]}" >> "$prefix.commands"
      printf '\n' >> "$prefix.commands"
      link_rc=0
      timeout --signal=TERM --kill-after=2s 30s "${link_argv[@]}" \
        > "$prefix.link.stdout" 2> "$prefix.link.stderr" || link_rc=$?
      printf '%s\n' "$link_rc" > "$prefix.link.exitcode"
      if [[ "$link_rc" -eq 124 ]]; then
        result="FEATURE_NATIVE_LINK_TIMEOUT"
      fi
      if [[ "$link_rc" -eq 0 && -f "$native" && -x "$native" &&
            ! -s "$prefix.link.stdout" && ! -s "$prefix.link.stderr" ]]; then
        bin_digest="$(sha256sum "$native" | cut -d' ' -f1)"
        result="FEATURE_GUEST_MISMATCH"
        capture_native_guest "$native" "$prefix.stdout" "$prefix.stderr" "$prefix"
        if [[ "$guest_rc" -eq 124 ]]; then
          result="FEATURE_GUEST_TIMEOUT"
        elif [[ "$capture_rc" -ne 0 ]]; then
          result="FEATURE_STDOUT_CAPTURE_FAILED"
        fi
        expected_ok=0
        if [[ "$expected_output" == "EMPTY" ]]; then
          [[ ! -s "$prefix.stdout" ]] && expected_ok=1
        else
          printf '%s\n' "$expected_output" > "$prefix.expected.stdout"
          cmp -s "$prefix.expected.stdout" "$prefix.stdout" && expected_ok=1
        fi
        if [[ "$guest_rc" -eq "$expected_exit" && "$capture_rc" -eq 0 &&
              ! -s "$prefix.stderr" && "$expected_ok" -eq 1 ]]; then
          result="FEATURE_NATIVE_GUEST_EXACT"
          feature_ok=$((feature_ok + 1))
        fi
      fi
    else
      result="FEATURE_COMPILER_INVALID_IR_OR_DIAGNOSTIC"
    fi
  fi
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    "$name" "$source" "$expected_exit" "$expected_output" "$result" \
    "$source_digest" "$ir_digest" "$bin_digest" >> "$output_dir/feature-probes.tsv"
  printf '%s %s\n' "$result" "$name"
done < ci/native-feature-probes.tsv
printf 'NATIVE_FEATURE_PROBES=%d/%d\n' "$feature_ok" "$feature_total"
[[ "$feature_total" -eq 6 ]] || die "missing native feature probe receipt rows"
if [[ "$feature_ok" -eq 6 ]]; then
  printf '%s\n' 'NATIVE_FEATURE_ADMISSION_6_OF_6 (not numerical correctness evidence)'
else
  # Attempt every ORIE fixture anyway to preserve independent diagnostics
  # for guest subsets already supported by the real native compiler.
  # The aggregate 13/13 claim is still barred until probe admission is 6/6.
  printf '%s\n' 'NATIVE_FEATURE_ADMISSION_INCOMPLETE (collecting separate guest diagnostics)'
fi

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
  printf 'compiler_command=(cd %q && timeout --signal=TERM --kill-after=2s 60s %q --target=host %q)\n' "$pkg_dir" "$compiler" "$guest" > "$output_dir/$id.commands"
  printf 'native_link_command=link_argv_from_IR_declarations\n' >> "$output_dir/$id.commands"
  printf 'guest_command=timeout --signal=TERM --kill-after=2s 10s %q\n' "$native" >> "$output_dir/$id.commands"
  result="COMPILER_REJECTED_UNCLASSIFIED"
  ir_digest="NONE"
  bin_digest="NONE"
  compile_rc=0
  (cd "$pkg_dir" && timeout --signal=TERM --kill-after=2s 60s "$compiler" --target=host "$guest") > "$ir" 2> "$compiler_stderr" ||
    compile_rc=$?
  printf '%s\n' "$compile_rc" > "$output_dir/$id.compiler.exitcode"
  if [[ "$compile_rc" -eq 0 ]]; then
    if [[ -s "$ir" && ! -s "$compiler_stderr" ]]; then
      ir_digest="$(sha256sum "$ir" | cut -d' ' -f1)"
      result="NATIVE_LINK_FAILED"
      link_rc=0
      build_native_link_argv "$ir" "$native"
      printf '%q ' "${link_argv[@]}" > "$output_dir/$id.link.command"
      printf '\n' >> "$output_dir/$id.link.command"
      timeout --signal=TERM --kill-after=2s 30s "${link_argv[@]}" > "$output_dir/$id.link.stdout" 2> "$link_stderr" ||
        link_rc=$?
      printf '%s\n' "$link_rc" > "$output_dir/$id.link.exitcode"
      if [[ "$link_rc" -eq 124 ]]; then
        result="NATIVE_LINK_TIMEOUT"
      fi
      if [[ "$link_rc" -eq 0 && -f "$native" && -x "$native" &&
            ! -s "$link_stderr" && ! -s "$output_dir/$id.link.stdout" ]]; then
        bin_digest="$(sha256sum "$native" | cut -d' ' -f1)"
        result="GUEST_EXIT_OR_OUTPUT_MISMATCH"
        capture_native_guest "$native" "$stdout" "$stderr" "$output_dir/$id"
        if [[ "$guest_rc" -eq 124 ]]; then
          result="GUEST_TIMEOUT"
        elif [[ "$capture_rc" -ne 0 ]]; then
          result="GUEST_STDOUT_CAPTURE_FAILED"
        fi
        printf '%s\n' "$marker" > "$output_dir/$id.expected.stdout"
        if [[ "$guest_rc" -eq 0 && "$capture_rc" -eq 0 &&
              ! -s "$stderr" ]] &&
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

# Detect mid-run linker/compiler replacement before publishing 13/13.
[[ "$(sha256sum "$compiler" | cut -d' ' -f1)" = "$compiler_digest" ]] ||
  die "native compiler binary changed during guest execution"
[[ "$(sha256sum "$clang_path" | cut -d' ' -f1)" = "$clang_digest" ]] ||
  die "native linker binary changed during guest execution"
printf 'NATIVE_GUEST_RECEIPT_COUNT=%d/%d\n' "$ok" "$total"
[[ "$total" -eq 13 && "$ok" -eq 13 && "$feature_total" -eq 6 && "$feature_ok" -eq 6 ]] ||
  die "not all 13 native guests executed with exact stdout; see preserved per-case diagnostics"
printf '%s\n' 'NATIVE_GUEST_EXACT_STDOUT_13_OF_13 (does not prove numerical certificates or governance)'
