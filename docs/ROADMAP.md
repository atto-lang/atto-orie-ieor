# ORIE implementation roadmap

These are **planned**, unless explicitly tagged `source-prototype`.

| Stage | Work | Acceptance |
| --- | --- | --- |
| P0a | Four v1 package roots, modules, bounded integer kernels | Source-prototype committed; real guest execution pending |
| P0b | Compiler/guest proof, negative tests, exact source hashes | Java/GraalVM first, then four other backends |
| P0c | Numerics: f32/f64/Decimal policy, dense/sparse matrix API, condition estimates | Independent high-precision oracles and actor memory budgets |
| P0d | Generic LP model, revised primal/dual simplex, presolve, basis updates | Primal/dual feasibility, degeneracy, unbounded/infeasible certificates |
| P0e | MILP branch-and-bound then branch-and-cut | Node budgets, incumbent bounds, determinism, strong adversarial tests |
| P1a | Streaming API backed by std channels, bounded windows and cancellation | Backpressure and physical retirement under load |
| P1b | Discrete-event simulation and probabilistic distributions | Seeded replay, ordering, arrival/service queue oracles |
| P1c | Graph min-cost flow, max flow, matching, critical-path and resource scheduling | Differential benchmark instances and exact results |
| P2 | Nonlinear, stochastic, robust, CP-SAT and optional external adapters | Explicit provider features and provenance, no silent fallback |

Prioritize correct single-actor reference solvers before parallel execution.
Only mark an algorithm `implemented` after end-to-end guest execution,
not because a contract or type declaration exists.

## Reusable acceptance cases

- LP: bounded feasible optimum, alternate optima, infeasible, unbounded,
  redundant constraints, degeneracy, numerical near-singularity.
- MILP: integrality, fractional LP relaxation, exact tiny enumeration
  oracle, node cutoffs, cancellation, incumbent quality, gap bounds.
- Matrix: dense/sparse equivalence, zero size rejection, ill-conditioned
  solves, overflow/NaN policy, stable pivoting, allocation budgets.
- Simulation: same-time event stable ordering, overflow, empty queue,
  deterministic seeds, time limits and cancellation.
- Planning: disconnected nodes, cycles, tie cases, negative edge rejection,
  resource conflicts, invalid capacities and precedence violations.
