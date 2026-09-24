class_name InspectionTool
extends Draggable
## Base class for desk tools. Owns a "Sensor" Area2D that tracks which items
## are under the tool's working end, and turns that into two virtual hooks:
## _begin_inspecting(item) / _end_inspecting(item).
##
## Subclasses only talk to items through PawnItemNode's public methods.

signal inspection_started(tool: InspectionTool, item: PawnItemNode)
signal inspection_ended(tool: InspectionTool, item: PawnItemNode)

enum Activation {
	WHILE_HELD,  ## Works only while the player holds it (UV light, magnifier).
	ON_DROP,     ## Fires once when dropped onto an item (acid bottle).
}

@export var tool_name: String = "Tool"
@export var activation: Activation = Activation.WHILE_HELD
## Glide back to the tray after use (so the desk doesn't get cluttered).
@export var return_home_on_drop: bool = false

var home_position := Vector2.ZERO

var _items_in_range: Array[PawnItemNode] = []
var _active_on: Array[PawnItemNode] = []

@onready var sensor: Area2D = $Sensor


func _ready() -> void:
	super._ready()
	home_position = position
	sensor.area_entered.connect(_on_sensor_area_entered)
	sensor.area_exited.connect(_on_sensor_area_exited)
	picked_up.connect(_on_picked_up)
	dropped.connect(_on_dropped)
	_set_active_visuals(false)


func _on_sensor_area_entered(area: Area2D) -> void:
	var item := area as PawnItemNode
	if item == null or _items_in_range.has(item):
		return
	_items_in_range.append(item)
	if is_held and activation == Activation.WHILE_HELD:
		_start(item)


func _on_sensor_area_exited(area: Area2D) -> void:
	var item := area as PawnItemNode
	if item == null:
		return
	_items_in_range.erase(item)
	_stop(item)


func _on_picked_up(_self: Draggable) -> void:
	if activation == Activation.WHILE_HELD:
		_set_active_visuals(true)
		for item in _items_in_range:
			_start(item)


func _on_dropped(_self: Draggable) -> void:
	match activation:
		Activation.WHILE_HELD:
			_set_active_visuals(false)
			for item in _active_on.duplicate():
				_stop(item)
		Activation.ON_DROP:
			for item in _items_in_range:
				_begin_inspecting(item)
				inspection_started.emit(self, item)
	if return_home_on_drop:
		create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT) \
				.tween_property(self, "position", home_position, 0.25)


func _start(item: PawnItemNode) -> void:
	if _active_on.has(item):
		return
	_active_on.append(item)
	_begin_inspecting(item)
	inspection_started.emit(self, item)


func _stop(item: PawnItemNode) -> void:
	if not _active_on.has(item):
		return
	_active_on.erase(item)
	if is_instance_valid(item):
		_end_inspecting(item)
	inspection_ended.emit(self, item)


func _exit_tree() -> void:
	for item in _active_on.duplicate():
		_stop(item)


# --- Virtual hooks ---------------------------------------------------------

func _begin_inspecting(_item: PawnItemNode) -> void:
	pass


func _end_inspecting(_item: PawnItemNode) -> void:
	pass


## Toggle glow/beam effects when the tool is switched on/off.
func _set_active_visuals(_active: bool) -> void:
	pass
