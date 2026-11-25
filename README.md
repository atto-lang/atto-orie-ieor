> **AI agent instructions (organization-wide):** Before working on code, issues, or pull requests, read and follow the [organization `AGENTS.md`](https://github.com/ores-truffle-oreslang/.github/blob/main/AGENTS.md), including its **merge-first stealth-development policy**. Honor any repository-local `AGENTS.md`, explicit holds, and GitHub-enforced rules.

# ORIE — Operations Research & Industrial Engineering for Oreslang

## AttoLang naming migration and language authority (2026-11-18)

The public language name is **AttoLang** (formerly **Oreslang**). This is the AttoLang repository `atto-lang/atto-orie-ieor`, with historical provenance in `ores-truffle-oreslang/oreslang-orie-ieor`; feature parity and original repository identity preservation are not established. Preserve historical implementation and build commands in the rest of this README. A similarly named repository is not evidence of identical commits, GitHub issue/PR history or feature status.

**[atto-lang/atto-spec](https://github.com/atto-lang/atto-spec) is the canonical normative language specification.** Use [atto-platform-conformance](https://github.com/atto-lang/atto-platform-conformance) for executable positive/negative guest fixtures, [atto-compilers-parity-testing](https://github.com/atto-lang/atto-compilers-parity-testing) for cross-backend comparisons, and [atto-common-source](https://github.com/atto-lang/atto-common-source) for portable `.atto` core/std code. Modern proposed language rules include `snake_case` callable naming, `borrow!`/`take!`/`share!`/`copy!`/`copy!!`, [default nonprimitive argument borrowing](https://github.com/atto-lang/atto-spec/blob/main/language/implicit-argument-borrow-v1.md), [static `define const` including one-time `os.read_env`](https://github.com/atto-lang/atto-spec/blob/main/language/file-module-const-v1.md), and [`<<<`/`>>>`/`ashr` shifts versus `<<`/`>>` stream I/O](https://github.com/atto-lang/atto-spec/blob/main/language/bitwise-and-stream-operators-v1.md). Contract status and compiler execution evidence take precedence over old README descriptions.

Retain actual legacy `.ores` files, CLI/package/ABI names and reproducible commands below until each replacement is separately implemented and verified. No Python scripts, CI/test support or generators for new AttoLang work; favor Rust support tooling. No feature or parity claim without exact SHA/tree, toolchain/target, real compiled guest execution and negative tests; host-only tests or zero executed CI steps count as **not executed**.

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

## Legacy migration provenance and gates

The original `ores-truffle-oreslang/oreslang-orie-ieor` repository is archived; this AttoLang repository has a separate numeric GitHub identity. Preserve historical source and reproducible build commands until replacements are independently verified. Operations research, industrial engineering and numerical experiments belong here; normative compiler semantics and unverified production optimizer claims do not.

[atto-lang](https://github.com/atto-lang) owns language libraries, compilers, tooling, tests and examples; [atto-co](https://github.com/atto-co) owns hosted deployment, tenant infrastructure, identity and billing. A future original-ID transfer or product carve-out requires separate source/target owner and independent security approval. Inventory exact SHA/tree, numeric ID, visibility, permissions, protections, PRs, releases, packages, dependencies, runners, secrets, applications, webhooks, Pages and rollback owner; verify preservation and rerun exact-head tests after an actual transfer. Never mirror private source without authorization. Zero-step jobs are NOT_EXECUTED; host-only checks do not establish native guest/compiler execution or security isolation.
