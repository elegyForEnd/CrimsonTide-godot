# Character idle animation, 2026-10-05

Generated with the built-in ImageGen tool. Original transparent PNGs are preserved unchanged. Exact prompts are in `generation-prompts.json`.

- Four hero sheets: four weapon families × four authored poses = 64 frames.
- Empty-hand grip sheet: four heroes × four poses = 16 frames, used with the existing 48 individual run-weapon icons.
- Rifle sheet: four heroes × four poses = 16 frames.
- Muyu soul scythe sheet: four poses.

These are 100 new character animation frames. They are character sheets, not effect atlases. Campaign weapons share their appropriate family art; each of the 21 campaign/issue weapons and 48 run weapons has separate idle handling. This does not replace each campaign weapon with its own new painted weapon model.

`tools/index_character_idle.py` reads alpha to record source regions and support-foot pivots in `manifest.json`; it writes JSON only. Small pieces from adjacent cells are excluded from runtime mesh geometry. One uniform scale per hero/clip preserves the established walking body height. Mesh joint motion adds restrained breathing, grip movement and cloth lag while keeping boots stationary. Six-step ping-pong playback uses all four painted poses.

Both battle presentations and the camp play these clips. Movement, dodge, attacks, casting, airborne and landing states override idle. Stop and weapon change start a 0.28-second gentle entry. Run-weapon textures attach at the idle grip; the empty-hand body avoids duplicated weapons.

Validation: character idle 75,909 checks, character scale 295 checks, ranged regression 272 checks, camp rules 83 checks; all passed. Real renderer screenshots cover the four heroes, both facings, camp and a live equipped run weapon. Screenshots are under `build/character-idle-*.png`.
