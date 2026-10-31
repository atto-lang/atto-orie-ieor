#!/usr/bin/env bash
# Source-free host-shell tests ONLY for the real native link-argv builder and
# stdout capture function. Neither a compiler nor Oreslang guest is invoked.
set -euo pipefail
export LC_ALL=C
umask 077
root="$(git rev-parse --show-toplevel)"
scratch="$(mktemp -d)"
trap 'rm -rf -- "$scratch"' EXIT

# Import the exact two function bodies from the checked-out harness rather
# than duplicating implementations or sourcing its top-level compiler runner.
for fn in build_native_link_argv capture_native_guest; do
  awk -v signature="$fn()" '
    $0 == signature " {" { inside=1; found=1 }
    inside { print }
    inside && $0 == "}" { exit }
    END { if (!found) exit 81 }
  ' "$root/ci/run-native-fixtures.sh" >> "$scratch/functions.sh" ||
    { echo "ORIE_TRANSPORT_TEST_MISSING_FUNCTION: $fn" >&2; exit 1; }
done
die() { printf '%s\n' "ORIE_TRANSPORT_TEST_EXPECTED_REJECT: $*" >&2; exit 81; }
# This is an argv-inspection test. /bin/true is NOT invoked as a linker.
clang_path="/bin/true"
compiler_root="$scratch/llvm"
runtime="$compiler_root/src/main/cpp/oreslang/runtime"
mkdir -p "$runtime"
touch "$runtime/NativeStringRegion.c" "$runtime/NativeRecordRegion.c" \
  "$runtime/NativeIntArrayRegion.c"
source "$scratch/functions.sh"
checks=0
check() { checks=$((checks+1)); printf 'ORIE_TRANSPORT_TEST_PASS %s\n' "$1"; }
in_argv() {
  local needle="$1" v
  for v in "${link_argv[@]}"; do
    [[ "$v" != "$needle" ]] || return 0
  done
  return 1
}
ir="$scratch/guest.ll"
native="$scratch/guest.native"
printf '%s\n' 'define i32 @main() { ret i32 0 }' > "$ir"
build_native_link_argv "$ir" "$native"
[[ "${link_argv[0]}" == "$clang_path" ]] &&
  in_argv "$ir" && ! in_argv "$runtime/NativeStringRegion.c" &&
  ! in_argv "$runtime/NativeRecordRegion.c" &&
  ! in_argv "$runtime/NativeIntArrayRegion.c" && ! in_argv -pthread
check scalar_ir_no_c_runtime

printf 'declare void @ores_string_test()\n' > "$ir"
build_native_link_argv "$ir" "$native"
in_argv "$runtime/NativeStringRegion.c" && in_argv -pthread
check string_runtime_link

printf 'declare void @ores_record_test()\n' > "$ir"
build_native_link_argv "$ir" "$native"
in_argv "$runtime/NativeRecordRegion.c" && in_argv -pthread
check record_runtime_link

printf 'declare void @oreslang_int_array_test()\n' > "$ir"
build_native_link_argv "$ir" "$native"
in_argv "$runtime/NativeIntArrayRegion.c" && in_argv -pthread
check integer_array_runtime_link

rm "$runtime/NativeIntArrayRegion.c"
if ( build_native_link_argv "$ir" "$native" ) >/dev/null 2>&1; then
  echo 'ORIE_TRANSPORT_FALSE_ACCEPT: missing native runtime source' >&2; exit 1
fi
check missing_runtime_fails_closed
ln -s /etc/passwd "$runtime/NativeIntArrayRegion.c"
if ( build_native_link_argv "$ir" "$native" ) >/dev/null 2>&1; then
  echo 'ORIE_TRANSPORT_FALSE_ACCEPT: symlinked native runtime source' >&2; exit 1
fi
check symlinked_runtime_fails_closed

guest="$scratch/pipe-guest.sh"
printf '%s\n' '#!/usr/bin/env bash' \
  '[[ -p /dev/stdout ]] || exit 88' \
  'printf "PASS:pipe\n"' > "$guest"
chmod 0700 "$guest"
capture_native_guest "$guest" "$scratch/pipe.stdout" "$scratch/pipe.stderr" \
  "$scratch/pipe" 2>/dev/null
[[ "$guest_rc" -eq 0 && "$capture_rc" -eq 0 &&
   ! -s "$scratch/pipe.stderr" ]] &&
  cmp -s "$scratch/pipe.stdout" <(printf 'PASS:pipe\n')
check guest_stdout_is_pipe_and_captured_exactly

printf '%s\n' '#!/usr/bin/env bash' 'exit 42' > "$guest"
capture_native_guest "$guest" "$scratch/exit42.stdout" "$scratch/exit42.stderr" \
  "$scratch/exit42" 2>/dev/null
[[ "$guest_rc" -eq 42 && "$capture_rc" -eq 0 &&
   ! -s "$scratch/exit42.stdout" && ! -s "$scratch/exit42.stderr" ]]
check guest_exit42_preserved

printf '%s\n' '#!/usr/bin/env bash' 'printf "x\n"' > "$guest"
capture_native_guest "$guest" /dev/full "$scratch/fill.stderr" \
  "$scratch/fill" 2>/dev/null
[[ "$capture_rc" -ne 0 ]]
check stdout_capture_failure_detected

[[ "$checks" -eq 9 ]] ||
  { echo "ORIE_TRANSPORT_INCORRECT_TEST_COUNT=$checks" >&2; exit 1; }
printf 'ORIE_SOURCE_FREE_LINK_TRANSPORT_TESTS_PASS=%d (no compiler or Oreslang guest)\n' "$checks"
