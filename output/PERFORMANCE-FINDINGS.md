# Campaign combat performance investigation

Tested on 2026-10-05 with Godot 4.7.2, OpenGL Compatibility, NVIDIA RTX 3080 Ti,
1280 x 800, VSync disabled. Tests use the actual campaign map, Battlefield,
TideSession.simulate(), CombatVisuals, BossVFX and BossDamageVisual. No network
or full main-screen/audio stack. Each fresh-process ablation runs nine seconds;
the first 1.5 seconds are excluded. Frame times are wall-clock intervals between
process callbacks. P95 means 95% of measured intervals are no slower than this.

## Confirmed crowded-combat bottleneck

Forty moon-monolith-colossus enemies are deliberately placed close together and
allowed to attack. This is a stress test, not a normal habitat population.

| Same combat workload | Median frame ms | P95 frame ms | End-of-run draw calls |
| --- | ---: | ---: | ---: |
| All effects | 20.125 | 71.059 | 6130 |
| Hide custom combat particles, retain their update and all combat logic | 10.621 | 14.984 | 665 |
| Hide and skip CombatVisuals update, retain combat logic and boss rendering | 5.379 | 8.255 | 664 |

The custom combat particle engine reached its 1400-particle cap. Hiding its
drawing materially reduced frame time. Disabling the wider combat VFX update
reduced it further. Therefore decorative particle rendering and its CPU update
are confirmed contributors for this workload; actor size alone is insufficient.

Source locations:

- scripts/combat_visuals.gd, observe_particles(): automatically creates gathering
  emitters and impact bursts for ordinary monsters. Every eligible projectile
  also emits a decorative particle every 0.035 seconds, without a shared trail
  emission quota. Monsters need not have a separately authored particle scene.
- scripts/combat_particles.gd, draw_particles(): individual transform and
  primitive submissions per particle, with a second additive glow drawing pass.
- scripts/combat_particles.gd, move()/stop(): repeatedly scans all particles for
  each emitter, including idle-enemy stop calls.

A diagnostic cap applied *after* updating particles lowered draw calls to 2265
but did not improve median frame time (25.076 ms, P95 29.556 ms). This is not a
validated production solution. Prioritize emission-time trail budgets, batching
and reducing repeated source scans; measure again before changing global caps.

## Boss observations

Single real boss sequences were also exercised, with full visual effects:

| Boss | Median frame ms | P95 frame ms | Max damage-visual update ms |
| --- | ---: | ---: | ---: |
| Bell | 2.394 | 3.763 | 19.295 |
| Queen | 2.672 | 3.920 | 25.209 |
| Storm | 2.756 | 3.457 | 1.032 |
| Dragon | 2.981 | 3.821 | 18.605 |

The large transient CPU spikes were recorded inside BossDamageVisual._process().
That path lazily loads effect artwork and creates the effect nodes/materials.
Preloading/warming actual upcoming effects is a candidate fix, but the nested
load and node-creation costs were not individually profiled. Repeated per-frame
Geometry.shader_data(h) calls at line 78 are an additional proven redundancy.

The user's exact symptom of one unspecified large enemy causing severe sustained
slowdown has not been reproduced. This investigation confirms a dense-combat
VFX bottleneck and boss-update spikes, not that every reported slowdown shares
that cause. Hidden-window microbenchmarks should not be read as full-game FPS.

## Reproduce

Run one case per process to avoid residual high-water resource allocations:

```powershell
& .\Godot_v4.7.2-stable_win64_console.exe --path . --script res://output/performance_effects_probe.gd --disable-vsync -- 40_large_fighting capture
& .\Godot_v4.7.2-stable_win64_console.exe --path . --script res://output/performance_effects_probe.gd --disable-vsync -- 40_large_no_particle_draw capture
& .\Godot_v4.7.2-stable_win64_console.exe --path . --script res://output/performance_effects_probe.gd --disable-vsync -- 40_large_no_combat_vfx capture
```

JSON logs and screenshots are saved alongside this report. The investigation
above preceded the implementation described below.

Correction: the original performance_campaign_probe results preceding this run
used the first spawned enemy as a template. Campaign initialization spawns map
guardians before ordinary enemies, so that template retained boss flags. Those
ordinary-vs-large comparisons are invalid. Both probe scripts now explicitly
select an ordinary-enemy template; the figures above use the corrected script.

## Implemented optimization (preserving the authored presentation)

- Particle count, emission intervals, random draws, motion, lifetime, size,
  color, fade, antialiasing and damage-safe masks remain unchanged.
- Adjacent polygon/line primitives are submitted as ordered triangle batches.
  The thin-line antialias geometry matches Godot 4.7's compensated widths.
  Rare polyline and dust styles retain their native drawing, with explicit batch
  flushes to preserve compositing order.
- The additive glow uses one instanced mesh with the same two 64-segment circles
  per particle, including inherited tint and opacity. No particles are removed.
- Body and glow share their per-frame color/pose calculations. Source-indexed
  particles replace full-array searches for gathering movement, cancellation
  and mask updates.
- Boss geometry uniforms are computed once instead of eight times per region.
- The effect-art cache loads the current map's bosses and upcoming raid boss
  artwork in background threads; the original effect timing is retained even
  if a requested texture is needed before its background load completes.

Fresh-process validation on the same machine and stress workload:

| Measurement | Reference | Final implementation |
| --- | ---: | ---: |
| 40 large attackers: median frame ms | 19.929 | 19.282 |
| 40 large attackers: P95 frame ms | 69.400 | 23.590 |
| 40 large attackers: max frame ms | 73.700 | 25.796 |
| 40 large attackers: end-of-run draw calls | 6182 | 667 |
| Particle cap reached | 1400 | 1400 |
| Queen: max damage-visual update ms | 28.182 | 1.295 |
| Queen: max frame ms | 31.747 | 7.174 |

The main benefit is fewer long frames (about 66% lower P95 in the crowd test),
not a large increase in median FPS. The artificial 40-elite crowd still exceeds
the 16.7 ms frame budget; this is not a guarantee of 60 FPS on every machine.

Validation passed:

- combat_particles.gd: 376 checks.
- boss_effect_staging.gd: 247 checks.
- boss_vfx.gd: 425 checks.
- boss_damage_geometry.gd: 38942 checks, zero GPU/damage-boundary mismatches.
- particle_render_equivalence.gd: 15 exact simulation-state comparisons across
  all 11 styles, normal/projected/mirrored transforms, inherited tint, gathering
  movement, cancellation and fade. Render comparisons have at most 14 of
  700000 pixels differing by more than 2/255; mean channel error is below
  0.0001/255 (sparse subpixel edge rasterization differences).

The frozen original particle implementation is in
output/performance-reference/combat_particles.gd. For a reference-rendering
benchmark, append `reference` after the case name. Reproduce visual regression:

```powershell
& .\Godot_v4.7.2-stable_win64_console.exe --path . --script tests/particle_render_equivalence.gd
python tools/check_particle_equivalence.py
```

Final benchmark logs: final-40_large_fighting-reference.log,
release-40_large_fighting.log, final-queen_full-reference.log and
release-queen_full.log. All final runtime error logs are empty.
