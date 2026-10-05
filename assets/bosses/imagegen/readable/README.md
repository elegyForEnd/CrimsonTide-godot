# Boss effects with readable sources

Ten new standalone ImageGen PNGs: grounded lightning, upward flame, a floor furnace vent, a physical bell clapper, a downward royal sword, a rock barricade, a gravestone, a standing mirror, a downward black sword and a tangible royal crown. Each keeps native proportions and alpha; each effect has one independent image. Exact prompts are in `generation-prompts.json`. Contact pivots are indexed from unchanged PNGs by `tools/index_boss_entity_contacts.py`.

- Thunder overload / wing stall ground contacts use a vertical grounded lightning sprite. Returning thunder projectiles use this sprite rotated to their actual projected velocity, with its contact tip placed at the live projectile.
- Ember pyres / furnace pressure vents emit fire upward from the ground. The chain drag follow-up retains its physical hammer, and the chain lane uses continuous rails rather than fire.
- Charge, entrance, phase, guard and death no longer place giant rotating attack images above the caster. Small electrical discharge, flame tongues, blade glints, optical fragments, rising cracks or dissipation follow their source.
- Ground materials no longer default to rotating radial petals / scars. Damage continues to use the exact shared CPU / GPU geometry. PNG entities above the ground are visual accents; the authoritative ground footprint determines damage.
- Boss particles are clipped to their actual hazard, including directional cones and lanes. Wing lightning uses electrical fragments and obsidian weapon contact uses sparks rather than feathers.
- Horizontal painted attack entities are GPU-clipped to the same warning and damage boundary; upright falling objects and ground structures use measured contact pivots. No texture is stretched to fit a hitbox.
- Choreographed zones carry explicit boss identity. Legacy network records resolve the existing identity flags; rogue releases use their authoritative active age.
- Summons and dash destinations resolve map obstacles before telegraphs appear; coincident follow-up attack origins and projectile path knots resolve to the same location. The knight's old attack cells with baked slash light are excluded.
- Furnace vents stay on the floor, smoke before activation, emit embers when a linked pressure attack fires, and can be destroyed. The old cage-shaped kiln image is no longer used.

Validation: readability / contact / obstacle assertions; 246 staging assertions; 1,177 choreography assertions covering 73 moves / 17 identities; 376 particle assertions; 58,162 GPU geometry and painted clipping assertions with zero mismatches. Visual audit: 12 extraction identities, 48 moves, warning / first impact / final impact (144 captures), plus all 25 rogue guardian moves. Host/client boss presentation also passes. Fixtures were updated for the current room selection API.
