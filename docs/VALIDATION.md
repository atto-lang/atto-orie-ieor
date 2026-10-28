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

## Nine Oreslang reference guest test cases

| Package | Cases |
| --- | --- |
| orie-numerics | `matrix_contract.ores`, `linear_solve_contract.ores` |
| orie-opt | `optimization_contract.ores`, `simplex_contract.ores`, `simplex_status_contract.ores`, `branch_and_bound_contract.ores` |
| orie-sim | `simulation_contract.ores`, `queueing_contract.ores` |
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
