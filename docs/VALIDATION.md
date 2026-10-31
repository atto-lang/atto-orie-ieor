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
