# ORIE — Operations Research & Industrial Engineering for Oreslang

ORIE is a **userland-only** Oreslang monorepo for industrial engineering,
operations research, mathematical optimization, simulation, and planning.

**Status: experimental reference sources; no validated Oreslang compiler or five-backend execution receipt yet.**
No solver is part of Oreslang core or stdlib. Numeric scalar and collection
primitives can come from those layers, but ORIE owns the domain algorithms.

The four independently rooted packages are:

| Package | Scope |
| --- | --- |
| [orie-numerics](packages/orie-numerics/) | Dense/sparse-oriented linear algebra reference kernels and numerical contracts |
| [orie-opt](packages/orie-opt/) | Optimization models and bounded exact discrete reference solvers |
| [orie-sim](packages/orie-sim/) | Deterministic event queues, windows and simulation reference primitives |
| [orie-plan](packages/orie-plan/) | Graph algorithms and precedence scheduling |

Read [architecture](docs/ARCHITECTURE.md), [acceptance gates](docs/VALIDATION.md),
and [roadmap](docs/ROADMAP.md). Public APIs are provisional until real compiler,
guest, and independent numerical oracle tests complete.

Each package owns its `.ores.pkg.toml` manifest; **the monorepo root is
not an Oreslang package root**. Avoid implicit cross-package imports or
pretending multi-file/package graph linking is already portable. All source
module functions use snake_case.
