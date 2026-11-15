extends Node2D

# Chunked exoplanet survey prototype.
#
# The world is infinite and generated deterministically per 16x16 chunk.
# Only a 20x16 tile window around the lander is rendered into a small
# SubViewport, so the texture and UI stay within a mobile-friendly budget.
# Chunks outside a 5x5 neighbourhood are dropped from memory.

const TILE := 64
const CHUNK := 16
const VIEW_TILES := 10.0

@export_group("Render Window")
## Tiles rendered around the player. Larger = more survey visible, more
## SubViewport work; defaults are tuned for mobile/WebGL.
@export_range(8, 48, 1) var view_w: int = 32
@export_range(8, 64, 1) var view_h: int = 32


func _view_px() -> Vector2:
	return Vector2(float(view_w * TILE), float(view_h * TILE))
const TURNS_START := 36
const OBJECTIVE_COUNT := 4
const HULL_START := 3

const WaterShaper := preload("res://scripts/water_shaper.gd")

const DIRS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
]
const DIR_NAMES: Array[String] = ["east", "west", "south", "north"]

const EDGE_DIRS: Array[Vector2i] = [
	Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)
]
const EDGE_NAMES: Array[String] = ["north", "east", "south", "west"]
const CORNER_DIRS: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(1, -1), Vector2i(1, 1), Vector2i(-1, 1)
]
const CORNER_NAMES: Array[String] = ["nw", "ne", "se", "sw"]

# Every impassable surface material. This must include the depth-band tiles
# that `_render_terrain_world()` swaps in for a water cell: the raw field stores
# `temperate/water_lake`, but the renderer draws `water_lake_shallow` /
# `water_lake_deep`, and ocean similarly draws `water_shelf`. Testing the
# rendered tile against a list that only names the raw key made shallow/deep
# water walkable. `_is_walkable_world()` therefore tests `_raw_terrain_world()`,
# where these band names never appear; they are still listed here because the
# prop filter and the water-priority pass operate on rendered/material keys.
var BLOCKED: Array[String] = [
	"temperate/water_lake",
	"temperate/water_lake_shallow",
	"temperate/water_lake_deep",
	"volcanic/lava",
	"volcanic/lava_core",
	"methane/pool",
	"sulfur/acid_pool",
	"ammonia/blue_pool",
	"ocean/water_shallow",
	"ocean/water_shelf",
	"ocean/water_deep",
]

var BIOMES: Array = [
	{
		"id": "temperate", "name": "Temperate", "profile": "temperate", "generator": "continents",
		"life": "rare biosphere", "shore_ring": false,
		"tint": "#ffffff", "tint_strength": 0.0, "exposure": 1.32,
		"base": "temperate/grass",
		"base_variants": [
			"temperate/grass", "temperate/grass_v14", "temperate/grass_v15",
			"temperate/grass_v16", "temperate/grass_v17", "temperate/grass_v18",
		],
		"detail": "temperate/dirt",
		"detail_alt": "temperate/moss", "detail_alt2": "temperate/mud",
		"rock": "temperate/rock", "shore": "temperate/beach",
		"water": "temperate/water_lake",
	},
	{
		"id": "arid", "name": "Arid", "profile": "arid", "life": "lifeless", "generator": "dunes",
		"tint": "#ffffff", "tint_strength": 0.0, "exposure": 1.1,
		"base": "arid/sand", "base_alt": "arid/dunes",
		"base_variants": [
			"arid/sand", "arid/sand", "arid/dunes", "arid/dunes_ripple",
			"arid/dune_crest", "arid/sand_plateau",
		],
		"detail": "arid/cracked_earth", "detail_alt": "arid/salt_flat",
		"detail_alt2": "arid/dry_river", "detail_alt3": "arid/cracked_earth",
		"rock": "arid/rock", "shore": "", "water": "",
	},
	{
		"id": "cryo", "name": "Cryo", "profile": "cryo", "life": "lifeless", "generator": "fractured",
		"cliffs": false, "occlusion": false, "tint": "#ffffff", "tint_strength": 0.0, "exposure": 0.6,
		"base": "cryo/ice_flat_a",
		"base_variants": [
			"cryo/ice_flat_a", "cryo/ice_flat_b", "cryo/ice_flat_c",
			"cryo/ice_sheet_a", "cryo/ice_sheet_b", "cryo/ice_sheet_c",
		],
		"detail": "cryo/ice_cloud_a",
		"detail_alt": "cryo/ice_cloud_b", "detail_alt2": "cryo/ice_cloud_c",
		"detail_alt3": "cryo/ice_cloud_a",
		"rock": "cryo/ice_flat_a", "rock_alt": "cryo/ice_flat_a", "shore": "", "water": "",
	},
	{
		"id": "volcanic", "name": "Volcanic", "profile": "volcanic", "generator": "caldera",
		"life": "lifeless", "tint": "#ffffff", "tint_strength": 0.0, "exposure": 1.68,
		"base": "volcanic/ash_rim",
		"base_variants": ["volcanic/ash_rim", "volcanic/ash", "volcanic/pumice", "volcanic/basalt_shelf", "volcanic/lava_crust"],
		"detail": "volcanic/ash_rim",
		"detail_alt": "volcanic/basalt_shelf", "detail_alt2": "volcanic/ash", "detail_alt3": "volcanic/pumice",
		"rock": "volcanic/basalt_shelf", "rock_alt": "volcanic/basalt_shelf",
		"shore": "", "water": "volcanic/lava_core",
	},
	{
		"id": "ocean", "name": "Ocean", "profile": "ocean", "life": "lifeless", "generator": "archipelago",
		"tint": "#ffffff", "tint_strength": 0.0, "exposure": 1.0, "shore_ring": false,
		"base": "ocean/water_shallow", "detail": "ocean/water_deep",
		"rock": "temperate/beach", "rock_alt": "temperate/beach",
		"shore": "ocean/beach", "water": "ocean/water_deep",
	},
	{
		"id": "barren", "name": "Barren", "profile": "barren", "life": "lifeless", "generator": "cratered",
		"tint": "#c9b6a0", "tint_strength": 0.20,
		"base": "barren/regolith",
		"base_variants": ["barren/regolith", "barren/dust", "barren/ejecta", "barren/crater_rim"],
		"detail": "barren/dust",
		"detail_alt": "barren/ejecta", "detail_alt2": "barren/crater_rim",
		"rock": "barren/rock", "shore": "", "water": "",
	},
	# Alien archetypes. They deliberately reuse existing material tiles with a
	# data-driven profile and colour grade, so dedicated tiles can be swapped in
	# later without changing the generator.
	{
		"id": "methane", "name": "Methane Lakes", "profile": "temperate", "generator": "continents",
		"life": "lifeless", "shore_ring": true, "water_level": -0.40,
		"tint": "#63d6c4", "tint_strength": 0.10, "exposure": 1.0,
		"base": "methane/flat",
		"base_variants": ["methane/flat", "methane/frost_crust", "methane/mud", "methane/seep"],
		"detail": "methane/seep", "detail_alt": "methane/frost_crust",
		"detail_alt2": "methane/mud",
		"rock": "methane/ice_shards", "shore": "methane/pool",
		"water": "ocean/water_deep",
	},
	{
		"id": "iron", "name": "Iron Desert", "profile": "arid", "generator": "dunes",
		"life": "lifeless", "tint": "#c98a62", "tint_strength": 0.12,
		"base": "iron/iron_crust",
		"base_variants": ["iron/iron_crust", "iron/red_soil", "iron/oxide_dune"],
		"detail": "iron/rust_plate", "detail_alt": "iron/metal_shard",
		"detail_alt2": "iron/scrap",
		"rock": "iron/metal_shard", "shore": "", "water": "",
	},
	{
		"id": "sulfur", "name": "Sulfur Plains", "profile": "volcanic", "generator": "caldera",
		"life": "lifeless", "tint": "#f0dc5a", "tint_strength": 0.10, "exposure": 1.75,
		"base": "sulfur/flat",
		"base_variants": ["sulfur/flat", "sulfur/powder", "sulfur/yellow_crust"],
		"detail": "sulfur/mineral_rim", "detail_alt": "sulfur/vent",
		"detail_alt2": "sulfur/powder",
		"rock": "sulfur/yellow_crust", "rock_alt": "sulfur/mineral_rim",
		"shore": "", "water": "sulfur/acid_pool",
	},
	{
		"id": "crystal", "name": "Crystal Field", "profile": "crystal", "generator": "faceted",
		"life": "lifeless", "tint": "#b08cff", "tint_strength": 0.28, "exposure": 0.62,
		"base": "crystal/glass_ground",
		"base_variants": ["crystal/glass_ground", "crystal/plate", "crystal/prism_plate"],
		"detail": "crystal/plate",
		"detail_alt": "crystal/prism_crack", "detail_alt2": "crystal/shard_field",
		"detail_alt3": "crystal/plate",
		"rock": "crystal/cluster", "rock_alt": "crystal/geode", "shore": "", "water": "",
	},
	{
		"id": "obsidian", "name": "Obsidian Glass", "profile": "volcanic", "generator": "fractured",
		"life": "lifeless", "tint": "#9b7bd6", "tint_strength": 0.12, "exposure": 1.82,
		"base": "obsidian/flat",
		"base_variants": ["obsidian/flat", "obsidian/glass_plate", "obsidian/black_glass", "obsidian/cracked_glass"],
		"detail": "obsidian/ember_speck", "detail_alt": "obsidian/sharp_shard",
		"detail_alt2": "obsidian/cracked_glass",
		"rock": "obsidian/sharp_shard", "shore": "", "water": "volcanic/lava",
	},
	{
		"id": "ammonia", "name": "Ammonia Ice", "profile": "cryo", "generator": "fractured",
		"life": "lifeless", "shore_ring": true, "water_level": -0.40,
		"tint": "#72c8e8", "tint_strength": 0.10, "exposure": 1.10,
		"base": "ammonia/slush",
		"base_variants": ["ammonia/slush", "ammonia/frost", "ammonia/vapor_crust", "ammonia/white_crust"],
		"detail": "ammonia/frost", "detail_alt": "ammonia/vapor_crust",
		"detail_alt2": "ammonia/white_crust",
		"rock": "ammonia/frost", "shore": "ammonia/frost",
		"water": "ammonia/blue_pool",
	},
	{
		"id": "carbon", "name": "Carbon World", "profile": "temperate", "generator": "continents",
		"life": "lifeless", "shore_ring": true,
		"tint": "#9aa2b2", "tint_strength": 0.12, "exposure": 1.05,
		"base": "carbon/dark_soil",
		"base_variants": ["carbon/dark_soil", "carbon/coal", "carbon/graphite_dust", "carbon/grit", "carbon/tar"],
		"detail": "carbon/diamond_crust", "detail_alt": "carbon/coal",
		"detail_alt2": "carbon/graphite_dust",
		"rock": "carbon/coal", "shore": "carbon/grit",
		"water": "ocean/water_deep",
	},
]

# One low-frequency personality per seed. The seed still owns every detail,
# but this bias decides whether the run opens on an ocean, a mountain wall, a
# canyon field, or a plain. It is applied in world space, so it holds across
# chunk borders and survives the infinite scroll.
const TERRAIN_ARCHETYPES: Array = [
	{"name": "Open Plains", "elev": 0.02, "water": 0.06, "ridge": 0.035, "detail": -0.02, "ridge_chance": -0.56},
	{"name": "Mountainous", "elev": 0.14, "water": -0.03, "ridge": 0.300, "detail": -0.03, "ridge_chance": 0.26},
	{"name": "Broken Highlands", "elev": 0.08, "water": -0.01, "ridge": 0.220, "detail": 0.03, "ridge_chance": 0.10},
	{"name": "Lake District", "elev": -0.12, "water": -0.22, "ridge": 0.050, "detail": 0.00, "ridge_chance": -0.44},
	{"name": "Archipelago", "elev": -0.20, "water": -0.32, "ridge": 0.050, "detail": -0.02, "ridge_chance": -0.48},
	{"name": "Canyonlands", "elev": 0.06, "water": 0.03, "ridge": 0.300, "detail": 0.06, "ridge_chance": 0.10},
	{"name": "Cratered", "elev": 0.02, "water": -0.02, "ridge": 0.100, "detail": 0.09, "ridge_chance": -0.20},
	{"name": "Fractured", "elev": 0.04, "water": 0.01, "ridge": 0.340, "detail": 0.10, "ridge_chance": 0.14},
]

var STRUCTURES: Dictionary = {
	"mountain_range": {
		"path": "res://assets/tilesets/structures/mountain_range.png",
		"w": 2, "h": 2, "occludes": true, "sprite_scale": 1.75,
	},
	# Native 3×2 ridge strip: three adjacent copies form a continuous 9×2
	# mountain wall instead of a row of separate 2×2 hill stamps.
	"ridge_wide": {
		"path": "res://assets/tilesets/structures/ridge_wide.png",
		"w": 3, "h": 2, "occludes": true, "sprite_scale": 1.0,
	},
	"ridge_mid": {
		"path": "res://assets/tilesets/structures/ridge/ridge_mid_temperate.png",
		"path_by_biome": {
			"temperate": "res://assets/tilesets/structures/ridge/ridge_mid_temperate.png",
			"arid": "res://assets/tilesets/structures/ridge/ridge_mid_arid.png",
			"cryo": "res://assets/tilesets/structures/ridge/ridge_mid_cryo.png",
			"volcanic": "res://assets/tilesets/structures/ridge/ridge_mid_volcanic.png",
			"barren": "res://assets/tilesets/structures/ridge/ridge_mid_barren.png",
		},
		"w": 3, "h": 2, "occludes": true, "sprite_scale": 1.0,
	},
	"ridge_cap_l": {
		"path": "res://assets/tilesets/structures/ridge/ridge_cap_l_temperate.png",
		"path_by_biome": {
			"temperate": "res://assets/tilesets/structures/ridge/ridge_cap_l_temperate.png",
			"arid": "res://assets/tilesets/structures/ridge/ridge_cap_l_arid.png",
			"cryo": "res://assets/tilesets/structures/ridge/ridge_cap_l_cryo.png",
			"volcanic": "res://assets/tilesets/structures/ridge/ridge_cap_l_volcanic.png",
			"barren": "res://assets/tilesets/structures/ridge/ridge_cap_l_barren.png",
		},
		"w": 3, "h": 2, "occludes": true, "sprite_scale": 1.0,
	},
	"ridge_cap_r": {
		"path": "res://assets/tilesets/structures/ridge/ridge_cap_r_temperate.png",
		"path_by_biome": {
			"temperate": "res://assets/tilesets/structures/ridge/ridge_cap_r_temperate.png",
			"arid": "res://assets/tilesets/structures/ridge/ridge_cap_r_arid.png",
			"cryo": "res://assets/tilesets/structures/ridge/ridge_cap_r_cryo.png",
			"volcanic": "res://assets/tilesets/structures/ridge/ridge_cap_r_volcanic.png",
			"barren": "res://assets/tilesets/structures/ridge/ridge_cap_r_barren.png",
		},
		"w": 3, "h": 2, "occludes": true, "sprite_scale": 1.0,
	},
	"mountain_massif": {
		"path": "res://assets/tilesets/structures/mountain_massif.png",
		"w": 4, "h": 4, "occludes": true, "sprite_scale": 1.0,
		"pieces": "massif_4x4",
	},
	"volcano": {
		"path": "res://assets/tilesets/structures/volcano.png",
		"w": 4, "h": 4, "occludes": true, "sprite_scale": 1.0,
		"pieces": "volcano_4x4",
	},
	"impact_crater": {
		"path": "res://assets/tilesets/structures/impact_crater.png",
		"w": 3, "h": 3,
		"ground": true,
	},
	"mesa": {
		"path": "res://assets/tilesets/structures/mesa.png",
		"w": 2, "h": 2, "occludes": true, "sprite_scale": 1.40,
	},
	"mesa_b": {
		"path": "res://assets/tilesets/structures/mesa_b.png",
		"w": 2, "h": 2, "occludes": true, "sprite_scale": 1.34,
	},
	"iceberg": {
		"path": "res://assets/tilesets/structures/iceberg.png",
		"w": 2, "h": 2, "occludes": true, "sprite_scale": 1.30,
	},
	"geyser": {
		"path": "res://assets/tilesets/structures/geyser.png",
		"w": 2, "h": 2, "sprite_scale": 1.15,
	},
	"coral_spire": {
		"path": "res://assets/tilesets/structures/coral_spire.png",
		"w": 2, "h": 2, "occludes": true, "sprite_scale": 1.20,
	},
	"crystal_outcrop": {
		"path": "res://assets/tilesets/structures/crystal_outcrop.png",
		"w": 1, "h": 1, "occludes": true,
	},

	"islet": {
		"path": "res://assets/tilesets/structures/islet.png",
		"w": 2, "h": 2,
	},
	# Large abandoned survey architecture. These were already on disk but
	# unused; outpost complexes now place them as a deliberate cluster.
	"habitat_dome": {
		"path": "res://assets/tilesets/structures/habitat_dome.png",
		"w": 2, "h": 2, "sprite_scale": 1.10,
	},
	"solar_farm": {
		"path": "res://assets/tilesets/structures/solar_farm.png",
		"w": 2, "h": 2,
	},
	"comms_dish": {
		"path": "res://assets/tilesets/structures/comms_dish.png",
		"w": 2, "h": 2,
	},
}

# Per-biome prop density. Default 6% reads as "inhabited"; sparse worlds use
# less so a single coral shard or shrub stays a landmark, not a lawn.
const WATER_BANDS: Dictionary = {
	"ocean": ["ocean/water_shallow", "ocean/water_shelf", "ocean/water_deep"],
}

const PROP_DENSITY: Dictionary = {
	"temperate": 0.045,
	"ocean": 0.015,
	"cryo": 0.032,
	# Crystal already carries outcrops and prism ground clutter; the generic
	# ice_chunk prop pushed the board into speckle.
	"crystal": 0.024,
}

# Small non-blocking set dressing. These sit on top of the terrain but never
# affect movement, so they add life without turning the board into clutter.
const PROPS: Dictionary = {
	"temperate": ["boulder", "shrub", "accent_temperate_tuft", "accent_temperate_crack", "accent_temperate_bones"],
	"arid": ["dead_bush", "accent_arid_crack", "accent_arid_bones", "accent_arid_tuft"],
	"cryo": ["ice_chunk", "accent_cryo_crack", "accent_cryo_crack", "accent_cryo_ice_teeth"],
	"volcanic": ["lava_rock", "sulfur_nodule", "accent_volcanic_vent", "accent_volcanic_crack"],
	"ocean": ["coral_shard"],
	"barren": ["barren_rock", "accent_barren_bones", "accent_barren_crack"],
	"methane": ["ice_chunk", "barren_rock"],
	"iron": ["dead_bush", "barren_rock", "obsidian_shard"],
	"sulfur": ["lava_rock", "sulfur_nodule"],
	"crystal": ["ice_chunk"],
	"obsidian": ["lava_rock", "obsidian_shard"],
	"ammonia": ["ice_chunk"],
	"carbon": ["barren_rock"],
}

var TRANSITION_PAIRS: Array = [
	["volcanic/lava", "volcanic/ash"],
	["volcanic/lava", "volcanic/basalt"],
	["volcanic/basalt", "volcanic/ash"],
	["temperate/grass", "temperate/dirt"],
	["temperate/grass", "temperate/rock"],
	["temperate/grass", "temperate/beach"],
	["temperate/grass", "temperate/water_lake"],
	["temperate/beach", "temperate/water_lake"],
	["arid/sand", "arid/cracked_earth"],
	["arid/sand", "arid/rock"],
	["arid/cracked_earth", "arid/rock"],
	["cryo/snow", "cryo/ice"],
	["cryo/snow", "cryo/rock"],
	["ocean/water_shallow", "ocean/water_deep"],
	["ocean/water_shallow", "ocean/reef"],
	["ocean/reef", "ocean/beach"],
]

var tile_set: TileSet
var source_ids: Dictionary = {}
var source_alts: Dictionary = {}
var transition_pairs: Dictionary = {}

# Water-body shaping (agent b). Off only for A/B evidence runs
# (`--legacy-water`); the shipped generator always runs it.
var water_shaping: bool = true
var water_shape_keys: Dictionary = {}
var water_shape_pad: int = 2

var chunks: Dictionary = {}
# Persistent survey snapshots. Loaded chunks unload around the player, but the
# minimap should keep showing every chunk the run has already revealed.
var mapped_chunks: Dictionary = {}
var mapped_lo := Vector2i.ZERO
var mapped_hi := Vector2i.ZERO
var has_mapped_bounds := false
var elevation := FastNoiseLite.new()
var detail := FastNoiseLite.new()
var structure_variants: Dictionary = {}
var variant_noise := FastNoiseLite.new()
var warp_noise := FastNoiseLite.new()
var shore_noise := FastNoiseLite.new()
var rough_noise := FastNoiseLite.new()
var ridge_noise := FastNoiseLite.new()

# Roguelike-safe feature flags: new mechanics and art passes should be
# switchable without deleting code. F4-F7 toggle these live in the viewer.
var feature_toggles: Dictionary = {
	"mountains": true,
	# Quarantined: habitat/solar/comms modules are human industrial
	# architecture and break the exoplanet-survey fiction. F5 still previews
	# them for art review, but they never spawn in a normal run.
	"outposts": false,
	"occlusion": true,
	"props": true,
}

var rng := RandomNumberGenerator.new()
var ui_rng := RandomNumberGenerator.new()

@export_group("Map / Seed")
## Turn this off to keep the inspector seed instead of rolling a new run.
@export var randomize_seed: bool = true
@export var seed_value: int = 4217
@export_range(0, 12, 1) var biome_index: int = 0

@export_group("Camera / View")
@export_enum("Dimetric", "Isometric", "Top") var view_mode: int = 1
@export var show_grid: bool = false
@export var circle_view: bool = true
@export_range(0.4, 1.6, 0.01) var zoom: float = 0.88
@export_range(0.4, 1.0, 0.01) var tilt: float = 0.75
var map_scale: float = 0.92
@export_range(0.20, 0.55, 0.01) var circle_radius: float = 0.40
@export_range(0.05, 0.15, 0.005) var circle_soft: float = 0.045
@export_range(0.45, 0.75, 0.01) var circle_outer: float = 0.56

@export_group("Fog / Survey")
@export var fog_enabled: bool = true
@export_range(0, 6, 1) var fog_reveal_radius: int = 2
@export_range(0.0, 1.0, 0.01) var fog_alpha_inner: float = 0.80
@export_range(0.0, 1.0, 0.01) var fog_alpha_mid: float = 0.74
@export_range(0.0, 1.0, 0.01) var fog_alpha_outer: float = 0.62
@export_range(0.0, 1.0, 0.01) var fog_desat: float = 0.35

@export_group("Decals")
@export_range(0.0, 0.5, 0.01) var decal_density: float = 0.15
@export_range(0.0, 0.5, 0.01) var decal_cluster_threshold: float = -0.20
@export_range(0.2, 1.0, 0.01) var decal_scale_min: float = 0.48
@export_range(0.2, 1.2, 0.01) var decal_scale_max: float = 0.64
@export_range(0.0, 1.0, 0.01) var decal_alpha: float = 0.72

@export_group("Terrain Shader")
@export_enum("Accepted dither", "Smooth tint", "Off") var edge_mode: int = 1
@export var relief_enabled: bool = false

var planet_name: String = ""
var terrain_archetype: Dictionary = {}
var archetype_name: String = "Open Plains"
var view_origin := Vector2i.ZERO

var sub_viewport: SubViewport
var tilemap: TileMapLayer
var underlay: TileMapLayer
var rockmap: TileMapLayer
var cliff_layer: Node2D
var overlay_layer: Node2D
var structure_layer: Node2D
var actor_layer: Node2D
var occlusion_layer: Node2D
var occlusion_tex: Texture2D
var display: TextureRect
var shader_mat: ShaderMaterial
var space_layer: CanvasLayer
var space_rect: TextureRect
var space_mat: ShaderMaterial
var player_tex: Texture2D
var player_sprite: Sprite2D
var ambient_layer: Node2D
var ambient_texture: Texture2D
var anim_time := 0.0
var parallax_ridge: TextureRect
var player_shadow: Polygon2D
var player_tween: Tween
var camera_tween: Tween
var node_tex: Texture2D
var relay_tex: Texture2D
var piece_sets: Dictionary = {}
var _tex_bounds: Dictionary = {}
var _prop_ok: Dictionary = {}
var cli_seed: int = -1
var cli_biome: int = -1
var cli_view: int = -1
var cli_hide_ui: bool = false
var debug_visible: bool = false
var debug_transitions: bool = false
var debug_layer: Node2D
var terrain_mask_tex: ImageTexture
var terrain_mask_img: Image
var terrain_mask_size := Vector2i.ZERO
var height_mask_tex: ImageTexture
var height_mask_img: Image
var height_mask_size := Vector2i.ZERO
var terrain_color_cache: Dictionary = {}
var decal_noise := FastNoiseLite.new()
var decal_cache: Dictionary = {}
var decal_manifest: Dictionary = {}
var decal_layer: Node2D
var debug_elapsed: float = 0.0
var nav_label: Label
var debug_label: Label
var minimap: Control
var minimap_img: Image
var minimap_tex: ImageTexture

var player_cell := Vector2i.ZERO
var objectives: Array[Vector2i] = []
var data_caches: Array[Vector2i] = []
var cache_taken: Array[bool] = []
var collected: Array[bool] = []
var objective_tiers: Array[int] = []
var objective_values: Array[int] = []
var revealed: Dictionary = {}
var fog_layer: Node2D
var fog_mat: ShaderMaterial
var objective_mode := "survey"
var turns_left: int = TURNS_START
var hull: int = HULL_START
var data_collected: int = 0
var game_over: bool = false
var message_text: String = ""
var hazard_cell := Vector2i(-999, -999)
var hazard_kind: String = ""
var hazard_color := Color(1.0, 0.35, 0.2)

var info_label: Label
var status_label: Label
var hazard_label: Label
var view_label: Label
var ui_layer: CanvasLayer
var ui_root: Control
var message_label: Label
var capture_requested: bool = false
var capture_elapsed: float = 0.0
const CAPTURE_PATH := "user://map_capture.png"


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("#0f0e14"))
	ui_rng.randomize()
	_parse_cli()
	_register_outcrops()
	capture_requested = (
		"--capture" in OS.get_cmdline_args()
		or "--capture" in OS.get_cmdline_user_args()
	)
	_build_tileset()
	_build_view()
	_build_ui()
	if cli_hide_ui:
		ui_layer.visible = false
	if cli_seed >= 0:
		seed_value = cli_seed
		_generate()
	elif randomize_seed:
		_new_seed()
	else:
		_generate()


func _parse_cli() -> void:
	"""Small command-line surface for reproducible screenshots and debugging.

	Examples:
	  godot --path . -- --capture --seed=4217 --biome=temperate --view=iso
	  godot --path . -- --seed=4217 --grid --no-ui
	"""
	var args: Array = OS.get_cmdline_args() + OS.get_cmdline_user_args()
	for raw in args:
		var arg := str(raw)
		if arg.begins_with("--seed="):
			cli_seed = int(arg.substr(7))
		elif arg.begins_with("--biome="):
			var name := arg.substr(8).to_lower()
			for i in range(BIOMES.size()):
				if str(BIOMES[i]["id"]) == name:
					cli_biome = i
					break
			if cli_biome < 0:
				if name.is_valid_int():
					cli_biome = clampi(int(name), 0, BIOMES.size() - 1)
		elif arg.begins_with("--view="):
			match arg.substr(7).to_lower():
				"tilt", "3/4", "dimetric":
					cli_view = 0
				"iso", "isometric":
					cli_view = 1
				"top", "topdown", "flat":
					cli_view = 2
		elif arg == "--grid":
			show_grid = true
		elif arg == "--debug":
			debug_visible = true
		elif arg == "--no-ui":
			cli_hide_ui = true
		elif arg == "--debug-transitions":
			debug_transitions = true
		elif arg == "--smooth-edges":
			edge_mode = 2
		elif arg == "--no-soft-edges":
			edge_mode = 0
		elif arg == "--rect" or arg == "--no-circle":
			circle_view = false
		elif arg == "--relief":
			relief_enabled = true
		elif arg == "--legacy-water":
			# Agent b: leaves the 1-cell halo and the old 3x3-only smoothing,
			# i.e. the pre-coalescing shoreline, for side-by-side evidence.
			water_shaping = false
		elif arg.begins_with("--water="):
			# --water=<radius>,<passes>,<wet>,<dry> for same-seed A/B tuning.
			var parts := arg.substr(8).split(",")
			if parts.size() == 4:
				WaterShaper.configure(
					int(parts[0]), int(parts[1]), float(parts[2]), float(parts[3])
				)
	if cli_biome >= 0:
		biome_index = cli_biome
	if cli_view >= 0:
		view_mode = cli_view


func _process(delta: float) -> void:
	anim_time += delta
	if player_sprite != null:
		player_sprite.offset = Vector2(0.0, sin(anim_time * 2.2) * 1.25)
	if player_shadow != null:
		player_shadow.scale = Vector2(1.0, 1.0 + sin(anim_time * 2.2 + 1.0) * 0.035)
	if parallax_ridge != null:
		parallax_ridge.position.x = -24.0 + sin(anim_time * 0.09) * 8.0
	if capture_requested:
		capture_elapsed += delta
		if capture_elapsed >= 1.2:
			capture_requested = false
			_save_capture(CAPTURE_PATH)
	if debug_visible:
		debug_elapsed += delta
		if debug_elapsed >= 0.25:
			debug_elapsed = 0.0
			_refresh_debug()


func _dot_texture() -> Texture2D:
	if ambient_texture != null:
		return ambient_texture
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	ambient_texture = ImageTexture.create_from_image(img)
	return ambient_texture


func _ambient_texture(name: String) -> Texture2D:
	var path := "res://assets/vfx/%s.png" % name
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return _dot_texture()


func _ambient_profile() -> Dictionary:
	# One atmospheric signature per biome. These are deliberately cheap
	# (CPUParticles2D, < 45 particles) because the map is the frame budget.
	var id := str(BIOMES[biome_index].get("id", "temperate"))
	match id:
		"cryo", "ammonia":
			return {
				"tex": "particle_snow", "amount": 62, "life": 9.0,
				"dir": Vector2(0.15, 1.0), "spread": 28.0,
				"vel": Vector2(5.0, 15.0), "gravity": Vector2(6.0, 18.0),
				"scale": Vector2(0.45, 1.15), "color": Color(0.90, 0.98, 1.0, 0.70),
			}
		"volcanic", "sulfur", "obsidian":
			return {
				"tex": "particle_ember", "amount": 44, "life": 6.0,
				"dir": Vector2(0.12, -1.0), "spread": 26.0,
				"vel": Vector2(8.0, 26.0), "gravity": Vector2(0.0, -10.0),
				"scale": Vector2(0.55, 1.35), "color": Color(1.0, 0.64, 0.28, 0.75),
			}
		"ocean", "methane":
			return {
				"tex": "particle_dot", "amount": 26, "life": 13.0,
				"dir": Vector2(1.0, 0.05), "spread": 10.0,
				"vel": Vector2(4.0, 11.0), "gravity": Vector2.ZERO,
				"scale": Vector2(0.6, 1.8), "color": Color(0.55, 0.92, 0.92, 0.22),
			}
		"crystal":
			return {
				"tex": "particle_spark", "amount": 24, "life": 3.2,
				"dir": Vector2(0.0, -1.0), "spread": 180.0,
				"vel": Vector2(1.5, 6.0), "gravity": Vector2.ZERO,
				"scale": Vector2(0.18, 0.55), "color": Color(0.85, 0.72, 1.0, 0.7),
			}
		"arid", "iron", "barren", "carbon":
			return {
				"tex": "particle_dot", "amount": 48, "life": 12.0,
				"dir": Vector2(1.0, 0.12), "spread": 14.0,
				"vel": Vector2(7.0, 19.0), "gravity": Vector2.ZERO,
				"scale": Vector2(0.45, 1.2), "color": Color(0.88, 0.78, 0.60, 0.36),
			}
		_:
			return {
				"tex": "particle_spore", "amount": 34, "life": 13.0,
				"dir": Vector2(0.25, -0.7), "spread": 58.0,
				"vel": Vector2(2.5, 8.0), "gravity": Vector2(0.0, -2.0),
				"scale": Vector2(0.35, 1.0), "color": Color(0.72, 0.96, 0.78, 0.42),
			}


func _build_ambient() -> void:
	if ambient_layer == null:
		return
	for child in ambient_layer.get_children():
		child.free()
	var prof := _ambient_profile()
	var dust := CPUParticles2D.new()
	dust.amount = int(prof["amount"])
	dust.lifetime = float(prof["life"])
	dust.preprocess = minf(float(prof["life"]) * 0.8, 8.0)
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(340, 200)
	dust.position = Vector2(320, 180)
	dust.direction = prof["dir"]
	dust.spread = float(prof["spread"])
	dust.gravity = prof["gravity"]
	dust.initial_velocity_min = float(prof["vel"].x)
	dust.initial_velocity_max = float(prof["vel"].y)
	dust.scale_amount_min = float(prof["scale"].x)
	dust.scale_amount_max = float(prof["scale"].y)
	dust.color = prof["color"]
	dust.texture = _ambient_texture(str(prof["tex"]))
	dust.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Fade each mote in and out so the field has no popping edge.
	var ramp := Gradient.new()
	var c: Color = prof["color"]
	ramp.set_color(0, Color(c.r, c.g, c.b, 0.0))
	ramp.set_color(1, Color(c.r, c.g, c.b, 0.0))
	ramp.add_point(0.18, Color(c.r, c.g, c.b, c.a))
	ramp.add_point(0.72, Color(c.r, c.g, c.b, c.a))
	dust.color_ramp = ramp
	ambient_layer.add_child(dust)



func _move_puff(at: Vector2) -> void:
	if ambient_layer == null:
		return
	var puff := CPUParticles2D.new()
	puff.texture = _dot_texture()
	puff.amount = 8
	puff.lifetime = 0.5
	puff.one_shot = true
	puff.explosiveness = 1.0
	puff.direction = Vector2(0, -1)
	puff.spread = 75.0
	puff.gravity = Vector2(0, 26)
	puff.initial_velocity_min = 7.0
	puff.initial_velocity_max = 18.0
	puff.scale_amount_min = 0.3
	puff.scale_amount_max = 0.9
	puff.color = Color(0.78, 0.92, 0.86, 0.30)
	puff.position = at
	puff.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ambient_layer.add_child(puff)
	puff.emitting = true
	get_tree().create_timer(0.9).timeout.connect(puff.queue_free)


func _save_capture(path: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	if img == null:
		push_error("viewport capture returned no image")
		return
	var err := img.save_png(path)
	print("capture: ", ProjectSettings.globalize_path(path), " (err=", err, ")")


func _register_outcrops() -> void:
	# W6 art is one hero + two supporting silhouettes per biome key. Register
	# them as normal structure defs so culling, contact shadows and y-sorting
	# come from the same path as every other landmark.
	for biome in ["temperate", "arid", "cryo", "volcanic", "ocean", "barren"]:
		for kind in ["hero", "hero_b", "sup_a", "sup_b"]:
			var key := "%s_%s" % [biome, kind]
			if STRUCTURES.has(key):
				continue
			var hero: bool = str(kind).begins_with("hero")
			STRUCTURES[key] = {
				"path": "res://assets/tilesets/outcrops/%s.png" % key,
				"w": 2 if hero else 1,
				"h": 2 if hero else 1,
				"occludes": hero,
				"sprite_scale": 0.92 if hero else 1.0,
			}


func _build_tileset() -> void:
	tile_set = TileSet.new()
	tile_set.tile_size = Vector2i(TILE, TILE)
	source_ids.clear()
	source_alts.clear()
	transition_pairs.clear()

	for biome in BIOMES:
		for field in [
			"base", "base_alt", "detail", "detail_alt", "detail_alt2",
			"detail_alt3", "rock", "rock_alt", "shore", "water",
		]:
			var key := str(biome.get(field, ""))
			if key != "":
				_add_tile(key, "res://assets/tilesets/%s.png" % key)
		for variant_key in biome.get("base_variants", []):
			var vk := str(variant_key)
			if vk != "":
				_add_tile(vk, "res://assets/tilesets/%s.png" % vk)

	var pairs: Array = _load_transition_pairs()
	for pair in pairs:
		var a: String = pair[0]
		var other: String = pair[1]
		var a_name := a.get_file()
		var b_name := other.get_file()
		var dir := "res://assets/tilesets/transitions/%s_%s" % [a_name, b_name]
		var info := {"a": a, "b": other, "a_name": a_name, "b_name": b_name}
		transition_pairs[a + "|" + other] = info
		transition_pairs[other + "|" + a] = info
		for side in ["west", "east", "north", "south"]:
			var path := "%s/%s_%s.png" % [dir, a_name, side]
			_add_tile(a + "|" + other + "|" + side, path)
		for corner in CORNER_NAMES:
			for prefix in ["outer", "inner"]:
				var extra_path := "%s/%s_%s_%s.png" % [dir, a_name, prefix, corner]
				if ResourceLoader.exists(extra_path):
					_add_tile(
						a + "|" + other + "|" + prefix + "_" + corner,
						extra_path
					)
		for axis in ["ns", "ew"]:
			var stripe_path := "%s/%s_stripe_%s.png" % [dir, a_name, axis]
			if ResourceLoader.exists(stripe_path):
				_add_tile(a + "|" + other + "|stripe_" + axis, stripe_path)
			var reverse_stripe := "%s/%s_stripe_%s.png" % [dir, b_name, axis]
			if ResourceLoader.exists(reverse_stripe):
				_add_tile(other + "|" + a + "|stripe_" + axis, reverse_stripe)
		# Hand-authored 45-degree coast splits, keyed by which half-cell the
		# water occupies. These are only used when the cell owns the land side;
		# the water cell keeps its normal tile.
		var diag_a := a.replace("/", "_")
		var diag_b := other.replace("/", "_")
		for corner in CORNER_NAMES:
			var diag_path := "res://assets/tilesets/transitions/diagonal/%s_%s/%s.png" % [
				diag_a, diag_b, corner
			]
			if ResourceLoader.exists(diag_path):
				_add_tile("diag|" + a + "|" + other + "|" + corner, diag_path)
			# The art is authored land-first, so a pair listed water-first in
			# transitions.json (e.g. ocean/water_shallow + ocean/reef) still
			# needs the land-first lookup key that _diagonal_key() builds.
			var diag_rev := "res://assets/tilesets/transitions/diagonal/%s_%s/%s.png" % [
				diag_b, diag_a, corner
			]
			if ResourceLoader.exists(diag_rev):
				_add_tile("diag|" + other + "|" + a + "|" + corner, diag_rev)


func _load_transition_pairs() -> Array:
	var path := "res://tools/transitions.json"
	if FileAccess.file_exists(path):
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary and parsed.has("pairs"):
			return parsed["pairs"]
	return TRANSITION_PAIRS


func _add_tile(key: String, path: String) -> void:
	if not ResourceLoader.exists(path):
		push_warning("Missing tile: " + path)
		return
	var tex := load(path) as Texture2D
	if tex == null:
		push_warning("Failed to load tile: " + path)
		return
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(TILE, TILE)
	src.create_tile(Vector2i.ZERO)
	source_ids[key] = tile_set.add_source(src)
	# Flips are free, are seamless for a tileable texture, and break the
	# obvious 64px repeat without changing the art.
	var alts: Array = [0]
	for flip in range(1, 4):
		var alt_id := src.create_alternative_tile(Vector2i.ZERO)
		var td := src.get_tile_data(Vector2i.ZERO, alt_id)
		td.flip_h = (flip & 1) != 0
		td.flip_v = (flip & 2) != 0
		alts.append(alt_id)
	source_alts[key] = alts


func _build_view() -> void:
	_load_structure_variants()
	# Deep-space plate. Layer -10 keeps it behind the map, structures and HUD
	# even when the board uses a transparent SubViewport.
	space_layer = CanvasLayer.new()
	space_layer.layer = -10
	add_child(space_layer)
	space_rect = TextureRect.new()
	space_rect.texture = load("res://assets/backgrounds/space.png") as Texture2D
	space_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	space_rect.stretch_mode = TextureRect.STRETCH_SCALE
	space_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	space_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	space_rect.size = get_viewport_rect().size
	space_rect.modulate = Color(1, 1, 1, 0.78)
	var star_shader := load("res://shaders/star_drift.gdshader") as Shader
	if star_shader != null:
		space_mat = ShaderMaterial.new()
		space_mat.shader = star_shader
		space_rect.material = space_mat
	space_layer.add_child(space_rect)

	if ResourceLoader.exists("res://assets/tilesets/structures/pieces/parallax_ridge_a.png"):
		parallax_ridge = TextureRect.new()
		parallax_ridge.texture = load("res://assets/tilesets/structures/pieces/parallax_ridge_a.png")
		parallax_ridge.position = Vector2(-24, 230)
		parallax_ridge.size = Vector2(688, 120)
		parallax_ridge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		parallax_ridge.stretch_mode = TextureRect.STRETCH_SCALE
		parallax_ridge.modulate = Color(0.62, 0.74, 0.80, 0.28)
		parallax_ridge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		space_layer.add_child(parallax_ridge)

	sub_viewport = SubViewport.new()
	sub_viewport.size = Vector2i(_view_px())
	sub_viewport.transparent_bg = true
	sub_viewport.disable_3d = true
	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(sub_viewport)

	# Every cell gets a plain base tile first. Transition art is allowed to
	# have transparent edges; without this underlay any missing/transparent
	# cell shows the black space plate through the SubViewport.
	underlay = TileMapLayer.new()
	underlay.tile_set = tile_set
	underlay.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sub_viewport.add_child(underlay)

	tilemap = TileMapLayer.new()
	tilemap.tile_set = tile_set
	tilemap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sub_viewport.add_child(tilemap)

	# Rock is a material, not a decal: duplicate only the plain rock cells on a
	# dark layer. The mossy temperate rock otherwise blends into grass and the
	# ridge belts disappear. Transition cells stay on the base layer so their
	# baked edges are not double-darkened.
	rockmap = TileMapLayer.new()
	rockmap.tile_set = tile_set
	rockmap.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rockmap.modulate = Color(1.18, 1.16, 1.08, 1.0)
	rockmap.z_index = 1
	sub_viewport.add_child(rockmap)

	display = TextureRect.new()
	display.texture = sub_viewport.get_texture()
	display.size = get_viewport_rect().size
	display.position = Vector2.ZERO
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.stretch_mode = TextureRect.STRETCH_SCALE
	# Linear on the projected viewport smooths the isometric resample; the
	# underlying 64 px tile textures stay nearest-filtered inside the SubViewport.
	display.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shader_mat = ShaderMaterial.new()
	shader_mat.shader = load("res://shaders/map_view.gdshader") as Shader
	display.material = shader_mat
	add_child(display)

	# Painted below structures and actors: a south-face shadow turns the rock
	# belt from a recoloured tile into a readable plateau without new art.
	cliff_layer = Node2D.new()
	cliff_layer.z_index = 11
	add_child(cliff_layer)

	# Small palette-locked pebbles/cracks/tufts sit above transition tiles and
	# below structures, so they dress the ground without competing with props.
	decal_layer = Node2D.new()
	decal_layer.z_index = 14
	add_child(decal_layer)

	overlay_layer = Node2D.new()
	overlay_layer.z_index = 22
	add_child(overlay_layer)

	fog_layer = Node2D.new()
	fog_layer.z_index = 23
	add_child(fog_layer)
	fog_mat = ShaderMaterial.new()
	fog_mat.shader = load("res://shaders/fog_veil.gdshader") as Shader

	debug_layer = Node2D.new()
	debug_layer.z_index = 30
	add_child(debug_layer)

	structure_layer = Node2D.new()
	structure_layer.z_index = 20
	add_child(structure_layer)

	actor_layer = Node2D.new()
	actor_layer.z_index = 25
	add_child(actor_layer)

	ambient_layer = Node2D.new()
	ambient_layer.z_index = 30
	add_child(ambient_layer)
	_build_ambient()

	# Veil drawn above actors so a ridge really hides the tile behind it.
	# Toggleable: F6 turns line-of-sight masking off for clarity.
	occlusion_layer = Node2D.new()
	occlusion_layer.z_index = 1000
	add_child(occlusion_layer)

	player_tex = load("res://assets/tilesets/structures/lander.png") as Texture2D
	if ResourceLoader.exists("res://assets/sprites/markers/data_node.png"):
		node_tex = load("res://assets/sprites/markers/data_node.png") as Texture2D
	if ResourceLoader.exists("res://assets/props/relay_beacon.png"):
		relay_tex = load("res://assets/props/relay_beacon.png") as Texture2D
	get_viewport().size_changed.connect(_on_viewport_resized)
	_update_view()


func _build_ui() -> void:
	ui_layer = CanvasLayer.new()
	ui_layer.layer = 10
	add_child(ui_layer)

	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root = root

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.045, 0.06, 0.92)
	style.border_color = Color(0.25, 0.35, 0.40, 0.75)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 5
	style.content_margin_bottom = 5
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(8, 8)
	panel.custom_minimum_size = Vector2(160, 0)
	root.add_child(panel)

	minimap = Control.new()
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.offset_left = -90.0
	minimap.offset_top = 8.0
	minimap.offset_right = -8.0
	minimap.offset_bottom = 90.0
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	minimap.draw.connect(_draw_minimap)
	root.add_child(minimap)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "EXOPLANET SURVEY"
	title.add_theme_font_size_override("font_size", 11)
	title.add_theme_color_override("font_color", Color("#d9e6e1"))
	vbox.add_child(title)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 9)
	info_label.add_theme_color_override("font_color", Color("#9fc6b8"))
	vbox.add_child(info_label)

	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 9)
	status_label.add_theme_color_override("font_color", Color("#e8f0ea"))
	vbox.add_child(status_label)

	hazard_label = Label.new()
	hazard_label.add_theme_font_size_override("font_size", 9)
	vbox.add_child(hazard_label)

	nav_label = Label.new()
	nav_label.add_theme_font_size_override("font_size", 8)
	nav_label.add_theme_color_override("font_color", Color("#65e6d6"))
	vbox.add_child(nav_label)

	view_label = Label.new()
	view_label.add_theme_font_size_override("font_size", 8)
	view_label.add_theme_color_override("font_color", Color("#7f9aa8"))
	vbox.add_child(view_label)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 4)
	vbox.add_child(row1)
	var new_btn := _make_button("New (R)", Vector2(64, 18))
	new_btn.pressed.connect(_on_new_pressed)
	row1.add_child(new_btn)
	var biome_btn := _make_button("Biome (B)", Vector2(64, 18))
	biome_btn.pressed.connect(_on_biome_pressed)
	row1.add_child(biome_btn)

	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 4)
	vbox.add_child(row2)
	var view_btn := _make_button("View (V)", Vector2(64, 18))
	view_btn.pressed.connect(_on_view_pressed)
	row2.add_child(view_btn)
	var grid_btn := _make_button("Grid (G)", Vector2(64, 18))
	grid_btn.pressed.connect(_on_grid_pressed)
	row2.add_child(grid_btn)

	var row3 := HBoxContainer.new()
	row3.add_theme_constant_override("separation", 4)
	vbox.add_child(row3)
	var same_btn := _make_button("Same (T)", Vector2(64, 18))
	same_btn.pressed.connect(_on_same_pressed)
	row3.add_child(same_btn)
	var copy_btn := _make_button("Copy (C)", Vector2(64, 18))
	copy_btn.pressed.connect(_on_copy_seed)
	row3.add_child(copy_btn)

	var dpad := GridContainer.new()
	dpad.columns = 3
	dpad.add_theme_constant_override("h_separation", 2)
	dpad.add_theme_constant_override("v_separation", 2)
	dpad.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	dpad.offset_left = -110.0
	dpad.offset_top = -92.0
	dpad.offset_right = -8.0
	dpad.offset_bottom = -8.0
	root.add_child(dpad)
	dpad.add_child(_blank_cell())
	dpad.add_child(_make_dpad_button("W", Vector2i(0, -1)))
	dpad.add_child(_blank_cell())
	dpad.add_child(_make_dpad_button("A", Vector2i(-1, 0)))
	dpad.add_child(_blank_cell())
	dpad.add_child(_make_dpad_button("D", Vector2i(1, 0)))
	dpad.add_child(_blank_cell())
	dpad.add_child(_make_dpad_button("S", Vector2i(0, 1)))
	dpad.add_child(_blank_cell())

	var hint := Label.new()
	hint.text = "WASD move • B biome • V view • F4 mountains • F5 outposts • F6 sight • F7 props • F8 sky • F9 debug • H UI"
	hint.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 10.0
	hint.offset_right = 500.0
	hint.offset_top = -20.0
	hint.offset_bottom = -4.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", Color("#6f8790"))
	root.add_child(hint)

	message_label = Label.new()
	message_label.set_anchors_preset(Control.PRESET_CENTER)
	message_label.offset_left = -230.0
	message_label.offset_right = 230.0
	message_label.offset_top = -34.0
	message_label.offset_bottom = 34.0
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 18)
	message_label.add_theme_color_override("font_color", Color("#ffd479"))
	message_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.85))
	message_label.add_theme_constant_override("outline_size", 4)
	message_label.visible = false
	root.add_child(message_label)

	debug_label = Label.new()
	debug_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	debug_label.offset_left = -330.0
	debug_label.offset_right = -10.0
	debug_label.offset_top = 98.0
	debug_label.offset_bottom = 220.0
	debug_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	debug_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	debug_label.add_theme_font_size_override("font_size", 9)
	debug_label.add_theme_color_override("font_color", Color("#9fc6b8"))
	debug_label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	debug_label.add_theme_constant_override("outline_size", 3)
	debug_label.visible = debug_visible
	root.add_child(debug_label)


func _make_button(text: String, size: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = size
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 9)
	return btn


func _make_dpad_button(text: String, dir: Vector2i) -> Button:
	var btn := _make_button(text, Vector2(30, 24))
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(_on_dpad.bind(dir))
	return btn


func _blank_cell() -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(30, 24)
	return c


func _new_seed() -> void:
	seed_value = ui_rng.randi_range(1000, 99999)
	_generate()




func _generate() -> void:
	rng.seed = seed_value
	planet_name = "KOI-%04d b" % (seed_value % 9999)
	chunks.clear()
	mapped_chunks.clear()
	has_mapped_bounds = false
	game_over = false
	message_text = ""
	turns_left = TURNS_START
	hull = HULL_START
	data_collected = 0
	hazard_cell = Vector2i(-999, -999)
	hazard_kind = ""
	objectives.clear()
	collected.clear()
	_init_noise()
	player_cell = _find_start()
	_place_start_landmark()
	# A single opening landmark still reads as "one rock in a lawn". Mountain
	# archetypes get two more chains around the lander so the promise of the
	# seed is visible before the player moves.
	if archetype_name in ["Mountainous", "Broken Highlands", "Canyonlands", "Fractured"]:
		for i in range(2):
			_place_start_landmark(false)
	_place_objectives()
	_spawn_hazard()
	_update_chunks()
	_render_window()
	_apply_biome_tint()
	_build_ambient()
	_refresh_status()


func _refresh_world() -> void:
	"""Regenerate loaded chunks after a feature toggle, keeping the player."""
	chunks.clear()
	mapped_chunks.clear()
	has_mapped_bounds = false
	_update_chunks()
	_render_window()
	_refresh_status()


func _init_noise() -> void:
	elevation.seed = seed_value
	elevation.frequency = 0.035
	elevation.fractal_octaves = 4
	elevation.fractal_gain = 0.5
	elevation.fractal_lacunarity = 2.0

	detail.seed = seed_value + 911
	detail.frequency = 0.05
	detail.fractal_octaves = 3
	detail.fractal_gain = 0.5
	detail.fractal_lacunarity = 2.0

	variant_noise.seed = seed_value + 1777
	variant_noise.frequency = 0.045
	variant_noise.fractal_octaves = 2
	variant_noise.fractal_gain = 0.5
	variant_noise.fractal_lacunarity = 2.0

	# Domain warp breaks up the long, straight noise contours that otherwise
	# make lakes and coastlines read as diagonal bands.
	warp_noise.seed = seed_value + 2503
	warp_noise.frequency = 0.018
	warp_noise.fractal_octaves = 2
	warp_noise.fractal_gain = 0.5
	warp_noise.fractal_lacunarity = 2.0

	# High-frequency shoreline jitter so the water threshold does not cut
	# long orthogonal slabs. Kept small: it should wobble the coast, not
	# fragment the lakes.
	shore_noise.seed = seed_value + 3301
	shore_noise.frequency = 0.14
	shore_noise.fractal_octaves = 2
	shore_noise.fractal_gain = 0.5
	shore_noise.fractal_lacunarity = 2.0

	# Low-frequency mask: some stretches of coast should stay clean while
	# others fray. Without it every lake edge gets the same high-frequency
	# "eaten away" treatment.
	rough_noise.seed = seed_value + 4703
	rough_noise.frequency = 0.045
	rough_noise.fractal_octaves = 2
	rough_noise.fractal_gain = 0.5
	rough_noise.fractal_lacunarity = 2.0

	# Decal scatter clusters in 2-4 cell neighbourhoods rather than freckling
	# every eligible cell independently.
	decal_noise.seed = seed_value + 6103
	decal_noise.frequency = 0.075
	decal_noise.fractal_octaves = 2
	decal_noise.fractal_gain = 0.5
	decal_noise.fractal_lacunarity = 2.0

	# Low-frequency belts, not another shoreline. A narrow band of rock terrain
	# crosses several chunks, so the eye reads a mountain range rather than
	# isolated boulders. World coordinates keep it continuous at chunk edges.
	ridge_noise.seed = seed_value + 6101
	ridge_noise.frequency = 0.035
	ridge_noise.fractal_octaves = 3
	ridge_noise.fractal_gain = 0.5
	ridge_noise.fractal_lacunarity = 2.0

	_pick_archetype()
	water_shape_pad = WaterShaper.pad()
	water_shape_keys = WaterShaper.water_keys(BIOMES[biome_index])


func _pick_archetype() -> void:
	# String.hash() avalanches small sequential seeds much better than a
	# linear congruential seed, so seed 1/2/3 do not all land in the same
	# terrain family. The biome index keeps the same seed different per world.
	var h := ("%d:%d" % [seed_value, biome_index]).hash()
	terrain_archetype = TERRAIN_ARCHETYPES[
		absi(h) % TERRAIN_ARCHETYPES.size()
	]
	archetype_name = str(terrain_archetype["name"])


func _find_start() -> Vector2i:
	# Prefer a broad landing site, not a one-tile island. Score a 5x5 patch of
	# walkable cells and take the first good site, otherwise the best seen.
	var best := Vector2i.ZERO
	var best_score := -1
	for r in range(0, 13):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if r > 0 and abs(dx) != r and abs(dy) != r:
					continue
				var c := Vector2i(dx, dy)
				if not _is_walkable_world(c):
					continue
				var score := 0
				for oy in range(-2, 3):
					for ox in range(-2, 3):
						if _is_walkable_world(c + Vector2i(ox, oy)):
							score += 1
				if score > best_score:
					best_score = score
					best = c
				if score >= 18:
					return c
	return best


func _place_start_landmark(allow_crater: bool = true) -> void:
	# Guarantee one readable natural landmark near the lander so the opening
	# screen shows more than flat terrain. The rest still comes from chunks.
	if not bool(feature_toggles.get("mountains", true)):
		return
	var b: Dictionary = BIOMES[biome_index]
	var biome_id := str(b["id"])
	var key := "mountain_massif" if biome_id == "temperate" else "mountain_range"
	match biome_id:
		"volcanic":
			key = "volcano"
		"arid":
			key = "mesa" if randf() < 0.55 else "mesa_b"
		"cryo":
			key = "iceberg"
		"ocean":
			key = "islet"
		"barren":
			key = "impact_crater" if allow_crater else "mesa"
		"methane":
			key = "iceberg"
		"iron":
			key = "mesa" if randf() < 0.55 else "mesa_b"
		"sulfur":
			key = "volcano"
		"crystal":
			key = "crystal_outcrop"
		"obsidian":
			key = "volcano"
		"ammonia":
			key = "iceberg"
		"carbon":
			key = "impact_crater"
	# A plains/archipelago opening should not put a mountain wall beside the
	# lander; use a low, readable landmark instead.
	if archetype_name == "Open Plains":
		key = "impact_crater"
	elif archetype_name in ["Lake District", "Archipelago"] and biome_id not in ["volcanic", "sulfur", "obsidian"]:
		key = "islet" if biome_id == "ocean" else "geyser"
	if key == "impact_crater" and not allow_crater:
		key = "mesa"
	var info: Dictionary = STRUCTURES[key]
	var w: int = info["w"]
	var h: int = info["h"]

	var allowed: Array = []
	for field in [
		"base", "base_alt", "detail", "detail_alt", "detail_alt2",
		"detail_alt3", "rock", "rock_alt",
	]:
		var tile := str(b.get(field, ""))
		if tile != "":
			allowed.append(tile)
	for variant_key in b.get("base_variants", []):
		var vk := str(variant_key)
		if vk != "":
			allowed.append(vk)
	if biome_id == "ocean":
		# Islets sit in shallow water; reef/beach edges are also valid.
		allowed = [str(b["base"]), str(b["rock"])]
		if str(b.get("shore", "")) != "":
			allowed.append(str(b["shore"]))
	elif biome_id == "barren":
		allowed = [str(b["base"]), str(b["detail"]), str(b["rock"])]

	for attempt in range(240):
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(4.0, 6.5)
		var gx := int(round(player_cell.x + cos(ang) * dist)) - (w >> 1)
		var gy := int(round(player_cell.y + sin(ang) * dist)) - (h >> 1)
		var c := _world_to_chunk(Vector2i(gx, gy))
		var lx := gx - c.x * CHUNK
		var ly := gy - c.y * CHUNK
		if lx < 0 or ly < 0 or lx + w > CHUNK or ly + h > CHUNK:
			continue

		var ok := true
		for yy in range(h):
			for xx in range(w):
				var cell := Vector2i(gx + xx, gy + yy)
				if cell == player_cell or not (_raw_terrain_world(cell.x, cell.y) in allowed):
					ok = false
					break
			if not ok:
				break
		if not ok:
			continue

		var data := _get_chunk(c)
		for s in data["structures"]:
			if gx < int(s["gx"]) + int(s["w"]) and gx + w > int(s["gx"]) \
					and gy < int(s["gy"]) + int(s["h"]) and gy + h > int(s["gy"]):
				ok = false
				break
		if ok:
			data["structures"].append({
				"key": key, "gx": gx, "gy": gy, "w": w, "h": h,
			})
			return


func _place_objectives() -> void:
	# Only place markers inside the region the lander can actually walk to.
	# Water, lava and multi-tile structures can isolate pockets near the start;
	# the old test accepted any walkable cell, so a marker could spawn behind a
	# lava field and make the sector unwinnable. One bounded flood fill is cheap
	# next to the 1200 placement attempts and makes connectivity structural
	# instead of something the player has to discover.
	var reach := _reachable_world_cells()
	objectives.clear()
	collected.clear()
	objective_tiers.clear()
	objective_values.clear()
	data_caches.clear()
	cache_taken.clear()
	for i in range(OBJECTIVE_COUNT):
		var placed := false
		var tier := 1 + mini(1, i / 2)
		var value := 1 + (tier - 1)
		var band := 4.0 + float(i) * 1.9
		for attempt in range(1200):
			var ang := rng.randf() * TAU
			var dist := rng.randf_range(maxf(3.0, band - 0.9), band + 0.9)
			var c := Vector2i(
				int(round(player_cell.x + cos(ang) * dist)),
				int(round(player_cell.y + sin(ang) * dist))
			)
			if not reach.has(c) or not _is_walkable_world(c) or c == player_cell or objectives.has(c):
				continue
			var ok := true
			for o in objectives:
				if abs(o.x - c.x) + abs(o.y - c.y) < 3:
					ok = false
					break
			if ok:
				objectives.append(c)
				collected.append(false)
				objective_tiers.append(tier)
				objective_values.append(value)
				placed = true
				break
		if not placed:
			for attempt in range(2000):
				var c := Vector2i(
					player_cell.x + rng.randi_range(-14, 14),
					player_cell.y + rng.randi_range(-14, 14)
				)
				if reach.has(c) and _is_walkable_world(c) and c != player_cell and not objectives.has(c):
					objectives.append(c)
					collected.append(false)
					objective_tiers.append(tier)
					objective_values.append(value)
					placed = true
					break
		if not placed:
			# Deterministic last resort: nearest reachable cell that is not the
			# lander and not already used. Guarantees the node count holds even
			# on a start box that is almost entirely blocked.
			for c in reach.keys():
				var cell: Vector2i = c
				if cell != player_cell and not objectives.has(cell):
					objectives.append(cell)
					collected.append(false)
					objective_tiers.append(tier)
					objective_values.append(value)
					break


	# Optional data caches. They are not part of the quota: they reward a
	# detour and make the player choose a route instead of beelining one node.
	for cache_i in range(3):
		var band := 6.0 + float(cache_i) * 3.0
		for attempt in range(900):
			var ang := rng.randf() * TAU
			var dist := rng.randf_range(maxf(4.0, band - 1.0), band + 1.0)
			var cc := Vector2i(
				int(round(player_cell.x + cos(ang) * dist)),
				int(round(player_cell.y + sin(ang) * dist))
			)
			if not reach.has(cc) or not _is_walkable_world(cc) or cc == player_cell:
				continue
			if objectives.has(cc) or data_caches.has(cc):
				continue
			var too_close := false
			for o in objectives:
				if abs(o.x - cc.x) + abs(o.y - cc.y) < 2:
					too_close = true
					break
			for o in data_caches:
				if abs(o.x - cc.x) + abs(o.y - cc.y) < 3:
					too_close = true
					break
			if too_close:
				continue
			data_caches.append(cc)
			cache_taken.append(false)
			break


func _spawn_hazard() -> void:
	if game_over:
		return
	var kinds := [
		{"name": "Solar flare", "color": Color(1.0, 0.35, 0.20)},
		{"name": "Dust storm", "color": Color(0.86, 0.68, 0.35)},
		{"name": "Radiation surge", "color": Color(0.55, 1.0, 0.45)},
		{"name": "Seismic shock", "color": Color(1.0, 0.62, 0.25)},
	]
	var k: Dictionary = kinds[rng.randi_range(0, kinds.size() - 1)]
	hazard_kind = k["name"]
	hazard_color = k["color"]
	hazard_cell = Vector2i(
		player_cell.x + rng.randi_range(-6, 6) - 1,
		player_cell.y + rng.randi_range(-6, 6) - 1
	)


func _try_move(dir: Vector2i) -> void:
	if game_over:
		return
	var target := player_cell + dir
	if not _is_walkable_world(target):
		return

	var from_cell := player_cell
	player_cell = target
	turns_left -= 1

	for i in range(objectives.size()):
		if objectives[i] == player_cell and not collected[i]:
			collected[i] = true
			data_collected += 1

	if _in_hazard(player_cell):
		hull -= 1

	if hull <= 0:
		game_over = true
		message_text = "LANDER LOST\nPress R for a new map"
	elif data_collected >= objectives.size() and objectives.size() > 0:
		game_over = true
		message_text = "MISSION COMPLETE\nPress R for a new map"
	elif turns_left <= 0:
		game_over = true
		message_text = "OUT OF TURNS\nPress R for a new map"
	else:
		_spawn_hazard()

	_update_chunks()
	_render_window()
	_pan_camera(from_cell)
	_refresh_status()


func _in_hazard(cell: Vector2i) -> bool:
	return (
		cell.x >= hazard_cell.x and cell.x < hazard_cell.x + 3
		and cell.y >= hazard_cell.y and cell.y < hazard_cell.y + 3
	)


func _update_chunks() -> void:
	var center := _world_to_chunk(player_cell)
	for cy in range(center.y - 1, center.y + 2):
		for cx in range(center.x - 1, center.x + 2):
			_get_chunk(Vector2i(cx, cy))
	var keys := chunks.keys()
	for key in keys:
		if abs(key.x - center.x) > 2 or abs(key.y - center.y) > 2:
			chunks.erase(key)


func _get_chunk(coord: Vector2i) -> Dictionary:
	if chunks.has(coord):
		return chunks[coord]
	var data := _generate_chunk(coord)
	chunks[coord] = data
	_record_mapped_chunk(coord, data)
	return data


func _record_mapped_chunk(coord: Vector2i, data: Dictionary) -> void:
	if not mapped_chunks.has(coord):
		mapped_chunks[coord] = {
			"terrain": data["terrain"],
			"structures": data["structures"],
		}
	var x0 := coord.x * CHUNK
	var y0 := coord.y * CHUNK
	if not has_mapped_bounds:
		mapped_lo = Vector2i(x0, y0)
		mapped_hi = Vector2i(x0 + CHUNK, y0 + CHUNK)
		has_mapped_bounds = true
	else:
		mapped_lo.x = mini(mapped_lo.x, x0)
		mapped_lo.y = mini(mapped_lo.y, y0)
		mapped_hi.x = maxi(mapped_hi.x, x0 + CHUNK)
		mapped_hi.y = maxi(mapped_hi.y, y0 + CHUNK)


func _generate_chunk(coord: Vector2i) -> Dictionary:
	var arr: Array = []
	arr.resize(CHUNK * CHUNK)
	var b: Dictionary = BIOMES[biome_index]

	# Sample one cell of padding around the chunk so the smoothing pass sees
	# the same neighbours from every chunk and the seams stay deterministic.
	# Water shaping votes over a 3x3 window before the smoothing pass, which
	# reads one cell further out again, hence water_shape_pad (2) of raw halo.
	var off := water_shape_pad
	var pad := CHUNK + off * 2
	var raw: Array = []
	raw.resize(pad * pad)
	for ly in range(-off, CHUNK + off):
		for lx in range(-off, CHUNK + off):
			raw[(ly + off) * pad + (lx + off)] = _sample_terrain(
				b, coord.x * CHUNK + lx, coord.y * CHUNK + ly
			)
	if water_shaping:
		WaterShaper.apply(raw, pad, b, water_shape_keys)
	for ly in CHUNK:
		for lx in CHUNK:
			arr[ly * CHUNK + lx] = _smooth_cell(raw, pad, lx, ly, b)
	_coalesce_water_pinholes(raw, pad, arr, b)

	_carve_ridges(coord, arr, b)
	var structures := _generate_chunk_structures(coord, arr, b)
	var props := _generate_chunk_props(coord, arr, structures, b)
	return {"terrain": arr, "structures": structures, "props": props}


func _sample_terrain(b: Dictionary, wx: int, wy: int) -> String:
	var fx := float(wx)
	var fy := float(wy)
	# Two decorrelated samples give the contours a natural wobble instead of
	# stretching the same warp in both axes.
	var sx := fx + warp_noise.get_noise_2d(fx, fy) * 14.0
	var sy := fy + warp_noise.get_noise_2d(fx + 41.0, fy - 29.0) * 14.0
	var n := elevation.get_noise_2d(sx, sy)
	var det := detail.get_noise_2d(sx, sy) + float(terrain_archetype.get("detail", 0.0))
	var elev := n + float(terrain_archetype.get("elev", 0.0))
	var gen := str(b.get("generator", "continents"))

	# Each world gets its own landform grammar instead of every biome reusing
	# the same thresholded fBm field. The underlying noise is still seeded by
	# the world seed, so a seed remains reproducible; only the shape language
	# changes. Keep the output in the -1..1 range _pick_terrain expects.
	match gen:
		"archipelago":
			# Island chains: a lower-frequency mask chooses island groups,
			# a higher-frequency one tears channels through them.
			var groups := elevation.get_noise_2d(sx * 0.62 + 17.0, sy * 0.62 - 9.0)
			var cuts := detail.get_noise_2d(sx * 1.65 - 31.0, sy * 1.65 + 23.0)
			elev = groups * 0.68 + cuts * 0.36 - 0.04
			det += cuts * 0.35
		"dunes":
			# Wind-aligned dunes: a directional wave warped by low-frequency
			# noise. Broad bands, not another isotropic blob field.
			var warp := warp_noise.get_noise_2d(fx * 0.42, fy * 0.42)
			var dune := sin((fx * 0.72 + fy * 0.35) * 0.055 + warp * 5.0)
			elev = n * 0.55 + dune * 0.22 + float(terrain_archetype.get("elev", 0.0))
			det += dune * 0.42
		"caldera":
			# Concentric volcanic provinces: low centres become lava, high
			# rims become basalt/obsidian. abs() makes rings instead of blobs.
			var ring := absf(n)
			elev = -1.0 + 2.35 * smoothstep(0.015, 0.42, ring)
			elev += float(terrain_archetype.get("elev", 0.0)) * 0.45
			det += (1.0 - ring) * 0.45
		"fractured":
			# Ice/glass plates separated by narrow cracks; the cracks read as
			# frozen lakes or dark seams, the plates as raised shelves.
			var crack := absf(n)
			elev = -1.0 + 2.0 * smoothstep(0.012, 0.075, crack)
			elev += float(terrain_archetype.get("elev", 0.0)) * 0.40
			det += (1.0 - crack) * 0.35
		"cratered":
			# Basins and rims from two crater scales. abs() gives the bowl,
			# the offset second field breaks the circular repetition.
			var bowl := absf(elevation.get_noise_2d(sx * 1.9 + 53.0, sy * 1.9 - 47.0))
			elev = -1.0 + 2.1 * smoothstep(0.01, 0.13, bowl)
			elev += float(terrain_archetype.get("elev", 0.0)) * 0.35
			det += (1.0 - bowl) * 0.40
		"faceted":
			# Quantised crystal facets: stepped elevation and detail create
			# angular plates instead of smooth organic fBm.
			elev = floor(n * 5.0) / 5.0
			det = floor(det * 6.0) / 6.0
			elev += float(terrain_archetype.get("elev", 0.0)) * 0.35
		_:
			pass

	return _pick_terrain(b, elev, det, wx, wy)


func _carve_ridges(coord: Vector2i, arr: Array, b: Dictionary) -> void:
	"""Turn narrow low-frequency noise bands into walkable rock belts.

	The band is sampled in world space, so the same ridge continues across
	chunk borders. Rock is a terrain material, not a decal: it participates in
	transitions and gives the large mountain sprites a visual base to sit on.
	"""
	if not bool(feature_toggles["mountains"]):
		return
	var biome_id := str(b["id"])
	if biome_id == "ocean":
		return
	var rock := str(b.get("rock", ""))
	if rock == "":
		return
	var water := str(b.get("water", ""))
	var shore := str(b.get("shore", ""))
	var ridge_width := float(terrain_archetype.get("ridge", 0.105))
	for ly in CHUNK:
		for lx in CHUNK:
			var wx := coord.x * CHUNK + lx
			var wy := coord.y * CHUNK + ly
			if absf(ridge_noise.get_noise_2d(float(wx), float(wy))) > ridge_width:
				continue
			var idx := ly * CHUNK + lx
			var cur := str(arr[idx])
			if cur == water or (shore != "" and cur == shore):
				continue
			arr[idx] = rock


func _ground_tiles(b: Dictionary) -> Array:
	var ground: Array = [str(b["base"])]
	for key in ["base_alt"]:
		if b.has(key) and str(b[key]) != "":
			ground.append(str(b[key]))
	for key in b.get("base_variants", []):
		ground.append(str(key))
	return ground


func _smooth_cell(raw: Array, pad: int, lx: int, ly: int, b: Dictionary) -> String:
	var cur := str(raw[(ly + water_shape_pad) * pad + (lx + water_shape_pad)])
	var water := str(b.get("water", ""))
	var ground := _ground_tiles(b)
	var is_ground := cur in ground
	# `base` is the normal land fallback, but ocean biomes put open water in
	# `base`. Dropping a one-tile reef/rock speck to `base` there would carve a
	# one-tile water pinhole (and water tiles are BLOCKED), so use the shore
	# material for ocean-type palettes instead.
	var land_fill := str(b.get("base", ""))
	if land_fill.contains("water"):
		land_fill = str(b.get("shore", ""))
		if land_fill == "":
			land_fill = str(b.get("rock", ""))
	var counts := {}
	var same := 0
	for oy in range(-1, 2):
		for ox in range(-1, 2):
			if ox == 0 and oy == 0:
				continue
			var t := str(raw[(ly + water_shape_pad + oy) * pad + (lx + water_shape_pad + ox)])
			if t == cur:
				same += 1
			counts[t] = int(counts.get(t, 0)) + 1
	var best_any := ""
	var best_any_count := 0
	for t in counts:
		var n := int(counts[t])
		if n > best_any_count:
			best_any = str(t)
			best_any_count = n

	# Water edges are smoothed too, but lava channels stay authored. Removing
	# one-tile spurs and filling one-tile bays rounds the coast before the
	# shore ring and keeps the 64px grid from reading as stair steps.
	if water != "" and str(b.get("id", "")) != "volcanic":
		if cur == water:
			# Only drop truly isolated water. Keeping one-neighbour spurs is
			# what lets the corner tiles cut a diagonal coast; the old <=1
			# rule erased every diagonal and left rectangular slabs.
			if same == 0:
				return str(b["base"])
			return cur
		if int(counts.get(water, 0)) >= 7:
			return water

	if not is_ground:
		# Drop one-tile specks and thin diagonal tails; keep real clusters.
		# Merge into the dominant neighbour instead of a fixed `base`: in
		# ocean, `base` is water, so returning it turned a lone reef speck into
		# an impassable water pinhole; returning `land_fill` then turned
		# water-side specks into 1-tile islands. The majority material does the
		# right thing in both directions and stays local.
		if same <= 1:
			if best_any != "":
				return best_any
			return land_fill
		return cur

	# Fill one-tile holes and let a strong surrounding material take over a
	# base cell, which rounds off the noisy edges of detail patches.
	var best := ""
	var best_count := 0
	for t in counts:
		if str(t) in ground:
			continue
		var n := int(counts[t])
		if n > best_count:
			best = str(t)
			best_count = n
	if best_count >= 5:
		return best
	return cur



func _coalesce_water_pinholes(raw: Array, pad: int, arr: Array, b: Dictionary) -> void:
	"""Remove closed 1-2 cell water bodies after `_smooth_cell()`.

	`_smooth_cell()` decides each cell from the raw halo, so two neighbouring
	cells can disagree: a shallow pinhole sees two raw water neighbours that
	are themselves smoothed to land, stays water, and the final map has a
	1-2 cell hole. This is the "water coalescing" stage: rebuild a one-cell
	halo of already-smoothed values, run 4-connected components over that
	17x17 window, and fill any 1-2 cell body that touches the chunk. The halo
	makes the result seam-safe -- a 1-2 cell body containing a chunk cell
	cannot reach the outer edge of the window, and both chunks compute the
	same body from the same deterministic raw halo.

	Only biomes whose named water tile is real water participate; volcanic
	lava fields are authored hazards, not pinholes.
	"""
	var water_key := str(b.get("water", ""))
	if water_key == "" or not water_key.contains("water"):
		return
	var span := CHUNK + 2
	var smooth := PackedStringArray()
	smooth.resize(span * span)
	for y in CHUNK:
		for x in CHUNK:
			smooth[(y + 1) * span + (x + 1)] = str(arr[y * CHUNK + x])
	for x in range(-1, CHUNK + 1):
		smooth[x + 1] = _smooth_cell(raw, pad, x, -1, b)
		smooth[(CHUNK + 1) * span + (x + 1)] = _smooth_cell(raw, pad, x, CHUNK, b)
	for y in CHUNK:
		smooth[(y + 1) * span] = _smooth_cell(raw, pad, -1, y, b)
		smooth[(y + 1) * span + (CHUNK + 1)] = _smooth_cell(raw, pad, CHUNK, y, b)

	var mask := PackedByteArray()
	mask.resize(span * span)
	for i in range(span * span):
		mask[i] = 1 if str(smooth[i]).contains("water") else 0
	var seen := PackedByteArray()
	seen.resize(span * span)

	# A fixed land material keeps the fill identical on both sides of a seam;
	# the dominant-neighbour choice would need cells outside the local window.
	var land_fill := str(b.get("base", ""))
	if land_fill.contains("water"):
		land_fill = str(b.get("shore", ""))
		if land_fill == "":
			land_fill = str(b.get("rock", ""))
	if land_fill == "":
		return

	for y in range(span):
		for x in range(span):
			var i := y * span + x
			if mask[i] == 0 or seen[i] == 1:
				continue
			var q: Array[Vector2i] = [Vector2i(x, y)]
			seen[i] = 1
			var head := 0
			var cells: Array[Vector2i] = []
			var touches_edge := false
			while head < q.size():
				var cur := q[head]
				head += 1
				cells.append(cur)
				if cur.x == 0 or cur.y == 0 or cur.x == span - 1 or cur.y == span - 1:
					touches_edge = true
				for d in DIRS:
					var n: Vector2i = cur + d
					if n.x < 0 or n.y < 0 or n.x >= span or n.y >= span:
						continue
					var ni := n.y * span + n.x
					if seen[ni] == 1 or mask[ni] == 0:
						continue
					seen[ni] = 1
					q.append(n)
			if cells.size() > 2 or touches_edge:
				continue
			for c in cells:
				if c.x >= 1 and c.x <= CHUNK and c.y >= 1 and c.y <= CHUNK:
					arr[(c.y - 1) * CHUNK + (c.x - 1)] = land_fill


func _generate_chunk_props(
	coord: Vector2i, arr: Array, structures: Array, b: Dictionary
) -> Array:
	var out: Array = []
	if not bool(feature_toggles["props"]):
		return out
	var choices: Array = PROPS.get(str(b["id"]), [])
	if choices.is_empty():
		return out
	var density := float(PROP_DENSITY.get(str(b["id"]), 0.06))

	var occupied := {}
	for s in structures:
		for y in range(s["gy"], s["gy"] + s["h"]):
			for x in range(s["gx"], s["gx"] + s["w"]):
				occupied[Vector2i(x, y)] = true

	var crng := RandomNumberGenerator.new()
	crng.seed = _chunk_seed(coord) ^ 0x2c1b3c6d
	for ly in CHUNK:
		for lx in CHUNK:
			var wx := coord.x * CHUNK + lx
			var wy := coord.y * CHUNK + ly
			var t := str(arr[ly * CHUNK + lx])
			if t in BLOCKED or occupied.has(Vector2i(wx, wy)):
				continue
			# Per-biome density keeps sparse worlds sparse: a coral shard or
			# shrub should be an accent, not a lawn.
			if crng.randf() > density:
				continue
			out.append({
				"key": str(choices[crng.randi_range(0, choices.size() - 1)]),
				"gx": wx, "gy": wy,
				"flip": crng.randf() < 0.5,
				"scale": crng.randf_range(0.52, 0.78),
			})
	return out



func _pick_terrain(b: Dictionary, elev: float, det: float, wx: int, wy: int) -> String:
	var water: String = str(b.get("water", ""))
	var rock: String = str(b.get("rock", ""))
	var wet := elev + float(terrain_archetype.get("water", 0.0))
	if str(b.get("profile", b["id"])) != "volcanic":
		var rough := rough_noise.get_noise_2d(float(wx), float(wy))
		var jag := lerpf(0.015, 0.155, smoothstep(-0.30, 0.30, rough))
		wet += shore_noise.get_noise_2d(float(wx), float(wy)) * jag

	match str(b.get("profile", b["id"])):
		"temperate":
			# Keep the rare biosphere mostly walkable: lakes are punctuation,
			# not the dominant surface.
			if water != "" and wet < float(b.get("water_level", -0.30)):
				return water
			if elev > 0.50 and rock != "":
				return _rock_choice(b, det)
			if det > 0.30:
				return _detail_choice(b, det)
			return _base_choice(b, det, wx, wy)
		"arid":
			if elev < -0.35 or det > 0.42:
				return _detail_choice(b, det)
			if elev > 0.42 and rock != "":
				return _rock_choice(b, det)
			return _base_choice(b, det, wx, wy)
		"cryo":
			if water != "" and wet < float(b.get("water_level", -0.34)):
				return water
			# Cracks are the low shelves. Keep the plateau on the smooth ice
			# base: cryo/rock is a high-frequency speckle tile and turns the
			# whole field into TV static when the fractured plateau is mapped
			# to rock.
			if elev < 0.05 or det > 0.45:
				return _detail_choice(b, det)
			return _base_choice(b, det, wx, wy)
		"volcanic":
			if water != "" and elev < 0.10:
				return water
			if elev > 0.55 and rock != "":
				return _rock_choice(b, det)
			if elev > 0.35:
				return _detail_choice(b, det)
			return _base_choice(b, det, wx, wy)
		"ocean":
			if wet < -0.24:
				return _detail_choice(b, det)
			var reef_at := 0.04 if str(b.get("generator", "")) == "archipelago" else 0.52
			if elev > 0.12 and rock != "":
				return _rock_choice(b, det)
			if elev > reef_at:
				return "ocean/reef"
			return _base_choice(b, det, wx, wy)
		"crystal":
			if elev > 0.10 and rock != "":
				return _rock_choice(b, det)
			if elev < -0.30 or det > 0.24:
				return _detail_choice(b, det)
			return _base_choice(b, det, wx, wy)
		"barren":
			if elev > 0.48 and rock != "":
				return _rock_choice(b, det)
			if det > 0.35:
				return _detail_choice(b, det)
			return _base_choice(b, det, wx, wy)
	return str(b["base"])


func _base_choice(b: Dictionary, det: float, wx: int, wy: int) -> String:
	var variants: Array = b.get("base_variants", [])
	if not variants.is_empty():
		var v := variant_noise.get_noise_2d(float(wx), float(wy))
		var idx := clampi(
			int(floor((v + 1.0) * 0.5 * float(variants.size()))),
			0,
			variants.size() - 1,
		)
		return str(variants[idx])
	var alt := str(b.get("base_alt", ""))
	if alt != "" and det > 0.42:
		return alt
	return str(b["base"])


func _detail_choice(b: Dictionary, det: float) -> String:
	var alt3 := str(b.get("detail_alt3", ""))
	var alt2 := str(b.get("detail_alt2", ""))
	var alt := str(b.get("detail_alt", ""))
	if alt3 != "" and det > 0.68:
		return alt3
	if alt2 != "" and det > 0.56:
		return alt2
	if alt != "" and det > 0.40:
		return alt
	return str(b["detail"])


func _rock_choice(b: Dictionary, det: float) -> String:
	var alt := str(b.get("rock_alt", ""))
	if alt != "" and det > 0.52:
		return alt
	return str(b.get("rock", b["base"]))


func _structure_allowed_tiles(b: Dictionary) -> Array:
	var allowed: Array = []
	for field in [
		"base", "base_alt", "detail", "detail_alt", "detail_alt2",
		"detail_alt3", "rock", "rock_alt",
	]:
		var tile := str(b.get(field, ""))
		if tile != "":
			allowed.append(tile)
	for variant_key in b.get("base_variants", []):
		var vk := str(variant_key)
		if vk != "":
			allowed.append(vk)
	var biome_id := str(b["id"])
	if biome_id == "ocean":
		allowed = [str(b["base"]), str(b["rock"])]
		if str(b.get("shore", "")) != "":
			allowed.append(str(b["shore"]))
	elif biome_id == "barren":
		allowed = [str(b["base"]), str(b["detail"]), str(b["rock"])]
	return allowed


func _structure_fits(
	arr: Array, allowed: Array, occupied: Array, lx: int, ly: int, w: int, h: int
) -> bool:
	if lx < 1 or ly < 1 or lx + w > CHUNK - 1 or ly + h > CHUNK - 1:
		return false
	for yy in range(ly, ly + h):
		for xx in range(lx, lx + w):
			if not (arr[yy * CHUNK + xx] in allowed):
				return false
	var rect := Rect2i(lx, ly, w, h)
	for r in occupied:
		if rect.intersects(r):
			return false
	return true


func _append_structure(
	out: Array, occupied: Array, arr: Array, allowed: Array,
	coord: Vector2i, key: String, lx: int, ly: int
) -> bool:
	var info: Dictionary = STRUCTURES[key]
	var w: int = info["w"]
	var h: int = info["h"]
	if not _structure_fits(arr, allowed, occupied, lx, ly, w, h):
		return false
	# One silhouette repeated eight times reads as a rubber stamp. Give each
	# instance a small deterministic size/tint offset; the footprint and
	# collision stay identical, so this is purely visual de-duplication.
	var jr := RandomNumberGenerator.new()
	jr.seed = hash(Vector3i(coord.x * 37 + lx, coord.y * 53 + ly, key.hash()))
	var warm := Color(1.04, 1.01, 0.94)
	var cool := Color(0.96, 0.99, 1.04)
	out.append({
		"key": key,
		"gx": coord.x * CHUNK + lx,
		"gy": coord.y * CHUNK + ly,
		"w": w,
		"h": h,
		"scale_jitter": jr.randf_range(0.92, 1.08),
		"tint": warm.lerp(cool, jr.randf()),
	})
	occupied.append(Rect2i(lx, ly, w, h))
	return true


func _ridge_key(biome_id: String) -> String:
	match biome_id:
		"volcanic", "sulfur", "obsidian":
			return "volcano"
		"arid":
			return "ridge"
		"iron":
			return "mesa"
		"cryo", "methane", "ammonia":
			return "iceberg"
		"barren", "temperate":
			return "ridge"
		"carbon":
			return "mountain_range"
		"crystal":
			return "crystal_outcrop"
	return "mountain_range"


func _feature_key(biome_id: String, roll: float) -> String:
	match biome_id:
		"volcanic":
			return "volcano" if roll < 0.40 else "geyser"
		"arid":
			return "mesa" if roll < 0.55 else "mesa_b"
		"cryo":
			return "iceberg" if roll < 0.50 else "crystal_outcrop"
		"ocean":
			# Coral is the ocean's native landmark; islets still break up the
			# water so every ocean chunk is not the same spire.
			return "coral_spire" if roll < 0.55 else "islet"
		"barren":
			# Keep impact_crater as the one hero landmark; alternate the two
			# broad mesa silhouettes between chunks instead of stamping craters.
			return "mesa" if roll < 0.55 else "mesa_b"
		"methane":
			return "iceberg" if roll < 0.55 else "crystal_outcrop"
		"iron":
			return "mesa" if roll < 0.55 else "impact_crater"
		"sulfur":
			return "volcano" if roll < 0.50 else "geyser"
		"crystal":
			return "crystal_outcrop"
		"obsidian":
			return "volcano" if roll < 0.55 else "geyser"
		"ammonia":
			return "iceberg"
		"carbon":
			return "impact_crater" if roll < 0.55 else "mesa"
	return "mountain_range"


func _place_ridge_chain(
	out: Array, occupied: Array, arr: Array, allowed: Array,
	coord: Vector2i, biome_id: String, rng: RandomNumberGenerator
) -> void:
	# A 3×2 cap + N×3×2 mids + cap. All segments share the same height and
	# the mid crest is periodic, so they meet without a vertical seam. Only
	# east-west chains are emitted; the art is authored horizontally.
	var count := rng.randi_range(2, 4)
	var span := count * 3
	for attempt in range(16):
		var lx := rng.randi_range(2, maxi(2, CHUNK - span - 2))
		var ly := rng.randi_range(2, maxi(2, CHUNK - 4))
		var trial: Array = occupied.duplicate()
		var tx := lx
		var ok := true
		for i in range(count):
			if not _structure_fits(arr, allowed, trial, tx, ly, 3, 2):
				ok = false
				break
			trial.append(Rect2i(tx, ly, 3, 2))
			tx += 3
		if not ok:
			continue
		tx = lx
		for i in range(count):
			var key := "ridge_mid"
			if i == 0:
				key = "ridge_cap_l"
			elif i == count - 1:
				key = "ridge_cap_r"
			if not _append_structure(out, occupied, arr, allowed, coord, key, tx, ly):
				return
			tx += 3
		return
	# Fallback: single wide strip is better than an empty ridge.
	for attempt in range(6):
		var sx := rng.randi_range(2, maxi(2, CHUNK - 5))
		var sy := rng.randi_range(2, maxi(2, CHUNK - 4))
		if _append_structure(out, occupied, arr, allowed, coord, "ridge_wide", sx, sy):
			return


func _place_ridge(
	out: Array, occupied: Array, arr: Array, allowed: Array,
	coord: Vector2i, biome_id: String, rng: RandomNumberGenerator
) -> void:
	if biome_id == "ocean":
		# Ocean ridges are chains of islets, not mountain walls.
		var ilx := rng.randi_range(2, CHUNK - 3)
		var ily := rng.randi_range(2, CHUNK - 3)
		var idir: Vector2i = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)][rng.randi_range(0, 2)]
		for i in range(rng.randi_range(2, 4)):
			if not _append_structure(out, occupied, arr, allowed, coord, "islet", ilx, ily):
				break
			ilx += idir.x * 2
			ily += idir.y * 2
		return

	var key := _ridge_key(biome_id)
	# Volcanoes are landmarks: at most one per 16×16 chunk, otherwise the
	# 20×16 camera window shows four identical cones at once.
	if key == "volcano":
		for s in out:
			if str(s["key"]) == "volcano":
				return
	if key == "ridge":
		_place_ridge_chain(out, occupied, arr, allowed, coord, biome_id, rng)
		return
	var info: Dictionary = STRUCTURES[key]
	var w: int = info["w"]
	var h: int = info["h"]
	var step := maxi(w, 2)
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)
	]
	var dir: Vector2i = dirs[rng.randi_range(0, dirs.size() - 1)]
	var count := rng.randi_range(4, 7) if key == "mountain_range" else rng.randi_range(3, 6)
	if key == "ridge_wide":
		count = rng.randi_range(2, 4)
	if key == "mountain_massif":
		count = rng.randi_range(1, 2)
	# A volcanic cone is a landmark, not a mountain chain. Four or five
	# identical cones in one view read as a stamp, so cap the chain at two.
	if key == "volcano":
		count = rng.randi_range(1, 2)

	# A chain that starts at the chunk edge and walks out is truncated to one
	# rock, which is why the first density pass still looked sparse. Try
	# several starts and only commit a chain that fits end-to-end.
	for attempt in range(12):
		var lx := rng.randi_range(2, maxi(2, CHUNK - w - 2))
		var ly := rng.randi_range(2, maxi(2, CHUNK - h - 2))
		var tx := lx
		var ty := ly
		var links: Array[Rect2i] = []
		var ok := true
		for i in range(count):
			if not _structure_fits(arr, allowed, occupied, tx, ty, w, h):
				ok = false
				break
			var rect := Rect2i(tx, ty, w, h)
			for other in links:
				if rect.intersects(other):
					ok = false
					break
			if not ok:
				break
			links.append(rect)
			tx += dir.x * step
			ty += dir.y * step
		if not ok:
			continue
		tx = lx
		ty = ly
		for i in range(count):
			if not _append_structure(out, occupied, arr, allowed, coord, key, tx, ty):
				break
			tx += dir.x * step
			ty += dir.y * step
		return

	# Fallback: a single hill is better than an empty chunk.
	for attempt in range(6):
		var sx := rng.randi_range(2, maxi(2, CHUNK - w - 2))
		var sy := rng.randi_range(2, maxi(2, CHUNK - h - 2))
		if _append_structure(out, occupied, arr, allowed, coord, key, sx, sy):
			return


func _place_outpost(
	out: Array, occupied: Array, arr: Array, allowed: Array,
	coord: Vector2i, rng: RandomNumberGenerator
) -> void:
	var modules: Array[String] = ["habitat_dome", "solar_farm", "comms_dish"]
	modules.shuffle()
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
	var dir: Vector2i = dirs[rng.randi_range(0, dirs.size() - 1)]
	var lx := rng.randi_range(2, CHUNK - 4)
	var ly := rng.randi_range(2, CHUNK - 4)
	# One or two modules per outpost. Three identical dome clusters in one
	# view read as copy-paste, which was the wrong kind of "big structure".
	var count := rng.randi_range(1, 2)
	for i in range(count):
		var key := modules[i % modules.size()]
		if not _append_structure(out, occupied, arr, allowed, coord, key, lx, ly):
			break
		lx += dir.x * 2
		ly += dir.y * 2


func _generate_chunk_structures(coord: Vector2i, arr: Array, b: Dictionary) -> Array:
	var out: Array = []
	var crng := RandomNumberGenerator.new()
	crng.seed = _chunk_seed(coord)
	var biome_id := str(b["id"])
	var allowed := _structure_allowed_tiles(b)
	var occupied: Array[Rect2i] = []

	# Mountains are the silhouette of the map. Two attempts per chunk give a
	# proper range instead of one lonely rock; an empty chunk always gets a
	# fallback so the play area never opens on a flat lawn.
	var arch_ridge := float(terrain_archetype.get("ridge_chance", 0.0))
	var ridge_chance := 0.62 + arch_ridge
	if arch_ridge < 0.0:
		# Open Plains / Lake District / Archipelago are allowed to stay open;
		# the generic 0.62 base made every one of them grow mountains.
		ridge_chance = maxf(0.06, 0.30 + arch_ridge)
	match biome_id:
		"temperate", "arid", "barren", "iron", "carbon", "cryo", "methane", "volcanic", "sulfur", "obsidian", "crystal", "ammonia":
			ridge_chance = clampf(ridge_chance, 0.38, 0.96)
		"ocean":
			ridge_chance = clampf(0.38 + arch_ridge * 0.5, 0.24, 0.72)
	if bool(feature_toggles["mountains"]):
		# Mountainous archetypes get one more chain: the 20x16 window only
		# shows ~1.5 chunks, so two chains per 16x16 chunk still read as a
		# single lonely rock on screen.
		var ridge_attempts := 3 if arch_ridge >= 0.10 else 2
		for attempt in range(ridge_attempts):
			var chance := ridge_chance if attempt == 0 else 0.50 + arch_ridge * 0.5
			if crng.randf() < chance:
				_place_ridge(out, occupied, arr, allowed, coord, biome_id, crng)
		# Open water/plain archetypes must be allowed to stay open; only a
		# genuinely mountainous roll gets the guaranteed landmark.
		if out.is_empty() and arch_ridge >= 0.0:
			_place_ridge(out, occupied, arr, allowed, coord, biome_id, crng)

	# Abandoned survey outposts are the "big structure" beat. They read as a
	# deliberate complex rather than another rock, and their footprint blocks
	# movement, so they matter tactically.
	if (
		bool(feature_toggles["outposts"])
		and biome_id in ["arid", "barren", "iron", "carbon", "obsidian"]
		and crng.randf() < 0.18
	):
		_place_outpost(out, occupied, arr, allowed, coord, crng)

	# W6: one hero silhouette (plus two supporting pieces) in the start chunk.
	# Keeping it to the opening chunk makes it a place, not wallpaper repeated
	# in every 16×16 cell.
	if coord == _world_to_chunk(player_cell):
		_place_outcrop_cluster(coord, arr, out, occupied, allowed, biome_id, crng)

	# One additional natural feature keeps chunks from having a single motif.
	# Barren is deliberately sparser: impact_crater is the hero, and mesas are
	# punctuation, not a field of stamps.
	var feature_chance := 0.24 if biome_id == "barren" else 0.44
	if crng.randf() < feature_chance:
		var key := _feature_key(biome_id, crng.randf())
		if key == "impact_crater" and _structure_key_seen("impact_crater"):
			key = "mesa"
		# Never add a second identical cone/geyser to this chunk; the ridge
		# pass already placed the hero volcano.
		if key in ["volcano", "geyser", "impact_crater"]:
			for s in out:
				if str(s["key"]) == key:
					return out
		var info: Dictionary = STRUCTURES[key]
		var w: int = info["w"]
		var h: int = info["h"]
		for attempt in range(10):
			var lx := crng.randi_range(2, maxi(2, CHUNK - w - 2))
			var ly := crng.randi_range(2, maxi(2, CHUNK - h - 2))
			if _append_structure(out, occupied, arr, allowed, coord, key, lx, ly):
				break
	return out


func _place_outcrop_cluster(
	coord: Vector2i, arr: Array, out: Array, occupied: Array,
	allowed: Array, biome_id: String, rng: RandomNumberGenerator
) -> void:
	var key := _decal_biome()
	if key == "" or not STRUCTURES.has(key + "_hero"):
		return
	var pieces := [key + "_hero", key + "_sup_a", key + "_sup_b"]
	for piece in pieces:
		var info: Dictionary = STRUCTURES[piece]
		var w: int = int(info["w"])
		var h: int = int(info["h"])
		for attempt in range(28):
			var lx := rng.randi_range(2, maxi(2, CHUNK - w - 2))
			var ly := rng.randi_range(2, maxi(2, CHUNK - h - 2))
			var gx := coord.x * CHUNK + lx
			var gy := coord.y * CHUNK + ly
			if gx <= player_cell.x + 2 and gx + w >= player_cell.x - 2 and gy <= player_cell.y + 2 and gy + h >= player_cell.y - 2:
				continue
			if _append_structure(out, occupied, arr, allowed, coord, str(piece), lx, ly):
				break


func _structure_key_seen(key: String) -> bool:
	for data in chunks.values():
		for s in data.get("structures", []):
			if str(s.get("key", "")) == key:
				return true
	return false


func _chunk_seed(coord: Vector2i) -> int:
	var h := int(seed_value) & 0x7fffffff
	h = (h * 374761393 + coord.x * 668265263 + coord.y * 1442695041) & 0x7fffffff
	h = (h ^ (h >> 13)) & 0x7fffffff
	h = (h * 1274126177) & 0x7fffffff
	return h


func _raw_terrain_world(x: int, y: int) -> String:
	var c := _world_to_chunk(Vector2i(x, y))
	var data := _get_chunk(c)
	var lx := x - c.x * CHUNK
	var ly := y - c.y * CHUNK
	return data["terrain"][ly * CHUNK + lx]


func _render_terrain_world(x: int, y: int) -> String:
	var raw := _raw_terrain_world(x, y)
	var b: Dictionary = BIOMES[biome_index]
	var water := str(b.get("water", ""))
	var is_water := raw == water
	if is_water:
		var land := 0
		for d in DIRS:
			if _raw_terrain_world(x + d.x, y + d.y) != water:
				land += 1
		var bands: Array = WATER_BANDS.get(str(b.get("id", "")), [])
		if bands.size() >= 3:
			if land >= 3:
				raw = str(bands[0])
			elif land >= 1:
				raw = str(bands[1])
			else:
				raw = str(bands[2])
	if bool(b.get("shore_ring", false)) and not is_water:
		for d in DIRS + CORNER_DIRS:
			if _raw_terrain_world(x + d.x, y + d.y) == str(b.get("water", "")):
				return str(b["shore"])
	return raw


func _is_walkable_world(cell: Vector2i) -> bool:
	# Test the raw field, not the rendered material: `_render_terrain_world()`
	# replaces water with depth bands (`*_shallow`/`*_deep`/`water_shelf`) whose
	# names are not the raw blocked keys. The raw cell is always the canonical
	# water/lava key, so this cannot drift when banding changes.
	var t := _raw_terrain_world(cell.x, cell.y)
	if t in BLOCKED:
		return false
	var data := _get_chunk(_world_to_chunk(cell))
	for s in data["structures"]:
		var gx: int = s["gx"]
		var gy: int = s["gy"]
		var w: int = s["w"]
		var h: int = s["h"]
		if cell.x >= gx and cell.x < gx + w and cell.y >= gy and cell.y < gy + h:
			return false
	return true


func _reachable_world_cells(radius: int = 28) -> Dictionary:
	# Bounded flood fill from the lander over the same walkability test the
	# pathfinder uses. `radius` is a box half-width in cells, not a path length:
	# objectives spawn within 14 cells, so 28 leaves room for detours around a
	# lake or lava field without walking the infinite world.
	var seen := {player_cell: true}
	var q: Array[Vector2i] = [player_cell]
	var head := 0
	while head < q.size():
		var cur: Vector2i = q[head]
		head += 1
		for d in DIRS:
			var n: Vector2i = cur + d
			if seen.has(n):
				continue
			if absi(n.x - player_cell.x) > radius or absi(n.y - player_cell.y) > radius:
				continue
			if not _is_walkable_world(n):
				continue
			seen[n] = true
			q.append(n)
	return seen


func _world_to_chunk(cell: Vector2i) -> Vector2i:
	return Vector2i(
		int(floor(float(cell.x) / float(CHUNK))),
		int(floor(float(cell.y) / float(CHUNK)))
	)


func _flip_alt(key: String, wx: int, wy: int) -> int:
	var alts: Array = source_alts.get(key, [])
	if alts.size() < 2:
		return 0
	var h := int((wx * 73856093) ^ (wy * 19349663) ^ seed_value)
	return int(alts[absi(h) % alts.size()])


func _reveal_around(cell: Vector2i, radius: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				revealed[cell + Vector2i(dx, dy)] = true


func _draw_fog() -> void:
	if fog_layer == null:
		return
	for child in fog_layer.get_children():
		child.free()
	if not fog_enabled:
		return
	if fog_mat != null:
		fog_mat.set_shader_parameter("desat", fog_desat)
	for ly in view_h:
		for lx in view_w:
			var c := Vector2i(view_origin.x + lx, view_origin.y + ly)
			if revealed.has(c):
				continue
			var quad := PackedVector2Array([
				_project(Vector2(c.x * TILE, c.y * TILE)),
				_project(Vector2((c.x + 1) * TILE, c.y * TILE)),
				_project(Vector2((c.x + 1) * TILE, (c.y + 1) * TILE)),
				_project(Vector2(c.x * TILE, (c.y + 1) * TILE)),
			])
			# Soften the reveal boundary by one band: an unrevealed cell next
			# to known ground is a haze, two cells out is half-dark, and the
			# rest is full fog. This keeps the square-cell edge from reading
			# as a hard spotlight.
			var near := 3
			for ny in range(-2, 3):
				for nx in range(-2, 3):
					var d := absi(nx) + absi(ny)
					if d < near and revealed.has(c + Vector2i(nx, ny)):
						near = d
			var fog_alpha := fog_alpha_inner
			if near == 1:
				fog_alpha = fog_alpha_outer
			elif near == 2:
				fog_alpha = fog_alpha_mid
			var poly := Polygon2D.new()
			poly.polygon = quad
			poly.color = Color(1.0, 1.0, 1.0, fog_alpha)
			poly.material = fog_mat
			fog_layer.add_child(poly)


func _render_window() -> void:
	view_origin = player_cell - Vector2i(view_w / 2, view_h / 2)
	_reveal_around(player_cell, fog_reveal_radius if fog_enabled else 0)
	if debug_layer != null and not debug_transitions:
		for child in debug_layer.get_children():
			child.free()
	tilemap.clear()
	underlay.clear()
	rockmap.clear()
	if debug_layer != null:
		for child in debug_layer.get_children():
			child.free()
	var b: Dictionary = BIOMES[biome_index]
	var rock := str(b.get("rock", ""))
	var base_key := str(b["base"])
	var prio := _priority_map(b)

	for ly in view_h:
		for lx in view_w:
			var wx := view_origin.x + lx
			var wy := view_origin.y + ly
			if source_ids.has(base_key):
				underlay.set_cell(
					Vector2i(lx, ly), source_ids[base_key], Vector2i.ZERO,
					_flip_alt(base_key, wx, wy)
				)
			var t := _render_terrain_world(wx, wy)
			var best_key := _transition_choice(t, wx, wy, prio)
			if source_ids.has(best_key):
				var alt := 0
				if best_key == t:
					alt = _flip_alt(best_key, wx, wy)
				tilemap.set_cell(Vector2i(lx, ly), source_ids[best_key], Vector2i.ZERO, alt)
			elif source_ids.has(t):
				tilemap.set_cell(
					Vector2i(lx, ly), source_ids[t], Vector2i.ZERO,
					_flip_alt(t, wx, wy)
				)
			if t == rock and source_ids.has(t):
				rockmap.set_cell(
					Vector2i(lx, ly), source_ids[t], Vector2i.ZERO,
					_flip_alt(t, wx, wy)
				)

	sub_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_build_terrain_mask()
	_rebuild_structure_sprites()
	_rebuild_cliffs()
	_rebuild_decals()
	_rebuild_actors()
	_draw_fog()
	if debug_transitions:
		_draw_transition_debug()


func _tile_avg(key: String) -> Color:
	if terrain_color_cache.has(key):
		return terrain_color_cache[key]
	var path := "res://assets/tilesets/%s.png" % key
	var c := Color(0.3, 0.3, 0.3, 1.0)
	if ResourceLoader.exists(path):
		var img := (load(path) as Texture2D).get_image()
		if img != null:
			var r := 0.0
			var g := 0.0
			var b := 0.0
			var n := 0
			for y in range(0, img.get_height(), 4):
				for x in range(0, img.get_width(), 4):
					var px := img.get_pixel(x, y)
					if px.a > 0.2:
						r += px.r
						g += px.g
						b += px.b
						n += 1
			if n > 0:
				c = Color(r / n, g / n, b / n, 1.0)
	terrain_color_cache[key] = c
	return c


func _build_terrain_mask() -> void:
	# 4x sub-cell material field: one RGB texel per 4 screen-world pixels.
	# The shader uses the colour discontinuity to soften the seam between two
	# tile materials; the transition tiles still own the larger silhouette.
	var sub := 4
	var msize := Vector2i(view_w * sub, view_h * sub)
	if terrain_mask_img == null or terrain_mask_size != msize:
		terrain_mask_img = Image.create(msize.x, msize.y, false, Image.FORMAT_RGB8)
		terrain_mask_size = msize
		terrain_mask_tex = ImageTexture.create_from_image(terrain_mask_img)
	if height_mask_img == null or height_mask_size != msize:
		height_mask_img = Image.create(msize.x, msize.y, false, Image.FORMAT_RGB8)
		height_mask_size = msize
		height_mask_tex = ImageTexture.create_from_image(height_mask_img)
	var b: Dictionary = BIOMES[biome_index]
	for ly in view_h:
		for lx in view_w:
			var wx := view_origin.x + lx
			var wy := view_origin.y + ly
			var t := _render_terrain_world(wx, wy)
			var c := _tile_avg(t)
			terrain_mask_img.fill_rect(Rect2i(lx * sub, ly * sub, sub, sub), c)
			# Same field spacing as the material mask, but stores elevation so
			# the shader can shade slopes against one fixed top-left sun.
			var h := clampf(
				elevation.get_noise_2d(float(wx), float(wy)) * 0.82
				+ ridge_noise.get_noise_2d(float(wx), float(wy)) * 0.18,
				-1.0, 1.0
			)
			var hv := Color(h * 0.5 + 0.5, h * 0.5 + 0.5, h * 0.5 + 0.5, 1.0)
			height_mask_img.fill_rect(Rect2i(lx * sub, ly * sub, sub, sub), hv)
	terrain_mask_tex.update(terrain_mask_img)
	height_mask_tex.update(height_mask_img)
	if shader_mat != null:
		shader_mat.set_shader_parameter("terrain_mask", terrain_mask_tex)
		shader_mat.set_shader_parameter("terrain_mask_size", Vector2(msize))
		shader_mat.set_shader_parameter("terrain_mask_origin", Vector2(view_origin * TILE))
		shader_mat.set_shader_parameter("terrain_mask_span", float(view_w * TILE))
		shader_mat.set_shader_parameter("height_mask", height_mask_tex)
		shader_mat.set_shader_parameter("height_mask_size", Vector2(msize))


func _cell_quad(wx: int, wy: int) -> PackedVector2Array:
	var x0 := float(wx * TILE)
	var y0 := float(wy * TILE)
	return PackedVector2Array([
		_project(Vector2(x0, y0 + TILE * 0.5)),
		_project(Vector2(x0 + TILE * 0.5, y0 + TILE)),
		_project(Vector2(x0 + TILE, y0 + TILE * 0.5)),
		_project(Vector2(x0 + TILE * 0.5, y0)),
	])


func _rebuild_cliffs() -> void:
	if cliff_layer == null:
		return
	for child in cliff_layer.get_children():
		child.free()
	var b: Dictionary = BIOMES[biome_index]
	if not bool(b.get("cliffs", true)):
		return
	var rock := str(b.get("rock", ""))
	if rock == "" or not bool(feature_toggles.get("mountains", true)):
		return
	for ly in view_h:
		for lx in view_w:
			var wx := view_origin.x + lx
			var wy := view_origin.y + ly
			if _render_terrain_world(wx, wy) != rock:
				continue
			# Only the exposed south rim gets a wall. Filling every cell with a
			# face reads as a dark grid; edge-only faces read as a plateau.
			if _render_terrain_world(wx, wy + 1) == rock:
				continue
			var q := _cell_quad(wx, wy)
			if q.size() != 4:
				continue
			var drop := 6.0
			var face := Polygon2D.new()
			face.polygon = PackedVector2Array([
				q[0], q[1],
				q[1] + Vector2(0, drop), q[0] + Vector2(0, drop),
			])
			var face_path := "res://assets/tilesets/cliffs/face_%s.png" % str(b.get("id", "temperate"))
			if ResourceLoader.exists(face_path):
				face.texture = load(face_path) as Texture2D
				face.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
				face.uv = PackedVector2Array([
					Vector2(0, 0), Vector2(64, 0),
					Vector2(64, drop), Vector2(0, drop),
				])
				face.color = Color(1.0, 1.0, 1.0, 0.9)
			else:
				face.color = Color(0.025, 0.035, 0.03, 0.55)
			cliff_layer.add_child(face)
			var lip := Line2D.new()
			lip.points = PackedVector2Array([q[0], q[1]])
			lip.width = 1.5
			lip.default_color = Color(0.12, 0.14, 0.10, 0.72)
			cliff_layer.add_child(lip)

func _priority_map(b: Dictionary) -> Dictionary:
	var prio := {}
	for field in ["base", "base_alt"]:
		var base_tile := str(b.get(field, ""))
		if base_tile != "":
			prio[base_tile] = 1
	for variant_key in b.get("base_variants", []):
		var vk := str(variant_key)
		if vk != "":
			prio[vk] = 1
	for field in ["detail", "detail_alt", "detail_alt2", "detail_alt3"]:
		var detail_tile := str(b.get(field, ""))
		if detail_tile != "":
			prio[detail_tile] = 2
	for field in ["rock", "rock_alt"]:
		var rock_tile := str(b.get(field, ""))
		if rock_tile != "":
			prio[rock_tile] = 3
	var shore_tile := str(b.get("shore", ""))
	if shore_tile != "":
		prio[shore_tile] = 4
	var water_tile := str(b.get("water", ""))
	if water_tile != "" and water_tile != str(b["base"]):
		prio[water_tile] = 5
	# Every water material must outrank the land materials when the renderer
	# picks which neighbour transition to show. Ocean's open water is
	# `base`/`detail` rather than `water`, so `ocean/water_shallow` sat at the
	# base priority (1) and lost single-corner cells to the beach ring (3):
	# 47 of 181 ocean corner cells fell back to right-angle tiles even though
	# the 45-degree art existed. With the water priority they resolve.
	for water_key in BLOCKED:
		prio[water_key] = 5
	return prio


func _transition_key(t: String, n: String, dir: String) -> String:
	var pair_key := t + "|" + n
	if not transition_pairs.has(pair_key):
		return ""
	var info: Dictionary = transition_pairs[pair_key]
	var side := dir
	if info["a"] != n:
		side = _opposite(dir)
	var key: String = info["a"] + "|" + info["b"] + "|" + side
	if source_ids.has(key):
		return key
	return ""


func _opposite(dir: String) -> String:
	match dir:
		"east":
			return "west"
		"west":
			return "east"
		"south":
			return "north"
		"north":
			return "south"
	return dir


func _transition_choice(t: String, wx: int, wy: int, prio: Dictionary) -> String:
	"""Pick the tile that best matches all eight neighbours.

	Priority still decides which material wins when a cell touches several
	biome materials; the pattern score only breaks ties between equally
	important neighbours.
	"""
	var neighbours: Array[Vector2i] = []
	neighbours.append_array(EDGE_DIRS)
	neighbours.append_array(CORNER_DIRS)
	var seen := {}
	var best_key := t
	var best_prio := -1
	var best_score := -1
	for d in neighbours:
		var n := _render_terrain_world(wx + d.x, wy + d.y)
		if n == t or seen.has(n):
			continue
		seen[n] = true
		var pair_key := t + "|" + n
		if not transition_pairs.has(pair_key):
			continue
		var info: Dictionary = transition_pairs[pair_key]
		var data := _pattern_data(t, n, wx, wy, info)
		var key := str(data.get("key", ""))
		if key == "":
			continue
		var p := int(prio.get(n, 0))
		var s := int(data.get("score", 0))
		if p > best_prio or (p == best_prio and s > best_score):
			best_prio = p
			best_score = s
			best_key = key
	return best_key


func _pattern_data(t: String, n: String, wx: int, wy: int, info: Dictionary) -> Dictionary:
	"""Return the best extra/straight tile for one neighbour material.

	Edges are N/E/S/W, corners are NW/NE/SE/SW. ``n`` is the foreign material;
	``t`` is the cell material. The score is used only to compare patterns for
	the same material at the same priority.
	"""
	var edges: Array[bool] = [false, false, false, false]
	var corners: Array[bool] = [false, false, false, false]
	var edge_count := 0
	var corner_count := 0
	for i in range(4):
		edges[i] = _render_terrain_world(
			wx + EDGE_DIRS[i].x, wy + EDGE_DIRS[i].y
		) == n
		if edges[i]:
			edge_count += 1
	for i in range(4):
		corners[i] = _render_terrain_world(
			wx + CORNER_DIRS[i].x, wy + CORNER_DIRS[i].y
		) == n
		if corners[i]:
			corner_count += 1

	var score := edge_count * 2 + corner_count
	var key := ""
	if edge_count == 0:
		if corner_count == 1:
			var c := corners.find(true)
			key = _diagonal_key(info, n, CORNER_NAMES[c])
			if key == "":
				key = _extra_key(info, n, _foreign_prefix(info, n), CORNER_NAMES[c])
		elif corner_count == 2:
			var implied_edge := -1
			if corners[0] and corners[1]:
				implied_edge = 0
			elif corners[1] and corners[2]:
				implied_edge = 1
			elif corners[2] and corners[3]:
				implied_edge = 2
			elif corners[3] and corners[0]:
				implied_edge = 3
			if implied_edge >= 0:
				key = _transition_key(t, n, EDGE_NAMES[implied_edge])
			else:
				var c := corners.find(true)
				key = _extra_key(
					info, n, _foreign_prefix(info, n), CORNER_NAMES[c]
				)
		elif corner_count == 3:
			var c := corners.find(false)
			key = _extra_key(info, n, _cell_prefix(info, n), CORNER_NAMES[c])
	elif edge_count == 1:
		var e := edges.find(true)
		key = _transition_key(t, n, EDGE_NAMES[e])
	elif edge_count == 2:
		var opposite := (edges[0] and edges[2]) or (edges[1] and edges[3])
		if opposite:
			var axis := "ns" if edges[0] and edges[2] else "ew"
			key = _stripe_key(info, n, axis)
			if key == "":
				var e := edges.find(true)
				key = _transition_key(t, n, EDGE_NAMES[e])
		else:
			var c := -1
			if edges[0] and edges[1]:
				c = 1
			elif edges[1] and edges[2]:
				c = 2
			elif edges[2] and edges[3]:
				c = 3
			elif edges[3] and edges[0]:
				c = 0
			if c >= 0:
				key = _extra_key(info, n, _foreign_prefix(info, n), CORNER_NAMES[c])
	elif edge_count == 3:
		var missing := edges.find(false)
		if missing >= 0:
			var c1 := -1
			var c2 := -1
			match missing:
				0:
					c1 = 0
					c2 = 1
				1:
					c1 = 1
					c2 = 2
				2:
					c1 = 2
					c2 = 3
				3:
					c1 = 3
					c2 = 0
			var c := c1
			if corners[c1] and not corners[c2]:
				c = c2
			key = _extra_key(info, n, _cell_prefix(info, n), CORNER_NAMES[c])
	return {"key": key, "score": score}


func _diagonal_key(info: Dictionary, n: String, corner: String) -> String:
	# `info` is shared for both orderings of a pair, so a water-first pair
	# (`ocean/water_shallow` + `ocean/reef`) must also try the reversed key.
	var a := str(info["a"])
	var b := str(info["b"])
	if n == b:
		var key := "diag|" + a + "|" + b + "|" + corner
		if source_ids.has(key):
			return key
	elif n == a:
		var reverse := "diag|" + b + "|" + a + "|" + corner
		if source_ids.has(reverse):
			return reverse
	return ""


func _extra_key(info: Dictionary, n: String, prefix: String, corner: String) -> String:
	var key := str(info["a"]) + "|" + str(info["b"]) + "|" + prefix + "_" + corner
	if source_ids.has(key):
		return key
	return ""


func _stripe_key(info: Dictionary, n: String, axis: String) -> String:
	var a := str(info["a"])
	var b := str(info["b"])
	var key := ""
	if n == b:
		key = a + "|" + b + "|stripe_" + axis
	elif n == a:
		key = b + "|" + a + "|stripe_" + axis
	else:
		return ""
	if source_ids.has(key):
		return key
	return ""


func _cell_prefix(info: Dictionary, n: String) -> String:
	# inner_* = the cell material owns a corner; outer_* = the neighbour does.
	return "inner" if n == str(info["b"]) else "outer"


func _foreign_prefix(info: Dictionary, n: String) -> String:
	return "outer" if n == str(info["b"]) else "inner"


func _in_view(gx: int, gy: int, w: int = 1, h: int = 1) -> bool:
	"""Only draw features whose footprint lies inside the rendered window.

	The ground is a 20x16 SubViewport window. Anything outside it would be
	projected onto the empty border, so structures, props and markers must be
	culled here rather than by the shader.
	"""
	return (
		gx >= view_origin.x
		and gy >= view_origin.y
		and gx + w <= view_origin.x + view_w
		and gy + h <= view_origin.y + view_h
	)


func _transition_kind(key: String, base_key: String) -> String:
	if key == base_key:
		return "base"
	if key.contains("diag|"):
		return "diag"
	if key.contains("stripe_"):
		return "stripe"
	if key.contains("|outer_"):
		return "outer"
	if key.contains("|inner_"):
		return "inner"
	if key.ends_with("north") or key.ends_with("east") or key.ends_with("south") or key.ends_with("west"):
		return "straight"
	return "other"


func _draw_transition_debug() -> void:
	if debug_layer == null:
		return
	for child in debug_layer.get_children():
		child.free()
	var b: Dictionary = BIOMES[biome_index]
	var colors := {
		"straight": Color(0.10, 0.35, 1.0, 0.70),
		"outer": Color(1.0, 0.05, 0.05, 0.78),
		"inner": Color(0.05, 1.0, 0.25, 0.72),
		"stripe": Color(1.0, 0.85, 0.05, 0.70),
		"diag": Color(1.0, 0.10, 0.85, 0.76),
		"other": Color(1.0, 1.0, 1.0, 0.65),
	}
	var counts := {}
	for ly in view_h:
		for lx in view_w:
			var wx := view_origin.x + lx
			var wy := view_origin.y + ly
			var t := _render_terrain_world(wx, wy)
			var prio := _priority_map(b)
			var key := _transition_choice(t, wx, wy, prio)
			# Compare against the cell's own material, not the biome base:
			# water/sand/rock cells are valid bases too, and treating every
			# non-grass cell as a transition painted the whole board.
			var kind := _transition_kind(key, t)
			counts[kind] = int(counts.get(kind, 0)) + 1
			if kind == "base":
				continue
			var q := _cell_quad(wx, wy)
			if q.size() != 4:
				continue
			var poly := Polygon2D.new()
			poly.polygon = q
			poly.color = colors.get(kind, colors["other"])
			debug_layer.add_child(poly)
	print("TRANSDEBUG ", counts)


const DECAL_SHAPES := ["pebbles", "crack", "tuft", "bush", "shards", "flakes"]


func _decal_biome() -> String:
	match str(BIOMES[biome_index].get("id", "")):
		"temperate":
			return "temperate"
		"arid", "iron":
			return "arid"
		"volcanic", "sulfur", "obsidian":
			return "volcanic"
		"cryo", "ammonia", "methane":
			return "cryo"
		"ocean":
			return "ocean"
		"barren", "carbon":
			return "barren"
	return ""


func _load_decal_textures(biome_id: String) -> Array:
	if decal_cache.has(biome_id):
		return decal_cache[biome_id]
	if decal_manifest.is_empty():
		var manifest_path := "res://assets/tilesets/decals/manifest.json"
		if FileAccess.file_exists(manifest_path):
			var parsed: Variant = JSON.parse_string(
				FileAccess.get_file_as_string(manifest_path)
			)
			if parsed is Dictionary:
				decal_manifest = parsed
	var out: Array = []
	var files: Array = []
	var biomes: Dictionary = decal_manifest.get("biomes", {})
	if biomes.has(biome_id):
		files = biomes[biome_id].get("files", [])
	if not files.is_empty():
		# Honour the art manifest's per-biome allow-list instead of loading
		# every decal shape into every biome.
		for rel in files:
			var path := "res://assets/tilesets/decals/%s" % str(rel)
			if ResourceLoader.exists(path):
				out.append(load(path) as Texture2D)
	else:
		for shape in DECAL_SHAPES:
			for variant in ["a", "b"]:
				var path := "res://assets/tilesets/decals/%s/%s_%s.png" % [biome_id, shape, variant]
				if ResourceLoader.exists(path):
					out.append(load(path) as Texture2D)
	decal_cache[biome_id] = out
	return out


func _decal_hash(wx: int, wy: int, salt: int) -> int:
	return absi(int(wx) * 73856093 ^ int(wy) * 19349663 ^ seed_value * 83492791 ^ salt)


func _rebuild_decals() -> void:
	if decal_layer == null or chunks.is_empty():
		return
	for child in decal_layer.get_children():
		child.free()
	# F7 already hides props; tie decals to the same readability toggle so a
	# dense board can be stripped back without a second key.
	if not bool(feature_toggles.get("props", true)):
		return
	var biome_id := _decal_biome()
	if biome_id == "":
		return
	var textures := _load_decal_textures(biome_id)
	if textures.is_empty():
		return
	var b: Dictionary = BIOMES[biome_index]
	var base_keys: Array = [str(b["base"])]
	for v in b.get("base_variants", []):
		if not base_keys.has(str(v)):
			base_keys.append(str(v))

	var occupied := {}
	for coord in chunks:
		for s in chunks[coord].get("structures", []):
			for y in range(int(s["gy"]), int(s["gy"]) + int(s["h"])):
				for x in range(int(s["gx"]), int(s["gx"]) + int(s["w"])):
					occupied[Vector2i(x, y)] = true

	var center := _world_to_chunk(player_cell)
	for cy in range(center.y - 2, center.y + 3):
		for cx in range(center.x - 2, center.x + 3):
			var coord := Vector2i(cx, cy)
			if not chunks.has(coord):
				continue
			var data: Dictionary = chunks[coord]
			var arr: Array = data["terrain"]
			for ly in CHUNK:
				for lx in CHUNK:
					var wx := coord.x * CHUNK + lx
					var wy := coord.y * CHUNK + ly
					if not _in_view(wx, wy) or occupied.has(Vector2i(wx, wy)):
						continue
					if objectives.has(Vector2i(wx, wy)):
						continue
					if not base_keys.has(str(arr[ly * CHUNK + lx])):
						continue
					var h := _decal_hash(wx, wy, 6103)
					# Candidate rate × the low-frequency cluster gate controls
					# effective coverage (inspector: Decals group).
					if float(h % 10000) / 10000.0 > decal_density:
						continue
					if decal_noise.get_noise_2d(float(wx), float(wy)) < decal_cluster_threshold:
						continue
					var tex: Texture2D = textures[h % textures.size()]
					var sprite := Sprite2D.new()
					sprite.texture = tex
					sprite.centered = true
					sprite.position = _project(
						Vector2((float(wx) + 0.5) * TILE, (float(wy) + 0.5) * TILE)
					)
					sprite.position += Vector2(
						float((h / 7) % 21) - 10.0,
						float((h / 147) % 21) - 10.0
					)
					var s := lerpf(
						decal_scale_min,
						decal_scale_max,
						float((h / 11) % 9) / 8.0
					)
					sprite.scale = Vector2(s, s)
					var shape := str(DECAL_SHAPES[(h / 13) % DECAL_SHAPES.size()])
					if shape == "crack" or shape == "shards":
						sprite.rotation = float((h / 17) % 4) * PI * 0.5
					var v := 0.97 + float((h / 19) % 7) / 100.0
					sprite.modulate = Color(v, v, v, decal_alpha)
					decal_layer.add_child(sprite)


func _rebuild_structure_sprites() -> void:
	if structure_layer == null or chunks.is_empty():
		return
	for child in structure_layer.get_children():
		child.free()
	if occlusion_layer != null:
		for child in occlusion_layer.get_children():
			child.free()
	var center := _world_to_chunk(player_cell)
	for cy in range(center.y - 2, center.y + 3):
		for cx in range(center.x - 2, center.x + 3):
			var coord := Vector2i(cx, cy)
			if not chunks.has(coord):
				continue
			var data: Dictionary = chunks[coord]
			for s in data["structures"]:
				if _in_view(int(s["gx"]), int(s["gy"]), int(s["w"]), int(s["h"])):
					_add_structure_sprite(s)
					_add_occlusion(s)
			for p in data.get("props", []):
				if _in_view(int(p["gx"]), int(p["gy"])):
					_add_prop_sprite(p)


func _texture_bounds(tex: Texture2D) -> Rect2i:
	"""Alpha bounding box in texture pixels, cached per texture.

	Diffusion structures are centred in a square canvas, so several have
	transparent rows below the visible base. Anchoring by the full texture
	bottom leaves those structures hovering above the tile.
	"""
	var key := tex.resource_path
	if key != "" and _tex_bounds.has(key):
		return _tex_bounds[key]
	var full := Rect2i(0, 0, tex.get_width(), tex.get_height())
	var img := tex.get_image()
	var bounds := full
	if img != null:
		var used := img.get_used_rect()
		if used.size.x > 0 and used.size.y > 0:
			bounds = used
	if key != "":
		_tex_bounds[key] = bounds
	return bounds


func _load_piece_sets() -> Dictionary:
	if not piece_sets.is_empty():
		return piece_sets
	var path := "res://assets/tilesets/structures/pieces/manifest.json"
	if not FileAccess.file_exists(path):
		return piece_sets
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data is Dictionary:
		piece_sets = data.get("sets", {})
	return piece_sets


func _structure_visibility(cell: Vector2i, screen: Vector2) -> float:
	"""Match structures to the terrain's circular/edge grade.

	Fog itself is a screen-space veil above the structure layer; this handles
	the shader-only circular focus and the rectangular sector edge fade. The
	cell argument is kept for future per-cell fades.
	"""
	var vp := get_viewport_rect().size
	var alpha := 1.0
	if circle_view:
		var disc := (screen / vp - Vector2(0.5, 0.5)) * Vector2(vp.x / vp.y, 1.0)
		var dist := disc.length()
		var focus := 1.0 - smoothstep(
			circle_radius - circle_soft, circle_radius + circle_soft, dist
		)
		var outside := 1.0 - smoothstep(
			circle_radius + circle_soft, circle_outer, dist
		)
		alpha *= lerpf(0.20, 1.0, clampf(focus * outside, 0.0, 1.0))
	else:
		var edge := minf(minf(screen.x, screen.y), minf(vp.x - screen.x, vp.y - screen.y))
		alpha *= smoothstep(0.0, 46.0, edge)
	return clampf(alpha, 0.10, 1.0)


func _add_piece_sprites(
	info: Dictionary, gx: int, gy: int, w: int, h: int, anchor_screen: Vector2
) -> bool:
	var sets := _load_piece_sets()
	var set_name := str(info.get("pieces", ""))
	if not sets.has(set_name):
		return false
	var pieces: Array = sets[set_name].get("pieces", [])
	if pieces.is_empty():
		return false
	var unit := float(sets[set_name].get("unit_px", TILE))
	# The assembled sheet is a screen-space 4x4 block; draw each cut piece at
	# its own screen offset so the joins stay pixel-exact. z is derived from
	# the piece's bottom row, letting actors pass in front of the south face.
	var top_left := anchor_screen - Vector2(w * unit * map_scale * 0.5, h * unit * map_scale)
	var dim := _structure_visibility(
		Vector2i(gx + w / 2, gy + h / 2), anchor_screen
	)
	for p in pieces:
		var tile: Array = p.get("tile", [0, 0])
		var col := int(tile[0])
		var row := int(tile[1])
		var tex := load("res://assets/tilesets/structures/" + str(p["path"])) as Texture2D
		if tex == null:
			continue
		var sprite := Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = top_left + Vector2(col, row) * unit * map_scale
		sprite.scale = Vector2(map_scale, map_scale)
		sprite.modulate = Color(1.0, 1.0, 1.0, dim)
		sprite.z_index = min(int(anchor_screen.y - float(h - 1 - row) * unit * map_scale), 940)
		structure_layer.add_child(sprite)
	return true


func _load_structure_variants() -> void:
	structure_variants.clear()
	var path := "res://assets/tilesets/structures/variants/manifest.json"
	if not FileAccess.file_exists(path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return
	var keys: Dictionary = parsed.get("keys", {})
	for key in keys:
		var paths: Array = []
		for entry in keys[key]:
			if entry is Dictionary and str(entry.get("file", "")) != "":
				paths.append(str(entry["file"]))
		if not paths.is_empty():
			structure_variants[str(key)] = paths


func _add_structure_sprite(s: Dictionary) -> void:
	var info: Dictionary = STRUCTURES[s["key"]]
	if str(s["key"]) == "volcano" and OS.get_cmdline_args().has("--dump-structures"):
		print("VOLCANO gx=", s["gx"], " gy=", s["gy"], " w=", s["w"], " player=", player_cell)
	var gx: int = s["gx"]
	var gy: int = s["gy"]
	var tex_path := str(info["path"])
	var by_biome: Dictionary = info.get("path_by_biome", {})
	if not by_biome.is_empty():
		var biome_id := str(BIOMES[biome_index]["id"])
		tex_path = str(by_biome.get(biome_id, tex_path))
	var variant_paths: Array = structure_variants.get(str(s["key"]), [])
	if not variant_paths.is_empty():
		var vi := _decal_hash(gx, gy, 0x51a7) % variant_paths.size()
		tex_path = str(variant_paths[vi])
	var tex := load(tex_path) as Texture2D
	if tex == null:
		return
	var w: int = s["w"]
	var h: int = s["h"]
	var is_ground := bool(info.get("ground", false))
	# Upright props stand on the footprint's south edge; ground decals such as
	# craters sit in the centre of the footprint. Anchoring both by the visible
	# alpha bbox keeps transparent padding from making them hover.
	var anchor_world := Vector2(
		(gx + w * 0.5) * TILE,
		(gy + (0.5 if is_ground else 1.0) * h) * TILE
	)
	var anchor_screen := _project(anchor_world)
	var bounds := _texture_bounds(tex)
	var dim := _structure_visibility(
		Vector2i(gx + w / 2, gy + h / 2), anchor_screen
	)
	var sprite_boost := float(info.get("sprite_scale", 1.0))
	var shadow_rx := w * TILE * map_scale * (0.46 if is_ground else 0.62) * sprite_boost
	var shadow_ry := w * TILE * map_scale * (0.12 if is_ground else 0.13) * sprite_boost
	var shadow := Polygon2D.new()
	# An ellipse under every structure reads as a pasted round plinth. Break the
	# rim with two low-frequency harmonics so the contact patch looks like soil
	# that pooled around an uneven base.
	shadow.polygon = _contact_shadow_points(
		Vector2.ZERO, shadow_rx, shadow_ry,
		hash(Vector2i(roundi(anchor_screen.x), roundi(anchor_screen.y)))
	)
	shadow.color = Color(0.0, 0.0, 0.0, (0.20 if is_ground else 0.19) * dim)
	shadow.position = anchor_screen + Vector2(0.0, -shadow_ry * 0.55)
	shadow.z_index = min(int(anchor_screen.y) - 1, 939)
	structure_layer.add_child(shadow)

	if _add_piece_sprites(info, gx, gy, w, h, anchor_screen):
		return

	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	var fit := Vector2.ONE
	if is_ground and tex.get_width() > 0 and tex.get_height() > 0:
		# Ground decals are authored at their native footprint scale; a smaller
		# texture (e.g. the 64px crater) is stretched to fill its footprint.
		fit = Vector2(
			float(w * TILE) / tex.get_width(),
			float(h * TILE) / tex.get_height()
		)
	var extra_scale := float(info.get("sprite_scale", 1.0)) * float(s.get("scale_jitter", 1.0))
	var tint: Color = s.get("tint", Color.WHITE)
	sprite.modulate = Color(tint.r, tint.g, tint.b, tint.a * dim)
	sprite.scale = Vector2(
		map_scale * fit.x * extra_scale,
		map_scale * fit.y * (tilt if is_ground else 1.0) * extra_scale
	)
	var bbox_center := Vector2(
		bounds.position.x + bounds.size.x * 0.5,
		bounds.position.y + (bounds.size.y * (0.5 if is_ground else 1.0))
	)
	sprite.position = anchor_screen - bbox_center * sprite.scale
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = min(int(anchor_screen.y), 940)
	structure_layer.add_child(sprite)


func _add_occlusion(s: Dictionary) -> void:
	"""Darken the row immediately north of a tall structure.

	A full line-of-sight system would be overkill for a terrain viewer. The
	readable rule is: the cell behind a ridge is hidden. Drawing the veil above
	the actor layer means the lander can actually disappear behind a mountain;
	F6 toggles it off for clarity.
	"""
	if occlusion_layer == null or not bool(feature_toggles["occlusion"]):
		return
	var b: Dictionary = BIOMES[biome_index]
	if not bool(b.get("occlusion", true)):
		return
	var info: Dictionary = STRUCTURES[s["key"]]
	if not bool(info.get("occludes", false)):
		return
	var gx: int = s["gx"]
	var gy: int = s["gy"]
	var w: int = s["w"]
	var tex := _occlusion_texture()
	for x in range(gx, gx + w):
		var cell := Vector2i(x, gy - 1)
		if not _in_view(cell.x, cell.y, 1, 1):
			continue
		var corners := PackedVector2Array([
			_project(Vector2(cell.x * TILE, cell.y * TILE)),
			_project(Vector2((cell.x + 1) * TILE, cell.y * TILE)),
			_project(Vector2((cell.x + 1) * TILE, (cell.y + 1) * TILE)),
			_project(Vector2(cell.x * TILE, (cell.y + 1) * TILE)),
		])
		var lo := corners[0]
		var hi := corners[0]
		for p in corners:
			lo.x = minf(lo.x, p.x)
			lo.y = minf(lo.y, p.y)
			hi.x = maxf(hi.x, p.x)
			hi.y = maxf(hi.y, p.y)
		var fog := Sprite2D.new()
		fog.texture = tex
		fog.centered = true
		fog.position = (lo + hi) * 0.5
		fog.scale = Vector2(
			(hi.x - lo.x) / float(tex.get_width()) * 1.10,
			(hi.y - lo.y) / float(tex.get_height()) * 1.10
		)
		fog.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		occlusion_layer.add_child(fog)


func _occlusion_texture() -> Texture2D:
	if occlusion_tex != null:
		return occlusion_tex
	var gradient := Gradient.new()
	# Read as a haze over the hidden cells, not three black blobs. The veil is
	# an occlusion cue, not a shadow: at 0.94 alpha each radial sprite showed as
	# a distinct dark oval floating behind tall structures.
	gradient.offsets = PackedFloat32Array([0.0, 0.68, 1.0])
	gradient.colors = PackedColorArray([
		Color(0.020, 0.028, 0.042, 0.30),
		Color(0.024, 0.032, 0.046, 0.24),
		Color(0.024, 0.032, 0.046, 0.0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 64
	tex.height = 64
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 1.0)
	occlusion_tex = tex
	return tex


func _prop_is_usable(tex: Texture2D) -> bool:
	"""Reject prop sprites that still have an opaque sheet background.

	Props are authored as single objects on a transparent background. A sprite
	that still carries an opaque sheet background would drop a solid beige
	square on the map, which is worse than omitting the prop.
	"""
	var key := tex.resource_path
	if key != "" and _prop_ok.has(key):
		return bool(_prop_ok[key])
	var ok := false
	var img := tex.get_image()
	if img != null:
		var total := img.get_width() * img.get_height()
		if total > 0:
			var data := img.get_data()
			var clear := 0
			for i in range(3, data.size(), 4):
				if data[i] < 8:
					clear += 1
			ok = float(clear) / float(total) >= 0.08
	if key != "":
		_prop_ok[key] = ok
	return ok


func _add_prop_sprite(p: Dictionary) -> void:
	var tex := load("res://assets/props/%s.png" % str(p["key"])) as Texture2D
	if tex == null or not _prop_is_usable(tex):
		return
	var base_world := Vector2((int(p["gx"]) + 0.5) * TILE, (int(p["gy"]) + 1.0) * TILE)
	var base_screen := _project(base_world)
	var bounds := _texture_bounds(tex)
	var dim := _structure_visibility(
		Vector2i(int(p["gx"]), int(p["gy"])), base_screen
	)
	var scale: float = map_scale * float(p.get("scale", 0.72))

	var prop_shadow_ry := TILE * map_scale * 0.09
	var shadow := Polygon2D.new()
	shadow.polygon = _contact_shadow_points(
		Vector2.ZERO, TILE * map_scale * 0.30, prop_shadow_ry,
		hash(Vector2i(roundi(base_screen.x), roundi(base_screen.y)))
	)
	shadow.color = Color(0.0, 0.0, 0.0, 0.17 * dim)
	shadow.position = base_screen + Vector2(0.0, -prop_shadow_ry * 0.5)
	shadow.z_index = min(int(base_screen.y) - 1, 939)
	structure_layer.add_child(shadow)

	var sprite := Sprite2D.new()
	sprite.texture = tex
	sprite.centered = false
	sprite.scale = Vector2(scale, scale)
	sprite.flip_h = bool(p.get("flip", false))
	sprite.position = base_screen - Vector2(
		(bounds.position.x + bounds.size.x * 0.5) * scale,
		(bounds.position.y + bounds.size.y) * scale
	)
	sprite.modulate = Color(1.0, 1.0, 1.0, dim)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = min(int(base_screen.y), 940)
	structure_layer.add_child(sprite)


func _rebuild_actors() -> void:
	if actor_layer == null or overlay_layer == null or chunks.is_empty():
		return
	for child in actor_layer.get_children():
		child.free()
	for child in overlay_layer.get_children():
		child.free()

	# Tile selection under the lander.
	var corners := PackedVector2Array([
		_project(Vector2(player_cell.x * TILE, player_cell.y * TILE)),
		_project(Vector2((player_cell.x + 1) * TILE, player_cell.y * TILE)),
		_project(Vector2((player_cell.x + 1) * TILE, (player_cell.y + 1) * TILE)),
		_project(Vector2(player_cell.x * TILE, (player_cell.y + 1) * TILE)),
	])
	var tile_fill := Polygon2D.new()
	tile_fill.polygon = corners
	tile_fill.color = Color(0.40, 1.0, 0.90, 0.10)
	overlay_layer.add_child(tile_fill)
	var tile_line := Line2D.new()
	tile_line.points = corners
	tile_line.closed = true
	tile_line.width = 1.5
	tile_line.default_color = Color(0.50, 1.0, 0.90, 0.9)
	overlay_layer.add_child(tile_line)

	# Hazard telegraph for the next turn: one diamond per affected cell.
	if hazard_kind != "":
		for oy in range(3):
			for ox in range(3):
				if not _in_view(hazard_cell.x + ox, hazard_cell.y + oy):
					continue
				var cx := (hazard_cell.x + ox) * TILE
				var cy := (hazard_cell.y + oy) * TILE
				var hz := PackedVector2Array([
					_project(Vector2(cx, cy)),
					_project(Vector2(cx + TILE, cy)),
					_project(Vector2(cx + TILE, cy + TILE)),
					_project(Vector2(cx, cy + TILE)),
				])
				var hz_fill := Polygon2D.new()
				hz_fill.polygon = hz
				hz_fill.color = Color(hazard_color.r, hazard_color.g, hazard_color.b, 0.09)
				overlay_layer.add_child(hz_fill)
				var hz_line := Line2D.new()
				hz_line.points = hz
				hz_line.closed = true
				hz_line.width = 1.0
				hz_line.default_color = Color(
					hazard_color.r, hazard_color.g, hazard_color.b, 0.55
				)
				overlay_layer.add_child(hz_line)
				var hz_tw := hz_fill.create_tween().set_loops()
				hz_tw.tween_property(hz_fill, "modulate:a", 0.45, 0.75)
				hz_tw.tween_property(hz_fill, "modulate:a", 1.0, 0.75)

	# Lander.
	var player_screen := _project(Vector2(
		(player_cell.x + 0.5) * TILE,
		(player_cell.y + 0.5) * TILE
	))
	player_shadow = Polygon2D.new()
	player_shadow.polygon = _ellipse_points(
		Vector2.ZERO, TILE * map_scale * 0.38, TILE * map_scale * 0.11
	)
	player_shadow.color = Color(0.0, 0.0, 0.0, 0.42)
	player_shadow.position = player_screen
	player_shadow.z_index = 949
	actor_layer.add_child(player_shadow)

	if player_tex != null:
		# The lander is a small vehicle, not a building: keep it clearly below
		# one tile wide so mountains and craters read as landscape-scale.
		var ps := map_scale * 0.82
		var pb := _texture_bounds(player_tex)
		player_sprite = Sprite2D.new()
		player_sprite.texture = player_tex
		player_sprite.centered = false
		player_sprite.scale = Vector2(ps, ps)
		player_sprite.position = player_screen - Vector2(
			(pb.position.x + pb.size.x * 0.5) * ps,
			(pb.position.y + pb.size.y) * ps
		)
		player_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		player_sprite.z_index = 950
		actor_layer.add_child(player_sprite)

	# Objective pickups: cyan data nodes, amber relay beacons.
	for i in range(objectives.size()):
		if collected[i]:
			continue
		var c := objectives[i]
		if not _in_view(c.x, c.y):
			continue
		var relay := objective_mode == "relay"
		var base_col := Color(1.0, 0.68, 0.24) if relay else Color(0.20, 1.0, 0.90)
		var pos := _project(Vector2((c.x + 0.5) * TILE, (c.y + 0.5) * TILE))
		var marker := Node2D.new()
		marker.position = pos
		# Map geometry is projected at map_scale, but markers are UI-scale
		# pickups. Keep them readable at the 640x360 logical resolution.
		marker.scale = Vector2(0.56, 0.56) if relay else Vector2(0.42, 0.42)
		var glow := Polygon2D.new()
		glow.polygon = _diamond_points(20.0)
		glow.color = Color(base_col.r, base_col.g, base_col.b, 0.30)
		marker.add_child(glow)
		var beam := Polygon2D.new()
		beam.polygon = PackedVector2Array([
			Vector2(-3, -30), Vector2(3, -30), Vector2(2, 0), Vector2(-2, 0)
		])
		beam.color = Color(base_col.r, base_col.g, base_col.b, 0.38)
		marker.add_child(beam)
		# A slow scanner diamond orbiting the pickup. The marker itself only
		# breathes; this adds the second motion that reads as "active".
		var halo := Node2D.new()
		var hline := Line2D.new()
		hline.points = _diamond_points(15.0)
		hline.closed = true
		hline.width = 1.0
		hline.default_color = Color(base_col.r, base_col.g, base_col.b, 0.50)
		halo.add_child(hline)
		marker.add_child(halo)
		var spin := halo.create_tween().set_loops()
		spin.tween_property(halo, "rotation", TAU, 5.5).from(0.0)
		var bp := beam.create_tween().set_loops()
		bp.tween_property(beam, "modulate:a", 0.45, 0.85).set_ease(Tween.EASE_IN_OUT)
		bp.tween_property(beam, "modulate:a", 1.0, 0.85).set_ease(Tween.EASE_IN_OUT)
		if relay and relay_tex != null:
			# VEGA's purpose-built relay beacon: tripod, mast and cyan lens.
			var beacon := Sprite2D.new()
			beacon.texture = relay_tex
			beacon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			beacon.position = Vector2(0, -21)
			beacon.scale = Vector2(0.52, 0.52)
			beacon.modulate = Color(1.0, 0.92, 0.72)
			marker.add_child(beacon)
		elif relay:
			# Fallback mast silhouette if the prop is missing.
			var mast := Line2D.new()
			mast.points = PackedVector2Array([Vector2(0, 4), Vector2(0, -16)])
			mast.width = 1.6
			mast.default_color = Color(base_col.r, base_col.g, base_col.b, 0.95)
			marker.add_child(mast)
			var dish := Polygon2D.new()
			dish.polygon = PackedVector2Array([
				Vector2(-7, -16), Vector2(7, -16), Vector2(4, -10), Vector2(-4, -10)
			])
			dish.color = Color(base_col.r, base_col.g, base_col.b, 0.95)
			marker.add_child(dish)
		if node_tex != null and not (relay and relay_tex != null):
			var icon := Sprite2D.new()
			icon.texture = node_tex
			icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			icon.scale = Vector2(0.40, 0.40)
			icon.modulate = Color(1.0, 0.86, 0.62) if relay else Color(0.72, 1.0, 1.0)
			marker.add_child(icon)
		elif not (relay and relay_tex != null):
			var core := Polygon2D.new()
			core.polygon = _diamond_points(12.0)
			core.color = base_col
			marker.add_child(core)
			var outline := Line2D.new()
			outline.points = _diamond_points(12.0)
			outline.closed = true
			outline.width = 1.4
			outline.default_color = Color(0.10, 0.06, 0.01) if relay else Color(0.02, 0.15, 0.15)
			marker.add_child(outline)
		actor_layer.add_child(marker)
		var pulse := marker.create_tween().set_loops()
		pulse.tween_property(marker, "modulate:a", 0.55, 0.85).set_delay(0.35)
		pulse.tween_property(marker, "modulate:a", 1.0, 0.85)


	# Optional caches: smaller than an objective, brighter than terrain. They
	# are route choices, so they deliberately sit away from the quota line.
	for i in range(data_caches.size()):
		if cache_taken[i]:
			continue
		var cc := data_caches[i]
		if not _in_view(cc.x, cc.y):
			continue
		var cpos := _project(Vector2((cc.x + 0.5) * TILE, (cc.y + 0.5) * TILE))
		var cm := Node2D.new()
		cm.position = cpos
		cm.scale = Vector2(0.32, 0.32)
		var cglow := Polygon2D.new()
		cglow.polygon = _diamond_points(19.0)
		cglow.color = Color(0.20, 1.0, 0.90, 0.22)
		cm.add_child(cglow)
		# Same visual family as a quota data node, one size down and without the
		# tall beam: an optional cache should read as data, not as a different
		# kind of pickup.
		if node_tex != null:
			var cicon := Sprite2D.new()
			cicon.texture = node_tex
			cicon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			cicon.scale = Vector2(0.27, 0.27)
			cicon.modulate = Color(0.72, 1.0, 1.0)
			cm.add_child(cicon)
		else:
			var ccore := Polygon2D.new()
			ccore.polygon = _diamond_points(8.0)
			ccore.color = Color(0.30, 1.0, 0.92, 0.95)
			cm.add_child(ccore)
		var cout := Line2D.new()
		cout.points = _diamond_points(9.0)
		cout.closed = true
		cout.width = 1.2
		cout.default_color = Color(0.02, 0.20, 0.18, 0.95)
		cm.add_child(cout)
		actor_layer.add_child(cm)
		var cpulse := cm.create_tween().set_loops()
		cpulse.tween_property(cm, "modulate:a", 0.55, 0.70).set_delay(0.20)
		cpulse.tween_property(cm, "modulate:a", 1.0, 0.90)


func _diamond_points(radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -radius), Vector2(radius, 0),
		Vector2(0, radius), Vector2(-radius, 0),
	])


func _contact_shadow_points(
	center: Vector2, rx: float, ry: float, seed_value: int
) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var phase := float(seed_value % 628) / 100.0
	for i in range(20):
		var a := TAU * float(i) / 20.0
		var rim := 1.0 + 0.10 * sin(3.0 * a + phase) + 0.06 * sin(5.0 * a - phase)
		pts.append(center + Vector2(cos(a) * rx * rim, sin(a) * ry * rim))
	return pts


func _ellipse_points(center: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in range(16):
		var a := TAU * float(i) / 16.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


func _animate_player(from_cell: Vector2i) -> void:
	if player_sprite == null or player_shadow == null:
		return
	if player_tween != null and player_tween.is_valid():
		player_tween.kill()
	var from_screen := _project(Vector2(
		(from_cell.x + 0.5) * TILE,
		(from_cell.y + 0.5) * TILE
	))
	var to_screen := _project(Vector2(
		(player_cell.x + 0.5) * TILE,
		(player_cell.y + 0.5) * TILE
	))
	var delta := from_screen - to_screen
	var sprite_target := player_sprite.position
	var shadow_target := player_shadow.position
	_move_puff(from_screen)
	player_sprite.position = sprite_target + delta
	player_shadow.position = shadow_target + delta
	player_tween = create_tween().set_parallel(true)
	player_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	player_tween.tween_property(player_sprite, "position", sprite_target, 0.16)
	player_tween.tween_property(player_shadow, "position", shadow_target, 0.16)


func _camera_world_layers() -> Array:
	return [cliff_layer, decal_layer, overlay_layer, structure_layer, occlusion_layer]


func _pan_camera(from_cell: Vector2i) -> void:
	if shader_mat == null:
		return
	var from_screen := _project(Vector2(
		(from_cell.x + 0.5) * TILE,
		(from_cell.y + 0.5) * TILE
	))
	var to_screen := _project(Vector2(
		(player_cell.x + 0.5) * TILE,
		(player_cell.y + 0.5) * TILE
	))
	if camera_tween != null and camera_tween.is_valid():
		camera_tween.kill()
	# The map was re-rendered around the new cell. Start the shader sample one
	# step behind, then slide the whole board under the lander instead of
	# snapping the window. One cell stays inside the rendered 20x16 window.
	var delta := from_screen - to_screen
	shader_mat.set_shader_parameter("camera_offset", delta)
	# Shift the world layers with the shader so terrain, structures and markers
	# pan together. The actor layer is deliberately left alone: the lander holds
	# the centre of the new view while the ground rolls under it.
	for layer in _camera_world_layers():
		if layer != null:
			layer.position = -delta
	camera_tween = create_tween().set_parallel(true)
	camera_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	camera_tween.tween_method(
		func(v: Vector2) -> void: shader_mat.set_shader_parameter("camera_offset", v),
		delta, Vector2.ZERO, 0.18
	)
	for layer in _camera_world_layers():
		if layer != null:
			camera_tween.tween_property(layer, "position", Vector2.ZERO, 0.18)


func _project(world: Vector2) -> Vector2:
	var vp := get_viewport_rect().size
	var local := world - Vector2(float(view_origin.x), float(view_origin.y)) * TILE
	var p := local - _view_px() * 0.5
	var screen := vp * 0.5
	match view_mode:
		0:
			return screen + Vector2(p.x * map_scale, p.y * map_scale * tilt)
		1:
			var u := (p.x - p.y) * 0.70710678
			var v := (p.x + p.y) * 0.70710678
			return screen + Vector2(u * map_scale, v * map_scale * tilt)
		_:
			return screen + p * map_scale


func _auto_exposure() -> float:
	# Tile luminance varies 66-179 across the atlas, so one hand-tuned exposure
	# per biome cannot keep every board readable (crystal field was the worst:
	# 0.62 exposure multiplied already-dark glass_ground by darkness).
	# Normalise the base tile toward a 0.62 mid-tone, then let the per-biome
	# constant act only as a restrained +-10% artistic trim.
	var b: Dictionary = BIOMES[biome_index]
	var base_key := str(b.get("base", ""))
	var luma := _tile_avg(base_key).get_luminance()
	var trim := clampf(float(b.get("exposure", 1.0)), 0.90, 1.10)
	var auto := clampf(0.62 / maxf(luma, 0.05), 0.75, 2.20)
	return auto * trim


func _apply_biome_tint() -> void:
	if shader_mat == null:
		return
	var b: Dictionary = BIOMES[biome_index]
	var c := Color(str(b.get("tint", "#ffffff")))
	shader_mat.set_shader_parameter("biome_tint", c)
	shader_mat.set_shader_parameter("biome_tint_strength", float(b.get("tint_strength", 0.0)))
	shader_mat.set_shader_parameter("exposure", _auto_exposure())
	# Gamma lift for the boards whose source tiles are genuinely dark (ash,
	# basalt, obsidian). It opens the shadows without flattening the highlight.
	var lift := 1.0
	match str(b.get("id", "")):
		"volcanic", "sulfur", "obsidian":
			lift = 0.72
		"barren", "iron", "carbon":
			lift = 0.88
	shader_mat.set_shader_parameter("lift", lift)
	shader_mat.set_shader_parameter("edge_mode", edge_mode)
	shader_mat.set_shader_parameter("relief", relief_enabled)


func _update_view() -> void:
	if display == null:
		return
	_apply_biome_tint()
	var vp := get_viewport_rect().size
	var target_w := float(_view_px().x)
	var target_h := float(_view_px().y)
	if view_mode == 0:
		target_h = float(_view_px().y) * tilt
	elif view_mode == 1:
		# The rendered window is _view_px(), not VIEW_TILES*TILE. A rotated
		# rectangle is (w+h)/sqrt(2) wide, then tilt-squashed vertically.
		target_w = float(_view_px().x + _view_px().y) * 0.70710678
		target_h = target_w * tilt
	# Fit both axes so fullscreen and unusual window aspect ratios keep the
	# same number of visible tiles instead of cropping the board vertically.
	map_scale = min(vp.x / target_w, vp.y / target_h) * zoom

	display.size = vp
	display.position = Vector2.ZERO
	if space_rect != null:
		space_rect.size = vp
		space_rect.position = Vector2.ZERO
	if space_mat != null:
		space_mat.set_shader_parameter("resolution", vp)
	shader_mat.set_shader_parameter("view_mode", view_mode)
	shader_mat.set_shader_parameter("map_scale", map_scale)
	shader_mat.set_shader_parameter("tilt", tilt)
	shader_mat.set_shader_parameter("screen_size", vp)
	shader_mat.set_shader_parameter("map_size", _view_px())
	shader_mat.set_shader_parameter("map_tiles", Vector2(view_w, view_h))
	shader_mat.set_shader_parameter("camera_center", _view_px() * 0.5)
	shader_mat.set_shader_parameter("camera_offset", Vector2.ZERO)
	shader_mat.set_shader_parameter("circle_view", 1 if circle_view else 0)
	shader_mat.set_shader_parameter("circle_radius", circle_radius)
	shader_mat.set_shader_parameter("circle_outer", circle_outer)
	shader_mat.set_shader_parameter("circle_soft", circle_soft)
	shader_mat.set_shader_parameter("show_grid", 1 if show_grid else 0)
	_rebuild_structure_sprites()
	_rebuild_actors()


func _draw_minimap() -> void:
	if minimap == null:
		return
	var sz := minimap.size
	var center := sz * 0.5
	var radius_px := minf(sz.x, sz.y) * 0.47
	minimap.draw_circle(center, radius_px, Color(0.025, 0.035, 0.050, 0.94))
	if mapped_chunks.is_empty():
		minimap.draw_arc(center, radius_px, 0.0, TAU, 64,
			Color(0.32, 0.45, 0.48, 0.75), 1.0, true)
		return

	var lo := mapped_lo
	var hi := mapped_hi
	lo.x = mini(lo.x, player_cell.x - 2)
	lo.y = mini(lo.y, player_cell.y - 2)
	hi.x = maxi(hi.x, player_cell.x + 2)
	hi.y = maxi(hi.y, player_cell.y + 2)
	var span := maxi(hi.x - lo.x, hi.y - lo.y)
	var world_center := Vector2(float(lo.x + hi.x) * 0.5, float(lo.y + hi.y) * 0.5)
	var step := (radius_px * 1.90) / float(maxi(span, 1))
	var b: Dictionary = BIOMES[biome_index]
	var water := str(b.get("water", ""))
	var shore := str(b.get("shore", ""))
	var rock := str(b.get("rock", ""))
	var land := Color(0.24, 0.34, 0.22, 0.96)
	match str(b.get("id", "")):
		"arid", "barren", "iron": land = Color(0.48, 0.40, 0.27, 0.96)
		"volcanic", "sulfur", "obsidian": land = Color(0.36, 0.24, 0.19, 0.96)
		"cryo", "ammonia": land = Color(0.56, 0.68, 0.73, 0.96)
		"crystal": land = Color(0.42, 0.34, 0.55, 0.96)
		"ocean": land = Color(0.33, 0.48, 0.35, 0.96)

	# Render the surveyed terrain into a small image and mask it by radius at
	# pixel resolution. Drawing one rectangle per cell left 64px chunk-shaped
	# bites out of the minimap edge; this gives the exact circular silhouette
	# the user asked for without a SubViewport or a shader pass.
	var map_px := 76
	if minimap_img == null:
		minimap_img = Image.create(map_px, map_px, false, Image.FORMAT_RGBA8)
	else:
		minimap_img.fill(Color(0, 0, 0, 0))
	var img_center := Vector2(map_px, map_px) * 0.5
	var img_radius := float(map_px) * 0.47
	for py in map_px:
		for px in map_px:
			var irel := Vector2(float(px) + 0.5, float(py) + 0.5) - img_center
			if irel.length() > img_radius:
				continue
			var world := world_center + irel / step
			var gx := int(floor(world.x))
			var gy := int(floor(world.y))
			var coord := Vector2i(floori(float(gx) / float(CHUNK)), floori(float(gy) / float(CHUNK)))
			if not mapped_chunks.has(coord):
				continue
			var data: Dictionary = mapped_chunks[coord]
			var arr: Array = data["terrain"]
			var lx := posmod(gx, CHUNK)
			var ly := posmod(gy, CHUNK)
			var raw := str(arr[ly * CHUNK + lx])
			var col := land
			if water != "" and (raw == water or raw.begins_with(water + "_")):
				col = Color(0.07, 0.24, 0.32, 0.96)
			elif shore != "" and raw == shore:
				col = Color(0.55, 0.47, 0.30, 0.96)
			elif rock != "" and raw == rock:
				col = Color(0.40, 0.43, 0.46, 0.96)
			minimap_img.set_pixel(px, py, col)
	if minimap_tex == null:
		minimap_tex = ImageTexture.create_from_image(minimap_img)
	else:
		minimap_tex.update(minimap_img)
	minimap.draw_texture_rect(
		minimap_tex,
		Rect2(center - Vector2(float(map_px), float(map_px)) * 0.5, Vector2(map_px, map_px)),
		false
	)

	for coord in mapped_chunks:
		var data: Dictionary = mapped_chunks[coord]
		for s in data["structures"]:
			var sx := int(s["gx"]) + int(s["w"]) * 0.5
			var sy := int(s["gy"]) + int(s["h"]) * 0.5
			var rel := (Vector2(float(sx), float(sy)) - world_center) * step
			if rel.length() > radius_px - 2.0:
				continue
			var sp := center + rel - Vector2(float(s["w"]), float(s["h"])) * step * 0.5
			minimap.draw_rect(
				Rect2(sp, Vector2(float(s["w"]), float(s["h"])) * step),
				Color(0.45, 0.50, 0.55, 0.90)
			)

	if hazard_kind != "" and hazard_cell.x != -999:
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				var rel := (Vector2(float(hazard_cell.x + ox), float(hazard_cell.y + oy)) - world_center) * step
				if rel.length() > radius_px - step:
					continue
				minimap.draw_rect(
					Rect2(center + rel - Vector2(step, step) * 0.5, Vector2(step, step)),
					Color(0.95, 0.25, 0.15, 0.32)
				)

	# Objectives are not clipped away: if an unscanned node lies beyond the
	# mapped bounds, pin it to the rim so the player always knows it exists.
	for i in range(objectives.size()):
		if collected[i]:
			continue
		var rel := (Vector2(objectives[i]) - world_center) * step
		var max_r := radius_px - 4.0
		if rel.length() > max_r:
			rel = rel.normalized() * max_r
		var op := center + rel
		var mark := PackedVector2Array([
			op + Vector2(0, -3), op + Vector2(3, 0),
			op + Vector2(0, 3), op + Vector2(-3, 0),
		])
		minimap.draw_colored_polygon(mark, Color(1.0, 0.82, 0.30, 0.98))

	var prel := (Vector2(player_cell) - world_center) * step
	var max_pr := radius_px - 3.0
	if prel.length() > max_pr:
		prel = prel.normalized() * max_pr
	var pp := center + prel
	minimap.draw_circle(pp, 2.4, Color(0.30, 0.95, 0.90, 1.0))
	minimap.draw_arc(center, radius_px, 0.0, TAU, 64,
		Color(0.32, 0.45, 0.48, 0.78), 1.0, true)


func _refresh_status() -> void:
	if info_label == null or status_label == null:
		return
	var b: Dictionary = BIOMES[biome_index]
	var life := str(b.get("life", "lifeless"))
	if life == "rare biosphere":
		life = "rare life"
	info_label.text = "%s\n%s  •  %s" % [planet_name, b["name"], life]
	status_label.text = "Turns %d   Data %d/%d   Hull %d" % [
		turns_left, data_collected, objectives.size(), hull
	]
	if hazard_kind != "":
		hazard_label.text = "Incoming: %s" % hazard_kind
		hazard_label.add_theme_color_override("font_color", hazard_color)
	else:
		hazard_label.text = ""
	if nav_label != null:
		nav_label.text = _nearest_objective_text()
	var names := ["3/4 tilt", "Isometric", "Top-down"]
	view_label.text = "seed %d • %s\n%s • %d chunks" % [
		seed_value, names[view_mode], archetype_name, chunks.size()
	]
	if message_label != null:
		message_label.visible = game_over
		message_label.text = message_text
	if debug_visible:
		_refresh_debug()
	if minimap != null:
		minimap.queue_redraw()


func _nearest_objective_text() -> String:
	var best := Vector2i.ZERO
	var best_dist := 1 << 30
	for i in range(objectives.size()):
		if collected[i]:
			continue
		var d := objectives[i] - player_cell
		var dist := d.x * d.x + d.y * d.y
		if dist < best_dist:
			best_dist = dist
			best = d
	if best_dist == 1 << 30:
		return "All data collected"
	var sx := float(best.x)
	var sy := float(best.y)
	# Convert board delta to the direction the player actually sees. Arrow keys
	# are screen-relative, so the compass is too.
	if view_mode == 0:
		sy *= tilt
	elif view_mode == 1:
		var u := sx - sy
		var v := (sx + sy) * tilt
		sx = u
		sy = v
	var angle := atan2(sy, sx)
	var idx := posmod(int(round(angle / (PI / 4.0))), 8)
	var dirs := ["E", "SE", "S", "SW", "W", "NW", "N", "NE"]
	return "Nearest data %d tiles %s" % [int(round(sqrt(float(best_dist)))), dirs[idx]]


func _refresh_debug() -> void:
	if debug_label == null:
		return
	var c := _world_to_chunk(player_cell)
	var structure_count := 0
	var prop_count := 0
	for coord in chunks:
		var data: Dictionary = chunks[coord]
		structure_count += data["structures"].size()
		prop_count += data.get("props", []).size()
	debug_label.text = (
		"seed %d   fps %d\ncell %d,%d   chunk %d,%d\norigin %d,%d   chunks %d\nstructures %d   props %d\nF4 mtn %s  F5 out %s  F6 sight %s  F7 props %s"
		% [
			seed_value, Engine.get_frames_per_second(),
			player_cell.x, player_cell.y, c.x, c.y,
			view_origin.x, view_origin.y, chunks.size(),
			structure_count, prop_count,
			"on" if bool(feature_toggles["mountains"]) else "off",
			"on" if bool(feature_toggles["outposts"]) else "off",
			"on" if bool(feature_toggles["occlusion"]) else "off",
			"on" if bool(feature_toggles["props"]) else "off",
		]
	)


func _on_new_pressed() -> void:
	_new_seed()


func _on_biome_pressed() -> void:
	biome_index = (biome_index + 1) % BIOMES.size()
	_generate()


func _on_view_pressed() -> void:
	view_mode = (view_mode + 1) % 3
	_update_view()
	_refresh_status()


func _on_grid_pressed() -> void:
	show_grid = not show_grid
	_update_view()
	_refresh_status()


func _on_same_pressed() -> void:
	_generate()


func _on_copy_seed() -> void:
	DisplayServer.clipboard_set(str(seed_value))
	view_label.text = "seed %d copied" % seed_value


func _on_dpad(dir: Vector2i) -> void:
	_try_move(_screen_to_grid(dir))


func _screen_to_grid(dir: Vector2i) -> Vector2i:
	"""Map a viewer-relative arrow to a board step.

	In the dimetric view the board is rotated 45 degrees, so screen-right is
	the grid diagonal (+1, -1) and screen-down is (+1, +1). This keeps the
	lander moving left/right/up/down relative to the player, not diagonally.
	"""
	if view_mode == 1:
		return Vector2i(dir.x + dir.y, -dir.x + dir.y)
	return dir


func _on_viewport_resized() -> void:
	# The viewport size settles one frame after a fullscreen/window change.
	_update_view.call_deferred()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return
	match key.keycode:
		KEY_R:
			_new_seed()
		KEY_B:
			biome_index = (biome_index + 1) % BIOMES.size()
			_generate()
		KEY_T:
			_generate()
		KEY_V:
			view_mode = (view_mode + 1) % 3
			_update_view()
			_refresh_status()
		KEY_G:
			show_grid = not show_grid
			_update_view()
			_refresh_status()
		KEY_C:
			_on_copy_seed()
		KEY_F3:
			debug_visible = not debug_visible
			if debug_label != null:
				debug_label.visible = debug_visible
			if debug_visible:
				_refresh_debug()
		KEY_H:
			ui_layer.visible = not ui_layer.visible
		KEY_F4:
			feature_toggles["mountains"] = not bool(feature_toggles["mountains"])
			_refresh_world()
		KEY_F5:
			feature_toggles["outposts"] = not bool(feature_toggles["outposts"])
			_refresh_world()
		KEY_F6:
			feature_toggles["occlusion"] = not bool(feature_toggles["occlusion"])
			_rebuild_structure_sprites()
			_refresh_status()
		KEY_F7:
			feature_toggles["props"] = not bool(feature_toggles["props"])
			_refresh_world()
		KEY_F9:
			debug_transitions = not debug_transitions
			_render_window()
		KEY_F10:
			_save_capture(CAPTURE_PATH)
		KEY_F11:
			if not OS.has_feature("web"):
				var mode := DisplayServer.window_get_mode()
				if mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				else:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				_on_viewport_resized()
		KEY_UP, KEY_W:
			_try_move(_screen_to_grid(Vector2i(0, -1)))
		KEY_DOWN, KEY_S:
			_try_move(_screen_to_grid(Vector2i(0, 1)))
		KEY_LEFT, KEY_A:
			_try_move(_screen_to_grid(Vector2i(-1, 0)))
		KEY_RIGHT, KEY_D:
			_try_move(_screen_to_grid(Vector2i(1, 0)))
		KEY_1:
			biome_index = 0
			_generate()
		KEY_2:
			biome_index = 1
			_generate()
		KEY_3:
			biome_index = 2
			_generate()
		KEY_4:
			biome_index = 3
			_generate()
		KEY_5:
			biome_index = 4
			_generate()
		KEY_6:
			biome_index = 5
			_generate()
		KEY_7:
			biome_index = 6
			_generate()
		KEY_8:
			biome_index = 7
			_generate()
		KEY_9:
			biome_index = 8
			_generate()
		KEY_0:
			biome_index = 9
			_generate()
		KEY_BRACKETLEFT:
			biome_index = 10
			_generate()
		KEY_BRACKETRIGHT:
			biome_index = 11
			_generate()
		KEY_BACKSLASH:
			biome_index = 12
			_generate()
