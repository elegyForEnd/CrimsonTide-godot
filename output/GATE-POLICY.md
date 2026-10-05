# ROGUE GATE POLICY (R18 preparation)

Owner: top-level dispatcher. Written by the R18-prep round.
Last measured: **2026-10-05, 20:12:16 (register), 20:14:06 (judge), 20:16:38 (post-class-cache re-run)**, `HEAD b034286`, engine `Godot_v4.7.2-stable_win64_console.exe`.
Artifacts of those runs: `build/gate-20261005-201216/`, `build/gate-20261005-201406/`, `build/gate-20261005-201638/`, `build/gate-20261005-201551/` (windowed UI case).

---

## 1. Tooling

| File | Role |
|---|---|
| `tools/run_all_tests.ps1` | Whole-suite batch runner (183 `tests/*.gd`). Hardened in this round. |
| `tools/run_rogue_gate.ps1` | **The gate.** Rogue + core regression set, failures-only judgement, exemptions, writer check. |
| `tools/verify_rogue_build.ps1` | Legacy. **NOT a gate** — see below. |
| `tools/check_class_cache.ps1` | Rebuilds `.godot/global_script_class_cache.cfg` when new `class_name`s appear. |

`verify_rogue_build.ps1` throws on **any** `ERROR:` line, so it can never pass in this tree (`rogue_build_rules` aborts on its first check, `rogue_build_pack` has a missing icon). It is kept for historical use only; use `run_rogue_gate.ps1`.

### Host quirks (cost real debugging time, do not re-learn them)
* **There is no `pwsh` on PATH here.** Invoke scripts as `& .\tools\run_rogue_gate.ps1` from the repo root, or `powershell -ExecutionPolicy Bypass -File tools\run_rogue_gate.ps1`. `pwsh -File ...` fails with `CommandNotFoundException`.
* **`Start-Process -PassThru` never surfaces `ExitCode` here** (Windows PowerShell 5.1, empty for both headless and windowed Godot runs; `Refresh()` does not help). The gate therefore judges on the summary line, the runtime-error count and the timeout state — an exit code would have been strictly less informative anyway.

---

## 2. Gate rules

1. **Only `failures` is judged.** `checks` is recorded and printed but may float freely: new assertions legitimately move it, and mid-flight writers move it too.
2. **PASS iff `failures <= baseline.failures`.** A test with an existing baseline of 1 (e.g. `boss_tactics`) passes at 1 but fails at 2. A test with no baseline entry must be green (0 failures).
3. **A run with no `<n> checks, <n> failures` summary line is a FAILURE** (`FAIL:NO-SUMMARY`), unless the test is exempt. This is the concrete fix for "a runtime error aborts the body before `quit()`, so the process idles forever and looks silent instead of red".
4. **A run killed by the wall-clock budget is a FAILURE** (`FAIL:TIMEOUT`).
5. **Missing test file is a FAILURE** (`MISSING`).
6. **Exempt tests are measured and reported, never judged.** They run with a small frame cap so they cannot slow the gate down.
7. **Mid-flight writers are surfaced.** Before running, the gate lists any file under `scripts/`, `tests/`, `resources/` written in the last 5 minutes and prints `[warn] ... numbers may be mid-flight`. `-StrictWriters` turns that warning into a non-zero exit.
8. **Clean-run requirement.** A believable number requires: no writers active for ≥ 5 minutes (rule 7 prints `[ok] no source writes in the last 5 min`), the gate run to completion, and the printed table archived. Mid-flight snapshots in this project have already produced `1831/558` → `11832/0` for the same test within 20 minutes; do not trust a number taken under `[warn]` without re-measuring.

### `--quit-after` backstop

Every run gets `--quit-after <frames>` plus a wall-clock kill at `budget + 15s`.

* Measured idle throughput of the `--headless` main loop on this machine: **≈120 frames/s** (`rogue_build_rules`, cap 600 → 5.58 s; cap 20000 → 156.19 s). Windowed tests are vsync-bound at ≈60 frames/s.
* Frame cap = `TimeoutSec × fps × 2.0`, i.e. deliberately **twice** the wall budget so it can never truncate a test that already fits its budget, while an endless idle loop still ends in a finite, inspectable exit instead of an indefinite wait.
* `TimeoutSec` defaults: 120 s in the gate, 60 s in `run_all_tests.ps1` (unchanged for the full suite).

---

## 3. Baseline (measured, not copied)

Measured by `& .\tools\run_rogue_gate.ps1 -Register` at 2026-10-05 20:12:16 with `HEAD b034286`. Every number below was **independently reproduced** by the judge run at 20:14:06.

| Test | checks | failures | judged as |
|---|---|---|---|
| `rogue_graph` | 83608 | 0 | PASS |
| `rogue_variants` | 495 | 0 | PASS |
| `rogue_curses` | 218 | 0 | PASS |
| `rogue_events` | 484 | 0 | PASS |
| `rogue_wiring` | 123 | 0 | PASS |
| `rogue_growth` | 6886 | 0 | PASS |
| `rogue_rooms` | 1299 | 0 | PASS |
| `rogue_daily` | 132 | 0 | PASS |
| `rogue_profile_migration` | 113 | 0 | PASS |
| `rogue_build_growth` | 4066 | 0 | PASS |
| `rogue_build_system` | 440 | 0 | PASS |
| `roguelike_seven_rooms` | 11832 | 0 | PASS |
| `rogue_build_progression` | 818 | 0 | PASS |
| `systems` | 10812 | 0 | PASS |
| `expedition` | 79 | 0 | PASS |
| `combat` | 78 | 0 | PASS |
| `enemy_body` | 379 | 0 | PASS |
| `boss_tactics` | 186 | **1** | PASS at ≤1 (known pre-existing red) |
| `roguelike_routes` | 5220 | **2** | PASS at ≤2 (known red, under review) |
| `rogue_boss_phase2` | 406 | 0 | PASS |
| `rogue_ui` | 160 | 0 | PASS |
| `rogue_ui_visual` (windowed, `-IncludeVisual`) | 13 | 0 | PASS |

Result: **21 PASS / 0 judged-FAIL / 4 EXEMPT**, exit 0.

Note on the two known-reds: they are **baselined, not exempt**. They are blocked from getting worse; somebody still has to explain or fix `boss_tactics`'s `Real projectile collision uses frontal guard once` and `roguelike_routes`'s two "walk continuously along each branch" assertions.

**Consistency with the pre-existing baseline table:** all 19 rows already quoted by the dispatcher matched to the digit; the additions are `rogue_boss_phase2` (406/0), `rogue_ui` (160/0) and the windowed `rogue_ui_visual` (13/0), which did not exist when that table was written.

---

## 4. Exemptions (measured, with evidence)

| Test | Observed | Why it is exempt, not "to be fixed green" |
|---|---|---|
| `rogue_build_rules` | `NO-SUMMARY`, 2 error lines, exits **only** via the frame cap (cap 1200 → 10.2 s) | It dies on its **first** check (`Painted icon exists: W001` → `Invalid access to property 'atlas'` on a `Nil`) and never reaches `quit()`; the remaining 126+ assertions never execute. Effective coverage is **0**, so it cannot serve as a regression signal. |
| `rogue_build_pack` | `NO-SUMMARY`, 1–2 error lines, exits via the frame cap (cap 600 → 9.9 s) | `Missing exported icon W001`: `assets/rogue/build/` is git-ignored and only holds 7-byte `{}` placeholder manifests, so `Art.icon(...)` returns `null` for everything. |
| `roguelike_network` | `NO-SUMMARY`, 0 error lines alone (cap 600 → 5.5 s) | Needs the multi-process harness (`-- --server --four`). A single-process run has no summary line at all; this is harness noise, not a regression. |
| `rogue_build_network` | same as above | same |

Both network cases are "no summary line when run alone" — which under rule 3 would otherwise be a hard FAIL, hence the explicit exemption rather than a weakened rule.

---

## 5. Observation from this round (for the dispatcher)
Source writes were observed **during** the measurement window, i.e. the numbers above were taken while the tree was not fully quiescent:

```
20:10:12  scripts\combat_visuals.gd
20:11:23  tests\roguelike_bosses.gd
20:13:07  tests\rogue_boss_phase2.gd
```

All 21 judged rows still matched their expected values, so the numbers are consistent — but per rule 8 they should be re-measured once every writer has stopped (and the gate should then print `[ok] no source writes in the last 5 min`). `combat_visuals.gd` being written at 20:10 is worth the dispatcher's attention: the rendering round was supposed to be finished, so something else is editing that file.

---

## 6. Class-cache rebuild (done last, as instructed)

Run at **20:16:20**, took 13 s, exit 0:

```
[setup] Stale Godot class cache: 3 class(es) missing -> RogueDaily, RogueGrowth, RogueRooms
[setup] Rebuilding the cache: Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
[setup] Rebuild finished (exit 0).
[setup] Class cache rebuilt successfully.
```

Verified in `.godot/global_script_class_cache.cfg` afterwards — all seven new classes registered:
`RogueGraph=True RogueVariants=True RogueCurses=True RogueEvents=True RogueDaily=True RogueGrowth=True RogueRooms=True`.

Concurrency note: the rebuild happened while other rounds were still running. Godot's `--import` is a *build-cache* refresh, not a business-code change, but it does rewrite `.godot/` and re-import `*.import` files (it re-uploaded 28 assets, including every `build/*.png` screenshot). Do not mistake those `*.import` diffs for feature work when reading `git status`.

**Post-cache re-run, 20:16:38** (`build/gate-20261005-201638/`): identical result — **21 PASS / 0 judged-FAIL / 4 EXEMPT**, every `checks`/`failures` pair unchanged, exit 0. So the cache rebuild broke nothing. At that moment the writer check still flagged one file (`tests/rogue_boss_phase2.gd`, 20:13:07), i.e. still not fully quiescent; the numbers nevertheless matched the earlier run exactly.

---

## 6b. Residual risk

* The frame cap is a *backstop*, not a scheduler: a GDScript infinite loop that never yields to the main loop will not be stopped by `--quit-after` (only the wall-clock kill catches it).
* `run_all_tests.ps1` still runs **all 183** tests, including ~15 windowed `*_visual` cases and `city` (which times out at 60 s); budget ~15 minutes and a real display for the full suite.
* The gate's default set is headless-only; `rogue_ui_visual` and the other windowed cases are opt-in (`-IncludeVisual`, or `-Only <name> -IncludeVisual`).
* `rogue_ui_visual` writes screenshots (`build/rogue-ui-*.png`) but asserts only 13 checks — it is a smoke/visual case, not proof of UI correctness.
