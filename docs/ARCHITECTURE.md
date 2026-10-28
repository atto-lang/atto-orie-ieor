# ORIE architecture and package boundaries

## Userland-only mandate

ORIE owns all domain-specific solvers and industrial engineering algorithms.
It does not change the Oreslang language, compiler, core runtime, or stdlib.
A future stdlib matrix primitive may accelerate an ORIE algorithm, but will
**never** pull the ORIE optimizer or simulation engine into the stdlib.

## Four independent Oreslang packages

1. **orie-numerics** — dense/sparse kernels; future LU/QR/Cholesky/SVD,
   condition estimates, stable linear solves, decimal/float precision policy.
2. **orie-opt** — model building, LP/MILP, primal/dual simplex, branch-and-bound,
   branch-and-cut, presolve, sensitivity, infeasibility certificates.
3. **orie-sim** — discrete-event simulation, event calendars, reproducible
   random streams, bounded windows, cancellation-safe actor pipelines.
4. **orie-plan** — shortest paths, max/min-cost flows, assignment, critical
   paths, resource-constrained and job-shop scheduling.

Each subdirectory `packages/<name>/` contains its own v1
`.ores.pkg.toml`. The repository root has no project manifest so compiler
discovery cannot accidentally merge independent package roots. Source modules
have unique public names; Oreslang flat namespaces, if adopted, should not
introduce implicit cross-package export. Nested module declarations are
not used. A future package registry must pin versions and dependency
identities; relative imports that cross package roots are forbidden.

## Current source maturity

The initial eight library modules are narrow, bounded **reference
algorithms** with Oreslang guest fixtures. They are not proof of compiler
acceptance or numerical reliability, and they are not general solvers.
In particular:

- `knapsack_dp` is an exact bounded 0/1 dynamic program, **not**
  branch-and-bound or a MILP solver.
- `linear_model` tests two-variable integer feasibility; it does not
  optimize arbitrary linear models.
- `event_calendar` stores sorted timestamps, not arbitrary actor
  callbacks, network event feeds or physical queue retirement.
- `window_stats` is a pure batch oracle, not a streaming runtime.
- `precedence` assumes unlimited resources and a DAG.
- All numerical reference kernels use validated bounded signed integers;
  no silent binary64 narrowing, exact-decimal or floating-point parity claim.

## Later solver architecture

A solver is an actor-owned engine with a versioned model snapshot, separate
immutable admission/validation, and a bounded progress channel.
Any branch-and-bound worker may own its local search tree, and all incumbent
improvements must have deterministic tie-breaking and safe mailbox admission.
Cancellation must not retire arenas while borrows, I/O or FFI callbacks remain.

A `Result<Solution, SolverError>` should distinguish `optimal`,
`feasible`, `infeasible`, `unbounded`, `cancelled`, `resource_limit`,
`numerical_failure` and `unsupported`. Objective bounds, primal/dual
residuals, proof/certificate information and solver tolerances should be
explicit. Never return an unqualified optimal result from a heuristic.

Optional adapters to HiGHS/OR-Tools can live in userland with explicit FFI
permissions; they are not a mandatory runtime dependency.

## Compatibility gates

Compiler support for `define module`, manifest-root discovery, relative
multi-file import linking and ownership-safe Array borrowing must be proven.
The first supported execution gate is a native LLVM Oreslang compiler,
followed by genuine WASM32, .NET Native AOT, and Forge guest execution.
No host-language implementation or bridge is a substitute for native Oreslang
source. An unsupported backend must reject explicitly.
No private source may be mirrored to a foreign CI organization without
independent export authorization. See [validation](VALIDATION.md).
