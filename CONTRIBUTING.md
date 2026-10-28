# Contributing to ORIE

All domain algorithms belong in ORIE packages, never Oreslang core/stdlib.
Use Oreslang source for implementation and snake_case function/method names.
Use source modules, keep module scope flat, and do not introduce cross-package
relative imports that bypass package identity.

Every algorithm PR must state the mathematical domain, shape and numeric
bounds, time/space complexity, failure statuses, exact compiler/source refs,
positive and negative guest oracles, resource budget, and backend support.
Pure integer smoke kernels may be introduced before advanced f64/Decimal
lowering, but no unsupported feature may silently coerce types.

Do not add Python tooling; use Rust if source-free verification tooling is
needed. Never claim a static layout workflow verifies Oreslang guest code.
No cross-organization copying of private compiler/runtime source without
an independently approved export policy.
