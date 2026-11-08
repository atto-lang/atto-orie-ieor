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

## Repository ownership and migration (2026-11-08)

**AttoLang** is the public name of the language; this code remains `ores-truffle-oreslang/oreslang-orie-ieor` (historical Oreslang). Preserve existing `.ores` source compatibility, old package names and CLI identifiers until separately proven changes are merged.

- **Scope:** operations research/industrial engineering examples and numerical model experiments.
- **Excluded:** normative compiler semantics or production business optimizer claims.
- **Organizational responsibility:** [atto-lang](https://github.com/atto-lang) owns portable language libraries, research code, compilers, tooling, demos and conformance; [atto-co](https://github.com/atto-co) independently owns cloud hosting, deployments, tenant infrastructure, identity, commercial services and billing. Pre-existing similarly named `atto-*` repositories are distinct Git identities absent transfer receipts.
- **Proposed first migration:** authorized GitHub transfer of the same original repo ID/name/history into `atto-lang/oreslang-orie-ieor`; no direct old-org → `atto-co` transfers are approved under the current plan. Any later product carve-out requires independent review.

**Per-repo cutover checklist:** coordinate in [issue #26](https://github.com/ores-truffle-oreslang/.github/issues/26) and consult private [migration runbook draft #25](https://github.com/ores-truffle-oreslang/.github/pull/25). Before moving, verify exact commit SHA/tree and stable numeric ID, source/target owner and independent security approval, destination availability/visibility/protections, Actions/runners, secrets, webhooks, Apps, PRs/releases, packages/consumer URLs, Pages and rollback owner. Don't mirror private source without authorization. After an approved GitHub ownership transfer verify ID/history/tree equivalence, restore access and policy, update consumers and rerun exact-head tests with **nonzero executed steps**. `steps=[]`/`null` means `NOT_EXECUTED`; static or host-only tests do not certify real AttoLang guest code or security isolation.
