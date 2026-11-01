# ORIE portable Oreslang scalar conformance (candidate, not executable parity)

## Why this slice exists

The thirteen ORIE numerical, optimization, planning and simulation guest tests
depend on features including f64 arithmetic, arrays, class values, Result, imports,
and stdout. These features are not yet available as a verified common source
execution profile in Java, LLVM, WASM, Cranelift and .NET. Do not claim that
the ORIE algorithms compile or run on all five backends.

This isolated scalar probe tests a much smaller proposed common intersection:
a zero-argument integer-returning `main`, signed i64 multiplication and a
checked-addition overflow boundary.

- `ci/portable-scalar/entry_42.ores` returns integer 42 via `6 * 7`.
- `ci/portable-scalar/checked_overflow.ores` performs
  `9223372036854775807 + 1`. It must not silently wrap and report a
  successful normal value. A compiler-time overflow diagnostic is acceptable
  only when explicitly classified as a **checked overflow** (not merely
  generic unsupported syntax); runtime checked-overflow rejection may also
  be admissible. Actual backend output and failure codes need pinned receipts.
- `ci/portable-scalar/fixtures.tsv` is the exact two-case source ledger.
- `ci/portable-scalar/backends.tsv` defines the five **expected** backend
  observation forms. These are not observed passes.

| Backend | Expected scalar 42 observation | Current admission boundary |
| --- | --- | --- |
| Java/GraalVM | Oreslang guest integer result 42 | Exact JIT/AOT/hybrid guest receipt pending |
| LLVM | Native process exit 42 | Real pinned source -> LLVM IR -> linker -> executable needed |
| WASM | Zero-import core Wasm function returns i64 42 | Requires independently pinned LLVM frontend and worker result |
| Cranelift | JIT CLI stdout exactly `42\n` | Stage-0 expression subset, not native AOT; no arrays/classes |
| .NET | Native AOT application process exits 42 | Shipping source profile is scalar; real Native AOT build needed |

The ABI differences are *not* permitted to alter the Oreslang expression's
value. Do not compare Cranelift stdout bytes directly to LLVM process exits,
or interpret a WASM return value as a process exit status.

## Evidence and promotion gates

1. Check that the exact same fixture blob and expected ledger are used in
   all five backend tests. The source-only `ci/test-portable-scalar-contract.sh`
   enforces four canonical files and seven negative mutations. It does not
   invoke a compiler, and its 8/8 result is only a fixture-integrity check.
2. Record for every backend: exact ORIE source commit/tree, guest SHA-256,
   compiler source SHA/tree, executable SHA-256, invocation, runtime mode
   (JIT, Native AOT, WASM worker), runner/job/attempt/step log, stdout/stderr
   bytes, exit status, and actual typed integer result. Reject placeholders,
   simulated host results, skipped, pending and source-only passes.
3. Run both the positive and overflow case through **real** toolchain
   execution, including error-path proof; a syntax-only frontend rejection
   cannot be credited as checked-overflow semantics without a specific,
   independently verified diagnostic.
4. Promote only the scalar profile after all five real backends agree.
   Independently implement and run the f64/Array/Result/module/stdio probes
   and the original thirteen ORIE fixtures per backend **before** promoting
   full ORIE application parity. Such capability is not implied by the
   scalar profile or the existing LLVM-only feature-probe harness.

At this stage: *all five backend native/guest receipts for this new portable
slice are NOT EXECUTED / UNVERIFIED.* The scalar fixtures are source contract
candidates, not an assertion that all five compilers accept identical syntax.

## Security and CI restrictions

The ORIE repository is private. This work adds no external checkout secrets.
No cross-organization source export is authorized by runner availability:
the independent review and exact source/destination/file allowlist in issue #2
must be approved first. Failed source-free runner jobs with no executed steps
do not prove that Oreslang source or any test ran. Preserve the existing draft
PR until independently reviewed CI/native/numerical evidence is complete.
