# Packbound tests

For test placement and authoring rules, read [AGENTS.md](AGENTS.md). The root [project guidelines](../AGENTS.md) explain production-file ownership.

Run from the repository root with Python 3.10+ and Godot 4.7.2 console installed:

```powershell
./tests/run_tests.ps1                       # smoke suite
./tests/run_tests.ps1 -Suite all             # headless tests; rendering tests skip
./tests/run_tests.ps1 -Suite render -Render  # opt in to real rendering
./tests/run_tests.ps1 -Suite all -Test '*save*'
./tests/run_tests.ps1 -Suite all -List
./tests/run_tests.ps1 -Godot 'D:/path/godot_console.exe' -Seed 1729
python -B -m unittest discover -s tests/runner -p test_runner.py
```

## Organization

- `systems/<topic>/`: rules and state exercised without instantiating application or presentation scenes.
- `scenes/<owner>/`: focused scene behavior, input, layout and world composition checks.
- `integration/<topic>/`: tests combining game rules, persistence or multiple application scenes and flows.
- `support/`: helper-only bases, assertions, input simulation, artifact paths and cleanup; these never run a suite on their own.
- `fixtures/`: small maintained, read-only inputs. Copy mutable inputs into the test sandbox before using them.
- `components/.../<component>/tests/`: focused tests owned by a reusable component, included in the same central manifest.

`INVENTORY.md` maps the maintained suite and retained developer tools. Capture/preview/authoring utilities are not automated regression tests; the existing utilities are retained under `workspace/tasks/test-organization/retained-tools/` for deliberate reuse or later promotion into `workspace/scripts/`. They are excluded from automated discovery. Previous generated evidence was preserved under `workspace/tasks/test-organization/previous-output/`. New captures, logs, saves and results use the per-test artifact helper.

The manifest's `requires_rendering` flag describes a hard requirement. Tests with optional screenshots may run headlessly for their nonvisual assertions; use `-Render` to exercise their visual branch too. A screenshot alone is review evidence, not an automated appearance verdict. Only a completed assertion-bearing result can pass.

Suites are `smoke`, `systems`, `scenes`, `integration`, `render`, plus `all` selection. `tests/manifest.json` is validated before selection. Register each central or component-local runnable script with `id`, repository-relative `path`, `suites`, `requires_rendering`, and `timeout_sec` (greater than zero, maximum 600 seconds). Duplicate IDs/paths, missing scripts, unknown suites and unregistered `*_test.gd` / `test_*.gd` scripts fail validation. Optional `args` are Godot user arguments. Optional `phases: [{"name":"write","args":["--write"]},{"name":"read","args":["--read"]}]` launch fresh processes sharing one test sandbox. Failure stops subsequent phases.

Every test runs in a fresh Godot process. Render-required tests skip unless `-Render` is supplied; all selected tests use rendering when `-Render` is supplied; otherwise compatible tests use `--headless`. Each phase has a manifest timeout, after which only its owned process tree is terminated. Unique run IDs refuse reuse; `-RunId` permits a chosen unused name.

Test app data, saves, settings, home, cache and temporary directories are isolated beneath `workspace/tasks/test-runs/<run-id>/<test-id>/`. Windows Godot resolves `user://` beneath redirected `APPDATA/Godot/app_userdata/Packbound`, verified live using `OS.get_user_data_dir()`. Environment variables `PACKBOUND_TEST_ARTIFACT_DIR` (absolute), `PACKBOUND_TEST_SEED` (default 1729) and `PACKBOUND_TEST_ISOLATED=1` are supplied to each subprocess. Shared support guards tests against accidentally running with real player data.

Artifacts include per-phase stdout, stderr and absolute Godot logs, per-test `report.json`, and aggregate `report.json` plus `report.md`. The Markdown report lists check/failure counts, the first diagnostic and relative artifact links; console failures show a concise diagnostic. Statuses are `passed`, `failed`, `skipped`, `timed_out`. Failure or timeout exits 1; runner/manifest errors exit 2. Script/assertion errors fail even when Godot exits zero. Fatal error output stops the owned process tree promptly, with both output streams drained concurrently. Explicit test exit 2 with a timed-out diagnostic is reported as `timed_out`. Shared support emits `PACKBOUND_TEST_RESULT ` followed by JSON check/failure counts, preserved as report evidence. Legacy fallback requires explicit positive check counts and zero failures and is marked `legacy_result`; zero exit without evidence fails.

After moving scripts, run one serial Godot headless editor import before tests, using an absolute `--log-file` under task workspace logs. The runner deliberately does not launch imports or concurrent editor processes. Rendering tests require a working display; headless results do not validate appearance. Temporary diagnostic material stays in `workspace/`; maintained tests, support, manifest and runner belong in `tests/` or the owning component.
