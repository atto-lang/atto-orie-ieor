# ORIE native-only engineering roadmap

ORIE algorithms are implemented in Oreslang `.ores` files, never Java or
other host-language solvers. No solver belongs in core or stdlib.

| Stage | Status | Required outcome |
| --- | --- | --- |
| Four package roots and bounded integer kernels | source prototype | Native compiler + guest oracles |
| Dense Gaussian elimination and residual checks | source prototype | Genuine native f64/Array lowering and ill-conditioned cases |
| Canonical LP model + primal tableau simplex | source prototype | Native execution, degeneracy/duality and numerical certification |
| Bounded 0/1 branch-and-bound using LP relaxations | source prototype | Exact enumeration differential tests, cutoff, feasibility proof |
| Deterministic FIFO and streaming window | source prototype | Guest results and invalid-input rejection |
| Revised primal/dual simplex and Phase I feasibility | planned | Basis factorization, warm starts, robust infeasible/unbounded certificates |
| Generic integer MILP + branch-and-cut | planned | Bounds, integrality, cuts, strong negative oracles |
| Actor-parallel optimization and sim workers | planned | Isolated actor-owned state, bounded Channel backpressure, deterministic barrier/reduction and cancellation |
| Sparse LU/QR/Cholesky, graph flow, scheduling | planned | Stable numerics, precise constraints, independent solver oracles |
| Native LLVM, then WASM32/.NET/Forge parity | blocked | Exact SHA check/compile/execute; never infer parity from source alone |

First native gate is to enable the needed f64, Array, Result and module-linking
support in the LLVM Oreslang compiler, **without** adding host-language
implementations to ORIE. ORIE must stay a userland consumer.

## Acceptance inputs

Primal simplex: feasible 24.8 optimum, invalid negative RHS, unbounded
canonical model, degenerate pivots, pivot exhaustion, independent LP oracle.
Branch-and-bound: 9 objective packing case where LP relaxation is 9.5,
explicit `node_limit` rather than false `optimal`, malformed input,
integer enumeration, resource bounds and numerical failure.
Simulation: FIFO 4 total wait/9 makespan, stable time ordering and
moving-window eviction, time and capacity violations.
