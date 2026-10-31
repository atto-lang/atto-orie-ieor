# Native Oreslang test evidence policy

**Status: UNEXECUTED** for the ORIE algorithms. All implementation files
and guest test cases use **Oreslang**. No Java compilers, wrappers, Java
runtime, Java bridge, or non-Oreslang numerical implementation is admitted
to ORIE. Infrastructure shell/YAML may perform layout checks only.

## Native-first order of operations

1. Pin ORIE repo commit and Git tree SHA.
2. Use the **native Oreslang LLVM frontend and native runtime**.
   Record the exact compiler source SHA and built compiler binary digest.
3. Check each package's `.ores.pkg.toml` and relative `import module` graph
   with an actual compiler; no direct package-root traversal.
4. Run Oreslang source -> LLVM IR -> native object -> executable and
   compare exact exit, stdout and stderr against declared oracles.
5. Run negative tests for invalid shapes, limits, nonfinite numbers,
   singular systems, LP pivot/node cutoffs and graph/cycle failures.
6. Later port the same exact guest programs to WASM32, .NET Native AOT
   and Forge, using those backends' native target modes. Do not describe
   parser-only checks as guest execution.

**Blocking native backend prerequisite:** the current native LLVM
implementation admits an incomplete scalar subset; it does not yet
support arbitrary `Array<f64>`, all `Result` payloads, numerical matrix
types and module imports at the level these files require.
Do not mark these fixtures as passed until that is changed and actually
executed. Do not substitute a mock interpreter or a host-language port.

## Thirteen Oreslang reference guest test cases

| Package | Cases |
| --- | --- |
| orie-numerics | `matrix_contract.ores`, `linear_solve_contract.ores` |
| orie-opt | `optimization_contract.ores`, `simplex_contract.ores`, `simplex_status_contract.ores`, `simplex_degenerate_contract.ores`, `simplex_numerical_contract.ores`, `branch_and_bound_contract.ores`, `branch_and_bound_enumeration.ores` |
| orie-sim | `simulation_contract.ores`, `queueing_contract.ores`, `queueing_negative_contract.ores` |
| orie-plan | `planning_contract.ores` |

Expected exact stdout markers:
`PASS:orie-numerics`, `PASS:orie-linear-solve`,
`PASS:orie-opt`, `PASS:orie-simplex`,
`PASS:orie-simplex-status`, `PASS:orie-branch-and-bound`,
`PASS:orie-sim`, `PASS:orie-queueing`, `PASS:orie-plan`.

A failed or unstarted job with zero compiled source files is
**infrastructure/unverified**, not a successful or failed solver result.
Runner mirroring is restricted by private-source export policies:
funded minutes in another org do not confer export authorization.
Run native validation on authorized infrastructure or on an
approved exact-tree mirror.

## Coverage still needed

Dual feasibility, degeneracy, unbounded/negative-RHS admission,
numerical tolerance adversarial cases, branch-bound correctness,
per-case immutable input hashes, exact primal residuals, resource
limits, cancellation and physical actor retirement. Independent
reference libraries must not be included in production ORIE sources.

## Security and CI budget status (2026-10-28)

PR #1 source-organization GitHub Actions run 40639158994 had one failed job
with **zero executed steps**, and its job logs were unavailable. This is not
solver or layout execution evidence. No GitHub Actions billing API is exposed
by the connected GitHub interface, so no destination's remaining minutes are
verified simply by seeing historical successes.

The source repository is private. A different private organization's runner
cannot check out private compiler source with its local `GITHUB_TOKEN`.
A token-free Git-tree mirror is technically possible, but would still be
an **export of private source**. No independently reviewed ORIE source/destination
export approval is present, and the native LLVM compiler's explicit export
allowlist is empty. Therefore no cross-org source mirror is performed as part
of this PR. Do not export either private repository merely to work around
zero-step runs. Target discovery, CI and security approval are separate gates.

Additional native Oreslang fixture markers: `PASS:orie-bnb-enumeration`,
`PASS:orie-simplex-degenerate`, `PASS:orie-simplex-numerical`,
`PASS:orie-sim-negative`.
These are guest execution targets, not successful runtime receipts.

## Numerical false-certificate regression (2026-10-28)

A previously admitted LP with an objective coefficient of 1e-10 and a
unit upper bound could return `optimal` at objective zero because the
negative reduced cost was smaller in magnitude than the fixed epsilon.
Likewise, a 1e-10 positive pivot could be overlooked and the bounded
program incorrectly classified as `unbounded`. Native guest fixture
`simplex_numerical_contract.ores` demands `numerical_failure` in both
cases rather than either false certificate. This does not prove robust
finite-precision simplex, nor certificate support for general LPs.

The model guest fixture also now calls the public `create_model` factory
instead of the private constructor, and checks model ownership after
mutating its original caller-owned buffers. All thirteen guest cases
remain **unexecuted** until an authorized native Oreslang toolchain can
compile and run them.

## 2026-10-30 source-local hardening (no compiler receipt)

- Removed correctness-critical pruning on rounded LP upper bounds in the
  bounded 0/1 solver; preserve explicit node/pivot resource limits.
- Repaired the native enumeration guest fixture to avoid the removed
  `%` operator and forbidden implicit `int`-to-`f64` conversions.
- Hid the mutable rolling-window backing array and constructor; the guest
  contract now mutates a copied snapshot and checks historical state.

These are source changes and test *expectations*, not passed guest tests.
No native LLVM compiler, guest execution, or formal numerical certificate
has been obtained by this change.

## 2026-10-31 follow-up: machine-readable fixture inventory and native admission

`ci/guest-fixtures.tsv` pins the **13 expected exact stdout lines** by
package-relative Oreslang guest path. It is input to future native-receipt
comparisons, **not** a ledger of completed executions. The layout workflow now calls `ci/validate-guest-inventory.sh` against this
single canonical TSV, rejecting duplicate/malformed rows, path traversal,
symlinks, extra or missing fixture files, and mismatched declared markers.
This is **source-layout verification only**, not compiled or executed tests. No `PASS:` line in a
source file demonstrates guest execution.

For each row, check the exact ORIE PR head and Git tree and the compiler
source SHA/tree/binary SHA-256. Invoke the **real** native Oreslang LLVM
frontend on its package/import graph, preserve the diagnostic or emitted
LLVM IR, and (only if admitted) compile/link and execute its native
executable. Native LLVM's documented CLI starts with
`oreslang-llvmc <fixture.ores> > fixture.ll` and
`clang -x ir fixture.ll -o fixture`; a supported stdio/runtime link
contract must be established for this suite rather than assumed.

The per-row evidence categories are **COMPILER_ADMISSION** (including
explicit unsupported diagnostics), **LLVM_IR**, **NATIVE_OBJECT/LINK**,
**GUEST_EXECUTION** (zero exit, stderr empty, stdout equal to the manifest
line plus exactly one trailing newline), and **NUMERICAL_CERTIFICATE**.
Do not combine these with the independent **RUNNER_ADMISSION** or
**SOURCE_LAYOUT** gates. Record run id, attempt, job id, actual nonempty
steps, checkout head/tree, compiler source/tree/binary hashes, toolchain
versions, command lines and output hashes.

Current compiler public-source evidence: relative file/module linking
is implemented for a bounded native subset
(`oreslang-source.llvm/docs/NATIVE_MODULE_LINKING.md`), so it is
incorrect to describe *all* relative imports as categorically unsupported.
Its bounded `Array<int>` support remains nonescaping/lexical
(`docs/NATIVE_ARRAY_I64_ABI.md`), while
`docs/NATIVE_ARRAY_RESULT_TYPED_CONTRACT.md` describes a host-only
closed Result proof, **not generic guest Result lowering**. Native f64
work is tracked in LLVM issues #428 and #453. None of these adjacent
capabilities establishes ORIE `Array<f64>` / general `Result` /
class-payload guest compilation. Blocked fixtures must fail closed.

### Additional source-local safety changes

- Binary packing incumbents now require `lhs <= rhs` without a positive
  feasibility tolerance: any represented capacity violation is rejected.
  `branch_and_bound_contract.ores` adds a near-boundary (1.0 item against
  capacity 0.999999999) false-certificate regression. It expects explicit
  conservative failure **or** an independently correct zero optimum,
  never an infeasible positive optimum.
- Dense Gaussian elimination checks both each residual product and the
  accumulated residual scale against finite bounds before treating the
  computed residual as valid.

Neither change is a native guest test result or a formal real-arithmetic
certificate. Input floating-point precision and numeric conditioning still
require independent oracles and error-bound analysis.

**Current execution status:** source-org runs, including the source-free
canary, have reported `steps=[]`. No authorized runner admission,
native guest execution, numerical certificate, cross-org export approval
(issue #2), or protected-main receipt (issue #3) has been obtained.

## Fail-closed native guest gate (prepared, NOT executed)

On a trusted runner **inside an independently approved security boundary**,
prepare an exact clean ORIE Git checkout and an exact clean native LLVM
compiler Git checkout, build the genuine native compiler there, and invoke:

```sh
bash ci/run-native-fixtures.sh /absolute/path/inside-llvm-checkout/oreslang-llvmc \
  /absolute/path/to/oreslang-source.llvm \
  /absolute/path/to/fresh-receipts-dir-outside-ORIE \
  <full-40-character-ORIE-commit-SHA> \
  <full-40-character-LLVM-commit-SHA> \
  <independently-pinned-64-character-compiler-binary-sha256>
```

The gate validates the canonical TSV, exact Git heads/trees and clean tracked
source, creates an exclusive new receipt directory outside both ORIE and LLVM
source roots (existing receipt paths cannot be overwritten), records the
compiler binary hash/toolchain and per-fixture source hash,
runs real Oreslang source -> emitted LLVM IR -> Clang-linked native executable
-> native guest execution, with 60-second compiler, 30-second linker and
10-second guest timeouts, and compares **byte-exact** stdout (one trailing
newline), empty stderr, and exit status zero. It preserves per-fixture source,
IR, native binary hashes, compiler/link/guest exit codes and diagnostics.
A compiler rejection is recorded as `COMPILER_REJECTED_UNCLASSIFIED`, not
automatically called a negative test PASS. GNU timeout exit code 124 is
classified separately as `COMPILER_TIMEOUT`, `NATIVE_LINK_TIMEOUT` or
`GUEST_TIMEOUT` with per-stage exit codes and diagnostics retained.
A link failure or guest mismatch likewise blocks the aggregate 13/13 gate. No mock or host-implemented solver
fallback is permitted. An unsupported feature must be independently
classified after inspecting exact compiler stderr.

The harness is **not wired as a green required status** because source-org
GitHub Actions admission remains at `steps=[]`, and compiler support and
the stdio/runtime link contract are not yet verified. A successful harness
invocation by itself does not establish the runner-admission metadata,
compiler-binary build provenance, independent numerical certificates,
reviewer approval, or branch protection. No private LLVM source checkout
or cross-organization mirror is authorized by this script.

The local host-shell inventory validator was exercised against a synthetic
13-row tree: normal acceptance, duplicate TSV row, extra TSV column,
path traversal, package symlink, missing guest PASS print, and restored
acceptance. These tests exercise **only the Bash gate logic**, not a real
ORIE checkout, the Oreslang compiler, or the ORIE guest runtime.

## 2026-10-31 next-step CI and compiler admission split (UNEXECUTED)

- `ci/test-guest-inventory.sh` creates a **synthetic**, disposable 13-fixture
  Git workspace and exercises 15 source-layout outcomes: two valid baselines
  plus duplicate-row, extra-column, missing-tab, path-traversal, CRLF,
  symlinked-guest, missing-stdout-marker, unlisted-guest, duplicate-marker,
  linked-ledger, linked-package-root, missing-manifest and extra-manifest
  rejection. `.github/workflows/layout.yml` now invokes it after the
  canonical inventory check. These **new CI steps are configured, not
  executed** while Actions runner admission is failing before steps begin.
- `ci/scalar-llvm-smoke.ores` is an intentionally separate compiler-only
  program using the LLVM-documented signed-i64 entrypoint. It should emit
  native code that terminates with process exit code **42** and no output.
  It is not part of the 13 numerical/optimization guest fixtures, does not
  exercise their package imports, and must not count as a solver test.
- `ci/run-native-fixtures.sh` now requires **actual scalar source -> IR ->
  native executable -> process exit 42** first. It records scalar source,
  generated IR, executable hashes, and per-stage exit codes in the private
  receipt directory. If scalar admission fails, the thirteen application
  cases are not attempted. If scalar admission succeeds, ORIE's f64/Array/
  Result/class features remain separately gated; no inference of support.

**Nothing in this section constitutes native execution evidence:** GitHub
runs currently have zero executed steps and no authorized compiler binary
is connected to this draft. The scalar probe, synthetic Bash CI tests and
13 Oreslang guests must each acquire real pinned execution receipts.

## Native compiler / linker executable integrity (source patch, not a run)

The native receipt runner requires six parameters: the **real compiler
executable residing physically inside the pinned LLVM source checkout**,
LLVM Git checkout path, fresh output directory outside either repository,
full ORIE/LLVM commit hashes, and an **independently pinned native compiler
executable SHA-256**. A mismatched compiler digest fails before creating
the receipt directory. The compiler binary and native linker paths are
resolved to physical absolute executables; the linker path is reused for
both scalar smoke and 13 guest builds. Its version, path and SHA-256 are
recorded, and both executable digests are checked again before aggregate
13/13 success. These checks guard against casual mutable-PATH substitution
and changed binaries; they do **not** provide a secure boot chain, prove
compiler source reproducibility, or attest a privileged runner.

Set `umask 077` on trusted shared runners: the receipt directory and
individual LLVM IR, native binaries, logs, stdout/stderr, and provenance
must not be readable by other local users. The runner's executing user
still has access, so the runner and private-source boundary must be trusted.
Do not create a replacement certificate from host-language simulated
execution or treat GitHub Actions jobs with `steps=[]` as testing evidence.

**Admission remains blocked:** the source-org source-free canary and layout
workflow still have zero executed job steps. Only an authorized administrator
can repair Actions billing, workflow policy, or runner-group eligibility.
This documentation and script diff do not assert any native guest pass.
