# ORIE Optimization

Linear feasibility primitives and bounded exact 0/1 knapsack DP.

**Stage:** experimental Oreslang source with deterministic expected-output
fixtures. Compiler acceptance, runtime execution, performance, and parity
with Java/GraalVM, LLVM, WASM, .NET and Forge are **not** yet demonstrated.

This directory is a **separate package root** using its own
`.ores.pkg.toml`. Source files expose flat `define module` namespaces
and snake_case public functions. No solver has been added to language core
or standard library. The package is not allowed to import another ORIE
package via relative filesystem traversal; dependency resolution must be
explicitly designed, version-pinned, and proven first.

See `src/` for APIs and `tests/` for standalone Oreslang guest fixtures.
