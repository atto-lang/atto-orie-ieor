# ORIE Optimization

Native Oreslang-only userland optimization algorithms and models.

- `src/linear_model.ores`: bounded 2D integer feasibility.
- `src/knapsack_dp.ores`: exact bounded 0/1 knapsack via DP.
- `src/lp_model.ores`: row-major canonical LP snapshot.
- `src/simplex.ores`: bounded one-phase **primal tableau simplex**,
  not revised simplex or full industrial LP.
- `src/branch_and_bound.ores`: bounded 0/1 packing branch-and-bound
  using LP relaxation. Not branch-and-cut or generic MILP.

These are source prototypes, not native-compiler/guest verified.
See [algorithm contracts](../../docs/ALGORITHMS.md) and
[native validation](../../docs/VALIDATION.md).
