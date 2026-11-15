class_name ShipBuild
extends RefCounted
## Derives the visible spacecraft build from the mission loadout and the
## refit modules bought between planets. The diagram is a readable silhouette
## story, not a second stats system: every module here already has a rule in
## GameState.UPGRADES, and the instrument slots mirror the payload chosen in
## Mission Design.

const SLOT_ORDER := [
	"nose", "top_front", "top_mid", "top_rear", "rear", "rear_low",
	"bottom", "bottom_front", "boom", "wing_l", "wing_r", "nose_low",
	"top_aux", "rear_aux",
]

const MODULE_INFO := {
	"camera": {
		"name": "MULTISPECTRAL CAMERA", "short": "CAM", "slot": "nose",
		"color": "#7cc8ff", "z": 2, "kind": "PAYLOAD",
	},
	"spectrometer": {
		"name": "SPECTROMETER", "short": "SPEC", "slot": "top_front",
		"color": "#b692ff", "z": 2, "kind": "PAYLOAD",
	},
	"radar": {
		"name": "RADAR SOUNDER", "short": "RDR", "slot": "top_mid",
		"color": "#54e6d1", "z": 2, "kind": "PAYLOAD",
	},
	"thermal": {
		"name": "THERMAL IMAGER", "short": "THM", "slot": "nose_low",
		"color": "#ff9c4a", "z": 2, "kind": "PAYLOAD",
	},
	"magnetometer": {
		"name": "MAGNETOMETER", "short": "MAG", "slot": "boom",
		"color": "#7fe08a", "z": 0, "kind": "PAYLOAD",
	},
	"drill": {
		"name": "SUBSURFACE DRILL", "short": "DRL", "slot": "bottom_front",
		"color": "#d8b070", "z": 2, "kind": "PAYLOAD",
	},
	"rtg": {
		"name": "RTG AUXILIARY", "short": "RTG", "slot": "rear",
		"color": "#d8b070", "z": 1, "kind": "MODULE",
	},
	"radiator": {
		"name": "DEPLOYABLE RADIATOR", "short": "RAD", "slot": "top_rear",
		"color": "#e8eff7", "z": 1, "kind": "MODULE",
	},
	"wheel": {
		"name": "REACTION WHEEL", "short": "RW", "slot": "bottom",
		"color": "#8ba0b6", "z": 1, "kind": "MODULE",
	},
	"armor": {
		"name": "ABLATIVE ARMOR", "short": "ARM", "slot": "nose",
		"color": "#54e6d1", "z": 2, "kind": "MODULE",
	},
	"buffer": {
		"name": "DEEP DATA BUFFER", "short": "BUF", "slot": "top_mid",
		"color": "#7fe08a", "z": 1, "kind": "MODULE",
	},
	"antenna": {
		"name": "HIGH-GAIN ANTENNA", "short": "HGA", "slot": "top_rear",
		"color": "#ffc45c", "z": 1, "kind": "MODULE",
	},
	"science_pack": {
		"name": "SCIENCE PACKAGE", "short": "SCI", "slot": "top_front",
		"color": "#b692ff", "z": 1, "kind": "MODULE",
	},
	"salvage": {
		"name": "SALVAGE PROTOCOL", "short": "SAL", "slot": "rear_low",
		"color": "#ffc45c", "z": 1, "kind": "MODULE",
	},
	"repair": {
		"name": "FIELD REPAIR KIT", "short": "FIX", "slot": "bottom",
		"color": "#7fe08a", "z": 1, "kind": "MODULE",
	},
	"coolant": {
		"name": "CRYO COOLANT LOOP", "short": "CL", "slot": "rear_low",
		"color": "#7cc8ff", "z": 1, "kind": "MODULE",
	},
	"ion": {
		"name": "ION THRUSTER", "short": "ION", "slot": "rear",
		"color": "#54e6d1", "z": 1, "kind": "MODULE",
	},
	"wheel2": {"name": "RW-8 GYRODYNE", "short": "RW8", "slot": "bottom_front",
		"color": "#8ba0b6", "z": 1, "kind": "MODULE"},
	"ion2": {"name": "HALL H12", "short": "H12", "slot": "rear_aux",
		"color": "#54e6d1", "z": 1, "kind": "MODULE"},
	"rtg2": {"name": "MMRTG-280", "short": "R280", "slot": "rear",
		"color": "#d8b070", "z": 1, "kind": "MODULE"},
	"fuel_cell": {"name": "RFC-2 CELL", "short": "RFC", "slot": "top_aux",
		"color": "#7fe08a", "z": 1, "kind": "MODULE"},
	"fuel_cell2": {"name": "RFC-4 CELL", "short": "RFC4", "slot": "top_aux",
		"color": "#7fe08a", "z": 1, "kind": "MODULE"},
	"radiator2": {"name": "LHP-4 LOOP", "short": "LHP4", "slot": "top_rear",
		"color": "#e8eff7", "z": 1, "kind": "MODULE"},
	"coolant2": {"name": "CRYO LOOP II", "short": "CL2", "slot": "rear_low",
		"color": "#7cc8ff", "z": 1, "kind": "MODULE"},
	"armor2": {"name": "WHIPPLE MK-II", "short": "WH2", "slot": "nose",
		"color": "#54e6d1", "z": 2, "kind": "MODULE"},
	"whipple": {"name": "COMPOSITE SHELL", "short": "CMP", "slot": "nose_low",
		"color": "#8ba0b6", "z": 1, "kind": "MODULE"},
	"whipple2": {"name": "COMPOSITE MK-II", "short": "CMP2", "slot": "nose_low",
		"color": "#8ba0b6", "z": 1, "kind": "MODULE"},
	"antenna2": {"name": "KA-BAND DSN", "short": "DSN", "slot": "top_rear",
		"color": "#ffc45c", "z": 1, "kind": "MODULE"},
	"buffer2": {"name": "SSR-8 RECORDER", "short": "SSR8", "slot": "top_mid",
		"color": "#7fe08a", "z": 1, "kind": "MODULE"},
	"science2": {"name": "LAB MK-II", "short": "LAB2", "slot": "top_front",
		"color": "#b692ff", "z": 1, "kind": "MODULE"},
	"sensor": {"name": "MULTI-SENSOR BAY", "short": "MSB", "slot": "top_front",
		"color": "#b692ff", "z": 1, "kind": "MODULE"},
	"sensor2": {"name": "SENSOR BAY II", "short": "MSB2", "slot": "top_front",
		"color": "#b692ff", "z": 1, "kind": "MODULE"},
}


static func modules(instruments: Array, owned: Array) -> Array:
	var out: Array = []
	var used: Dictionary = {}
	for id in instruments:
		_add_module(out, used, str(id))
	for id in owned:
		_add_module(out, used, str(id))
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("z", 1)) < int(b.get("z", 1))
	)
	return out


static func _add_module(out: Array, used: Dictionary, id: String) -> void:
	var info: Dictionary = MODULE_INFO.get(id, {})
	if info.is_empty():
		return
	var slot := str(info.get("slot", "top_mid"))
	if used.has(slot):
		slot = _free_slot(used)
	used[slot] = true
	out.append({
		"id": id,
		"name": str(info.get("name", id)),
		"short": str(info.get("short", id.to_upper())),
		"slot": slot,
		"color": Color(str(info.get("color", "#54e6d1"))),
		"z": int(info.get("z", 1)),
		"kind": str(info.get("kind", "MODULE")),
	})


static func _free_slot(used: Dictionary) -> String:
	for slot in SLOT_ORDER:
		if not used.has(slot):
			return str(slot)
	return "top_aux"


static func refit_count(owned: Array) -> int:
	var n := 0
	for id in owned:
		if MODULE_INFO.has(str(id)):
			n += 1
	return n


static func tier(refits: int) -> Dictionary:
	if refits >= 7:
		return {"name": "FLAGSHIP", "color": Color("#54e6d1")}
	if refits >= 5:
		return {"name": "DEEP-SPACE", "color": Color("#7cc8ff")}
	if refits >= 3:
		return {"name": "SURVEY-RIGGED", "color": Color("#b692ff")}
	if refits >= 1:
		return {"name": "FIELD-READY", "color": Color("#ffc45c")}
	return {"name": "STOCK", "color": Color("#8ba0b6")}


static func line(instruments: Array, owned: Array) -> String:
	var payload: Array[String] = []
	var refits: Array[String] = []
	for m in modules(instruments, owned):
		if str(m.get("kind", "")) == "PAYLOAD":
			payload.append(str(m["short"]))
		else:
			refits.append(str(m["short"]))
	var rig := "RIG  " + (" · ".join(refits) if not refits.is_empty() else "STOCK")
	var pay := "PAY  " + (" · ".join(payload) if not payload.is_empty() else "NONE")
	return rig + "\n" + pay
