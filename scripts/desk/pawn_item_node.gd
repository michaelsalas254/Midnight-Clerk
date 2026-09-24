class_name PawnItemNode
extends Draggable
## The physical, on-desk representation of a PawnItem resource.
##
## Tools never touch `data` or the sprite directly; they call the public
## `*_exposure` / `apply_*` methods below. The item decides how to react and
## reports findings through signals, which the Main scene routes to the UI.

## A hidden trait was discovered (e.g. &"fake_signature", &"fake_gold").
signal trait_revealed(item: PawnItemNode, trait_id: StringName, message: String)
## Any tool produced a finding worth logging, revealing or not.
signal inspected(item: PawnItemNode, tool_name: String, message: String)

const UV_TINT := Color(0.72, 0.55, 1.0)
const ACID_FAIL_TINT := Color(0.65, 0.9, 0.55)

@export var data: PawnItem:
	set = set_data

var _uv_sources := 0
var _revealed: Dictionary = {}  # trait_id -> true, so each finding fires once.
var _acid_tested := false


func _ready() -> void:
	super._ready()
	if data:
		_apply_data()


func set_data(value: PawnItem) -> void:
	data = value
	_uv_sources = 0
	_revealed.clear()
	_acid_tested = false
	if is_node_ready():
		_apply_data()


func _apply_data() -> void:
	display_size = data.desk_size
	fit_to_texture(data.default_sprite)
	sprite.modulate = Color.WHITE


# --- Public tool API -------------------------------------------------------

## Called by a UV light when its beam starts (true) or stops (false) covering
## this item. Counted, so two overlapping lights don't fight each other.
func set_uv_exposure(exposed: bool) -> void:
	_uv_sources = maxi(_uv_sources + (1 if exposed else -1), 0)
	_refresh_uv_visuals()
	if exposed and _uv_sources == 1:
		if data.has_fake_signature:
			_reveal(&"fake_signature", "UV reveals a forged signature. This %s is a fake." % data.item_name)
		else:
			inspected.emit(self, "UV Light", "Nothing fluoresces on the %s." % data.item_name)


## Called by the magnifying glass when it hovers the item.
func inspect_magnified() -> void:
	inspected.emit(self, "Magnifier", data.magnifier_note)


## Called by the acid bottle when it is dropped on the item. One test per item.
func apply_acid_test() -> void:
	if _acid_tested:
		inspected.emit(self, "Acid Test", "Already tested. Don't burn it twice.")
		return
	_acid_tested = true
	if not data.claims_gold:
		inspected.emit(self, "Acid Test", "Not sold as gold. Acid tells you nothing.")
	elif data.is_real_gold:
		inspected.emit(self, "Acid Test", "No reaction. The gold is real.")
	else:
		sprite.modulate = ACID_FAIL_TINT
		_reveal(&"fake_gold", "The acid turns green. The %s is gold-plated junk." % data.item_name)


func is_trait_revealed(trait_id: StringName) -> bool:
	return _revealed.has(trait_id)


# --- Internals -------------------------------------------------------------

func _refresh_uv_visuals() -> void:
	var under_uv := _uv_sources > 0
	var shows_hidden := under_uv and data.has_fake_signature and data.uv_revealed_sprite != null
	sprite.texture = data.uv_revealed_sprite if shows_hidden else data.default_sprite
	# Keep the on-desk size identical even if the UV art has a different resolution.
	var tex_size := sprite.texture.get_size()
	sprite.scale = Vector2.ONE * (display_size / maxf(tex_size.x, tex_size.y))
	if shows_hidden:
		sprite.self_modulate = Color.WHITE
	else:
		sprite.self_modulate = UV_TINT if under_uv else Color.WHITE


func _reveal(trait_id: StringName, message: String) -> void:
	if _revealed.has(trait_id):
		return
	_revealed[trait_id] = true
	trait_revealed.emit(self, trait_id, message)
