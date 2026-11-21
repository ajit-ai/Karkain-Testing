# Karkain-Testing

Framework-level test suite infrastructure for the Karkain ecosystem.

- **Language baseline:** Karkain Language v1.2.0 (verified tag `v1.2.0`,
  commit `77d70693e1e3134dac312a303bffafa7d50fa988`).
- **Framework version:** `0.1.0-dev`.
- **Status:** VERIFIED — core implemented, native tests and integration
  verification executed with the real v1.2.0 compiler.
- **Repository model:** independent repository; no submodules and no shared
  Git history with other framework repositories.

## Purpose

Karkain already provides hard assertions (`assert`, `assert_eq`, `assert_ne`)
and the `std.testing` helper module. This framework adds a distinct layer:
**named, soft, accumulating checks**. A suite records every check with a
label and diagnostic detail, continues after failures, and reports all
results at once. It is intended for test harnesses and diagnostic programs
built with Karkain v1.2.0.

This repository does not reimplement the standard library assertion helpers
and does not claim any unimplemented language feature.

## Public API

Module: `src/ktesting.kark` (import as `ktesting`; call as `ktesting.<fn>`).

| Function | Purpose |
|---|---|
| `new_suite()` | Create an empty check log. |
| `record(suite, ok, label, detail)` | Append a raw check entry. |
| `check(suite, label, ok)` | Record a named boolean check. |
| `expect_true(suite, label, cond)` | Record a truth check. |
| `expect_false(suite, label, cond)` | Record a falsity check. |
| `expect_eq(suite, label, actual, expected)` | Record an equality check with detail. |
| `expect_ne(suite, label, actual, unexpected)` | Record an inequality check with detail. |
| `fail(suite, label, detail)` | Record an unconditional failure. |
| `note(suite, label, detail)` | Record an informational passing entry. |
| `total_count(suite)` | Number of recorded checks. |
| `passed_count(suite)` | Number of passing checks. |
| `failed_count(suite)` | Number of failing checks. |
| `all_passed(suite)` | Whether every recorded check passed. |
| `summary(title, suite)` | Build a one-line summary string. |
| `report(title, suite)` | Print the full report; return overall status. |
| `require_pass(title, suite)` | Report and hard-fail the program on any failure. |

Arrays are values in Karkain v1.2.0, so every adding function returns the
updated suite: `suite = ktesting.check(suite, "name", ok)`.

## Layout

```text
Karkain-Testing/
├── src/ktesting.kark       # framework implementation (public API)
├── src/verify.kark         # integration program consuming the public API
├── tests/api_tests.kark    # native test_* bodies (10 tests)
├── examples/suite_demo.kark# runnable usage example
├── scripts/verify.ps1      # verification gate for the real v1.2.0 toolchain
├── COMPATIBILITY.md        # evidence-based baseline assessment
├── karkain.toml            # project manifest (version 0.1.0-dev)
├── VERSION
└── .gitignore
```

## Build and verification

A Karkain v1.2.0 toolchain is required. The verification script accepts
paths to the compiler and source checkout (see its parameter block):

```powershell
powershell -ExecutionPolicy Bypass -File scripts\verify.ps1
```

It runs five gates:

1. `karkain check` on the framework module.
2. `karkain test` on a generated single-file program containing the real
   module source plus all 10 native tests (expected: 10 passed, 0 failed).
3. `karkain run src/verify.kark` exercising the full public API, including
   negative cases (expected exit 0).
4. A negative gate using `assert(false)` (expected exit code 4), proving the
   harness detects failures.
5. A runnable example executed with the real compiler.

`karkain test` in v1.2.0 cannot resolve `import` statements, so gate 2
concatenates the module source with the test bodies in a temporary file.
This tests the actual module code without duplicating it.

## Dependencies

None. The implementation uses only verified Karkain v1.2.0 language
builtins and its own source. No framework-to-framework dependency is
introduced.

## Known limitations

- The check log stores entries in a mixed-type array (triples of
  `ok`, `label`, `detail`); v1.2.0's stable subset used here has no structs.
- Local imports resolve from the entry file's directory; consumers must
  place `ktesting.kark` beside their program or use a build step that stages
  it (as `scripts\verify.ps1` does).
- `report` prints failure lines but does not choose an OS exit status. Use
  `require_pass` when a non-zero exit status is required.
- No cross-platform, WASM, GPU, NPU, quantum, networking or database support
  is claimed. See `COMPATIBILITY.md` for verified boundaries.
