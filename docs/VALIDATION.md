# Exact-head test and evidence policy

**Current gate status: UNEXECUTED.** These files are checked-in proposed
Oreslang guest cases, not execution receipts. No exact Java/GraalVM, LLVM,
WASM, .NET or Forge compiler run is claimed.

## Source-level guest targets

| Package | Guest file | Expected stdout |
| --- | --- | --- |
| orie-numerics | `tests/matrix_contract.ores` | `PASS:orie-numerics` |
| orie-opt | `tests/optimization_contract.ores` | `PASS:orie-opt` |
| orie-sim | `tests/simulation_contract.ores` | `PASS:orie-sim` |
| orie-plan | `tests/planning_contract.ores` | `PASS:orie-plan` |

Run **each case from its own package root** with the target backend's real
`--check` or compile mode and then execute a true Oreslang guest or
native target program. Require exact stdout, zero exit, and no unexpected
stderr. The constructor, parser, import graph and ownership checks must
reject invalid syntax rather than relying on static grep.

Pin the ORIE Git commit and tree SHA, exact compiler source SHA/tree SHA,
binary hash, toolchain and target architecture. Preserve execution logs and
actual command lines. Report `compile`, `guest-run`, `native-aot-run`
and `source-structure` as independent evidence classes; a structure
check never proves guest semantics.

## Cross-backend parity

- Java/GraalVM: exact-head check, JDK 25 guest execution, Native Image
  only if compiler/runtime truly supports it.
- LLVM: actual source -> LLVM IR -> native object/executable -> run.
- WASM: actual wasm32 artifact built from accepted source and executed in a
  worker/runtime; a native LLVM run is not WASM parity.
- .NET: actual Oreslang -> CIL -> Linux and Windows Native AOT where supported.
- Forge: actual Forge frontend -> admitted IR -> runtime execution.

If a backend does not support `Array`, `Result`, imports or modules,
record `unsupported` and a deterministic diagnostic; never count a
compiler-rejected fixture as a successful solver run.

Private source mirror policy: require independent approval of a specific
source/destination pair and full exact-blob or exact-tree verification. A
different organization's remaining Actions minutes is not itself an export
authorization.

## Numerical validation beyond smoke tests

Reference vectors should be independently computed using bounded integer
enumeration or separately validated established numerical libraries. Add
property tests, metamorphic tests, malformed CSR pointers, duplicate columns,
overflow/domain limits, zero budget, forbidden negative edge weights,
directed-cycle rejection, cancellation and repeated actor memory retirement.
A deterministic smoke output alone is not proof of optimality or memory safety.
