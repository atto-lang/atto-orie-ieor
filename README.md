# ORIE — Operations Research & Industrial Engineering for Oreslang

ORIE is a **native Oreslang-only userland monorepo** for industrial engineering,
operations research, mathematical optimization, numerical methods and simulation.
There are **no Java implementations, wrappers, dependencies or Java-based test
requirements** in the ORIE source policy.

**Status:** algorithm source prototypes, not compiler-verified. Exact-head native
LLVM guest execution remains blocked by missing general Oreslang f64/Array
compilation and full package linking support. Structural checks are not
numerical or runtime verification.

| Package | Algorithms and models |
| --- | --- |
| [orie-numerics](packages/orie-numerics) | bounded dense and CSR integer kernels; experimental f64 Gaussian elimination |
| [orie-opt](packages/orie-opt) | packing feasibility, exact integer knapsack DP, bounded primal tableau simplex, 0/1 branch-and-bound |
| [orie-sim](packages/orie-sim) | stable event calendar, moving windows, deterministic FIFO queue simulation and incremental window snapshots |
| [orie-plan](packages/orie-plan) | nonnegative shortest paths, precedence DAG earliest-finish scheduling |

Every package has its own `.ores.pkg.toml` and flat `define module`
namespaces; cross-package dependencies must be explicit and version-pinned
instead of source-tree traversal. Algorithms stay **out of the Oreslang
compiler, runtime, core and standard library**.

See [architecture](docs/ARCHITECTURE.md), [native validation](docs/VALIDATION.md),
[algorithm limits](docs/ALGORITHMS.md), and [roadmap](docs/ROADMAP.md).

The new solver stages are **source prototypes**. The simplex code is a
bounded one-phase **tableau** method, not revised simplex and not a general
LP solver. The binary branch-and-bound code solves a narrow nonnegative
packing model by repeatedly calling its LP relaxation; it is not
branch-and-cut, CP-SAT, or arbitrary MILP. No actor-parallel runtime or
cancellation/retirement proof is claimed.
