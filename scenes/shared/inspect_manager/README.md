# Inspection manager

`PackInspector` owns hover-trigger registration, delayed opening, nested
inspection, placement and branch lifetime. `PackInspectWindow` owns the visible
tooltip, lock indicator, keyword rendering and its per-tooltip lifetime state.

Call `register(control, provider)` for inspection triggers, `register_links(label)`
for inline definition triggers, and `apply_timing(settings)` when preferences
change. `clear()` removes the whole chain. No tooltip takes keyboard focus.

The four settings are `tooltip_opening_delay`, `tooltip_lock_delay`,
`tooltip_grace_delay` and `tooltip_closing_delay`. They apply at every depth.
Locking requires trigger hover after opening; unlocked tooltips close immediately
on trigger exit. Locked tooltips use grace before first entry and closing delay
after entry. Hovering a descendant protects its ancestors. Returning to a trigger
retains its tooltip and schedules descendants for closing. Closing any ancestor
removes descendants together, without cascading delays. Zero delays are valid.

Lifetime checks are in `tests/systems/ui/tooltip_rules_test.gd`; rendered pointer and placement
checks are in `tests/systems/ui/tooltip_opening_test.gd` and
`tests/scenes/run/click_keyword_regression_test.gd`. Settings persistence and slider limits
are checked by `tests/scenes/shared/tooltip_timing_settings_test.gd`.

Repeated subjects open independent descendants with no depth limit. Only an
already open descendant of the same trigger occurrence is reused. The
`tooltip_repeated_subject_test.gd` regression builds a 56-window chain.

Placement uses the trigger's control bounds or native shaped keyword line
fragment, with a 12 UI-pixel gap. Right, left, below and above are tried in that
order; oversized contents scroll within the chosen non-overlapping region.
Moving within a trigger does not change its anchor. Viewport/source layout
changes reflow open tooltips. `tooltip_placement_test.gd` covers recipe controls,
wrapped links, repeated log keywords, viewport edges and resized layouts.
