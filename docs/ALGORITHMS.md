# ORIE algorithm contracts (native Oreslang source prototypes)

None of these contracts is a successful guest compiler or native AOT
execution receipt. Cross-language numerical reference values do not prove
Oreslang source conformance.

## Primal tableau simplex (`orie-opt/src/simplex.ores`)

Model is `maximize c*x`, subject to `A*x <= b`, `x >= 0`,
`b >= 0`. This is one-phase primal tableau simplex with an initial slack
basis; **not revised simplex**. Entry is deterministic Bland-first-negative
and leaves by minimum ratio with basis-index tie breaking. Its statuses
are `optimal`, `unbounded`, `pivot_limit`, `numerical_failure`, plus
`Err` on invalid model admission. It cannot solve general LPs with
negative RHS, equality constraints or infeasible initial bases: such
models fail admission. Numerical tolerances are heuristic and objective/
primal residuals are rechecked; no formal optimality/dual certificate.

Source dimensions: up to 16 variables, 16 constraints, 512 pivots.
Bounded input magnitudes and tableau intermediates are checked.
A numerical failure does not return an optimal-looking assignment.

## 0/1 branch-and-bound (`orie-opt/src/branch_and_bound.ores`)

`maximize c*x`, `A*x<=b`, binary x, with nonnegative A and b.
Binary bounds are passed to the LP relaxation. Fixed 1s are subtracted
from RHS, and fixed-variable objective contribution is added back.
The zero assignment establishes a known feasible incumbent.
Every complete integral LP relaxation is rechecked against the original
constraints. Fractional LP solutions branch deterministically on the
smallest index, zero child before one child. `node_limit` is deliberately
**not** `optimal`; its incumbent is feasible but its gap is not certified.
The implementation is sequential/actor-local, not actor-parallel yet.

Source model limits: at most 8 binary variables, 8 base constraints and
1024 expanded nodes. No general mixed integrality, cuts, branching
heuristics or parallel workers. Numerical tolerance requires an
independent robustness audit before production use.

## Dense linear solve (`orie-numerics/src/linear_solve.ores`)

Up to 16x16 float matrix, partial pivoting Gaussian elimination,
small-pivot rejection and residual validation. No public LU factor or
condition number. No near-singular correctness claims.

## FIFO simulation and rolling window

`queueing.simulate_fifo` computes a deterministic sorted-arrival,
single-server queue with integer clocks, bounded jobs and overflow
checks. No scheduling policy beyond FIFO, no stochastic event engine.
`stream_window` returns a copied immutable snapshot on each push and
evicts the oldest sample when full; it is a pure actor-owned *reference*,
not an async `Channel<T>` subscription or a concurrency proof.

## Independently calculated positive oracles

- LP: max 3x+5y with 2x+y<=10 and x+3y<=12 -> x=3.6, y=2.8, value=24.8.
- Binary packing: weights (4,3,2), values (6,5,3), capacity 6 ->
  integer x=(1,0,1) value 9; LP relaxation value 9.5.
- Linear solve: [[2,1],[1,3]]x=[8,13] -> x=(2.2,3.6).
- FIFO: arrivals (0,1,5), service (3,4,2) ->
  starts (0,3,7), waits (0,2,2), total wait 4, makespan 9.
- Rolling size 2: pushes 3,5,7 -> final sum 12.

These are exact mathematical expectations for test input, not actual
guest runtime outputs. All negative/error tests remain unexecuted.

## Safety hardening (2026-10-28)

The userland LP `Model` constructor now snapshots its three input arrays,
with no public raw-buffer getters. The simplex guest regression mutates the
caller's original arrays after model construction and expects unchanged
solver behavior. Branch-and-bound branches on every strictly fractional
relaxation value instead of rounding near-integers into an unsupported proof.
If an ostensibly integral candidate fails the original constraints, or if a
fixed-variable subtraction produces an ambiguous negative RHS, the algorithm
returns an explicit error; it may never drop that node and later claim
optimality. Strict gap pruning no longer silently discards tiny positive gaps.
Neither change establishes numerical dual certificates or native runtime
proof; independent exact rational oracles remain a required acceptance gate.
