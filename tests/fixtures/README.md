# Test fixtures

Keep small, deterministic inputs shared by tests here: authored test scenes, legacy save/settings examples, and representative content records. Group by topic when needed.

Treat committed fixtures as read-only. A test that modifies a save or settings file must copy the fixture into its isolated run directory first. Generated screenshots, logs, results and temporary saves belong under `workspace/tasks/test-runs/`, never alongside fixtures.

Prefer a short seeded fixture builder in `tests/support/` when a static file adds no useful coverage. Do not copy the game's complete production assets into this folder.
