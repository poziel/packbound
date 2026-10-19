# Test authoring and maintenance

These instructions supplement the root [AGENTS.md](../AGENTS.md). They also define the conventions for component-local tests referenced by the root instructions. See [README.md](README.md) for runner details and [INVENTORY.md](INVENTORY.md) for the ownership inventory.

## Choose the owner and contract

Before adding a test, inspect the code and current consumers, then identify the behavior that should stay true. Extend an existing focused test when it already owns that contract. Create a separate test when it covers an independent behavior or needs different setup/capabilities.

| Test scope | Destination |
| --- | --- |
| Rules, calculations, state or serialization without presentation scene setup | `tests/systems/<topic>/<behavior>_test.gd` |
| Focused menu, run, world or shared scene behavior | `tests/scenes/<owner>/<behavior>_test.gd` |
| Rules plus UI, save/reopen journeys or multiple application flows | `tests/integration/<topic>/<behavior>_test.gd` |
| A component's public behavior in isolation | `<component>/tests/<behavior>_test.gd` |

Organize by responsibility; add deeper folders only when a topic needs them. A mixed test belongs in integration even if its name mentions a system. Keep component tests with their package rather than copying them centrally. Use lowercase `snake_case` and descriptive behavior names; keep existing stable test IDs when moving or renaming files. Move paired `.uid` files too.

Test observable outcomes and explicit authoring contracts. Prefer public behavior over source-text matches, exact child counts, incidental node order or private implementation details. Preserve deliberate pixel geometry, scene ownership, resource identity and timing contracts when they are the behavior under test. Assert that inspection/previews preserve game state where relevant. Do not silently update an expected value to match a regression.

## Build on helper-only support

Extend `res://tests/support/test_case.gd` or the smallest applicable helper-only base in `tests/support/`. Runnable tests must never inherit from other runnable tests. Support scripts may provide fixtures and assertion helpers but must not automatically execute a parent scenario.

Normally implement `_run()`; the common base verifies isolation and schedules it. If a test genuinely must override `_initialize()`, call `require_isolation()` and return immediately when it fails, before test setup or mutations.

Use `check(condition, message)` for predicates and `check_equal(actual, expected, message)` for comparisons. Messages should identify the behavior and relevant fixture/item/phase. Comparison failures should expose actual and expected values. Use counted checks rather than native `assert()`, which can abort a callback and leave Godot running without a result. If a failed prerequisite makes later accesses unsafe, report and exit nonzero rather than continuing into null/invalid objects.

Finish with `report("DESCRIPTIVE RESULT")` and `quit(1 if failures else 0)`, including early failure exits. Do not print unconditional success messages. A zero process exit is not sufficient evidence of a passing test; a completed result must contain positive check counts and zero failures.

Example of the common lifecycle (adapt the behavior and fixture to the actual change):

```gdscript
extends "res://tests/support/test_case.gd"

func _run() -> void:
    var state := PackRun.new()
    state.reset(42, "warrior")
    state.hp = 1
    state.reset(42, "warrior")
    check_equal(state.hp, state.max_hp, "Starting a fresh run restores health")
    report("FRESH RUN HEALTH")
    quit(1 if failures else 0)
```

Use the project's tab indentation in actual GDScript files. The example is a lifecycle reference, not a requirement to add redundant reset tests.

## Deterministic setup and bounded execution

- Use small explicit fixtures and deterministic seeds. The runner supplies `PACKBOUND_TEST_SEED`; fixtures may intentionally use a different fixed seed. Identify that fixture seed in diagnostics when it matters. Do not randomize without recording the seed.
- Keep immutable sample saves/settings/test scenes under `tests/fixtures/`. Copy them into the sandbox before mutation. Prefer a short fixture builder when a static file adds no coverage. Do not duplicate production assets as fixtures.
- Wait for a signal or observable condition with a deadline. A frame wait is appropriate for known deferred layout; arbitrary longer sleeps are not a substitute for checking completion. Bound loops, simulation steps and state-machine progress explicitly.
- A test bot must handle the current game phases and use legal actions. Clone complete state through the owning serialization contract when needed; verify clone fidelity rather than copying a stale hand-picked field list.
- Clean up spawned scenes, viewports, tweens and audio. Reuse the support cleanup helpers where applicable. Keep mutable test state local to its process; phased persistence tests may share their own sandbox.

## Register every runnable test

Add or update an entry in `tests/manifest.json`. Both central and component-local tests must be registered. Use a unique stable `id`, repository-relative `path`, owner suite (`systems`, `scenes` or `integration`), `requires_rendering`, and `timeout_sec`. Add `smoke` only for a fast representative regression; add `render` for rendering-required coverage. `all` is a runner selection, not a manifest suite.

```json
{
  "id": "fresh_run_health",
  "path": "tests/systems/runs/fresh_run_health_test.gd",
  "suites": ["systems"],
  "requires_rendering": false,
  "timeout_sec": 30
}
```

The supported timeout range is greater than zero and at most 600 seconds. Choose a measured, realistic process timeout with room for a test's internal deadline and teardown. Do not increase it to conceal a hang. `args` are user arguments after Godot's `--`; use `phases` for fresh-process write/read journeys that share one test sandbox. See the existing save-reopen entry and README for the supported shape.

## Isolation, artifacts and rendering

Run tests through `tests/run_tests.ps1`. The runner isolates app data, settings, saves, home, cache and temporary files under `workspace/tasks/test-runs/<run-id>/<test-id>/`. The common base checks the actual `user://` location before setup; the runner also validates it in structured results. Do not bypass these checks or manually set the isolation marker to run against real player data.

Use `artifact_path("relative/path")` or `tests/support/artifact_paths.gd` for generated screenshots, saves and diagnostic files. Never write them into `tests/`, production assets, `.tmp/` or a previous task's folder. Engine logs use the runner's explicit absolute `--log-file` path.

Set `requires_rendering` when an assertion depends on a framebuffer, GPU readback, drawing or rendering callbacks. Such tests skip without `-Render`. CPU-only image/geometry checks do not automatically require rendering. Optional screenshots must be guarded and must not make a headless run claim visual coverage. `-Render` enables the renderer for every selected test, including optional visual branches.

Captures, previews, reviews, bake scripts and migrations are development tools, not regression tests. Keep task-specific tools in `workspace/tasks/<task-name>/` and reusable helpers in `workspace/scripts/` or their maintained owning tool package. A screenshot is evidence for review; automated appearance claims need meaningful assertions.

## Verify and report the change

From the repository root:

```powershell
./tests/run_tests.ps1 -Suite all -Test '<stable_test_id>'
./tests/run_tests.ps1 -Suite smoke
./tests/run_tests.ps1 -Suite render -Test '<stable_test_id>' -Render
```

Use the rendering command when the changed contract needs it. After relocating scripts/resources, run one serial Godot headless editor import with an absolute log path in the task workspace before suites. Avoid concurrent imports. When modifying the runner, run its Python regression tests as documented in README.md. Broaden testing when changed shared behavior, failures or unresolved concerns justify it.

Review the failing case before and after a regression fix. A migration should preserve coverage and update static paths, dynamically assembled paths, manifest entries and active documentation. Keep historical run reports unchanged.

Read the generated `report.json` and `report.md`, plus relevant stdout/stderr/Godot logs. Distinguish `passed`, `failed`, `skipped` and `timed_out`; a rendering skip is not a visual pass. Report the exact scope, actual results, seed and useful artifact paths. Diagnose whether a failure is a regression, a stale test contract or an environment/capability issue. Never delete assertions, add skips or change production gameplay merely to obtain a green summary. Keep volatile baseline counts in workspace reports rather than these instructions.
