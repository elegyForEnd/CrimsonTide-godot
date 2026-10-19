class_name LeyMap
extends RefCounted
## Abstract skeleton for one generated continent. It carries intents and
## budgets only; every per-cell field lives in TerrainMap.
##
## Determinism contract: this object is built by MapGen.p0_contract() from the
## requested seed and options. It never reads time, viewport, player settings or
## global RNG. Each downstream pass owns its own derived RandomNumberGenerator.

var seed_value: int = 0
var layout_version: int = 1
var extent := Vector2(9600, 7200)
var area_scale: float = 1.0
var linear_scale: float = 1.0

# --- land intent -------------------------------------------------------------
var land_center := Vector2.ZERO
var land_radius := Vector2.ZERO
var land_noise_seed: int = 0
var coast_seed: int = 0

# --- fold intent -------------------------------------------------------------
var fold_axis := Vector2.RIGHT
var fold_wavelength: float = 1200.0
var fold_secondary: float = 0.3
var ridge_bias: float = 0.35

# --- water intent ------------------------------------------------------------
var water_fraction: float = 0.08
var water_budget: float = 0.0
var river_count: int = 2
var stream_count: int = 3
var lake_count: int = 3
var ferry_docks: int = 3

# --- danger intent -----------------------------------------------------------
var danger_core_count: int = 16
var safe_pocket_count: int = 1
var exposed_core_count: int = 2

# --- regions -----------------------------------------------------------------
var region_count: int = 48
var big_region_count: int = 39
var fragment_count: int = 9
var depth_target := PackedFloat32Array([0.55, 0.28, 0.13, 0.04])

# --- type quotas -------------------------------------------------------------
var newbie_count: int = 1
var high_count: int = 2
var fight_count: int = 4
var trap_count: int = 4

# --- special structures ------------------------------------------------------
var exit_count: int = 5
var sealed_exit_count: int = 2
var shrine_count: int = 3
var guardian_count: int = 3
var boss_candidate_count: int = 3
var royal_city_count: int = 1
var site_budget: int = 26
var chest_budget: int = 10

var pass_salts: Dictionary = {}
var options: Dictionary = {}
