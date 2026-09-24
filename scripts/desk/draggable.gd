class_name Draggable
extends Area2D
## Base class for anything the player can pick up and slide around the desk.
##
## Pickup is decided by the Desk (which finds the topmost object under the
## click) calling pick_up(). While held, motion and release are read in _input,
## so the object follows every mouse event and never "drops" when the cursor
## outruns it. Positions come from the events themselves, not a cursor poll,
## so there is no frame of lag.
##
## Expected children: "Sprite" (Sprite2D), "Shape" (CollisionShape2D),
## optional "Shadow" (Sprite2D).

signal picked_up(draggable: Draggable)
signal dropped(draggable: Draggable)

const HELD_Z_INDEX := 100
const LIFT_TIME := 0.08

## Longest side of the sprite on the desk, in pixels. The grab shape matches it.
@export var display_size: float = 180.0
## Scale multiplier while held, for a tactile "lifted off the desk" feel.
@export var lift_scale: float = 1.08
## Shadow offset while resting / while held.
@export var rest_shadow_offset := Vector2(6, 8)
@export var lift_shadow_offset := Vector2(18, 26)

## World-space rect the object's origin is clamped to. Empty = unclamped.
var drag_bounds := Rect2()
var is_held := false

var _grab_offset := Vector2.ZERO
var _rest_z_index := 0
var _lift_tween: Tween

@onready var sprite: Sprite2D = $Sprite
@onready var shape: CollisionShape2D = $Shape
@onready var shadow: Sprite2D = get_node_or_null("Shadow")


func _ready() -> void:
	input_pickable = false  # The Desk does pickup; skip physics picking.
	_rest_z_index = z_index
	fit_to_texture(sprite.texture)


## Scale the sprite (and shadow) so its longest side equals display_size,
## and resize the grab rectangle to match. Call again after swapping textures.
func fit_to_texture(texture: Texture2D) -> void:
	sprite.texture = texture
	if texture == null:
		return
	var tex_size := texture.get_size()
	var factor := display_size / maxf(tex_size.x, tex_size.y)
	sprite.scale = Vector2.ONE * factor
	if shadow:
		shadow.texture = texture
		shadow.scale = sprite.scale
		shadow.position = rest_shadow_offset
	var rect := RectangleShape2D.new()
	rect.size = tex_size * factor * 0.85  # Trim transparent margins a little.
	shape.shape = rect


func _input(event: InputEvent) -> void:
	if not is_held:
		return
	if event is InputEventMouseMotion:
		_follow_point(_event_to_world(event))
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		get_viewport().set_input_as_handled()
		drop()


## `grab_point` is the world position of the click, so the object keeps the
## same offset from the cursor instead of snapping its center to it.
func pick_up(grab_point: Vector2) -> void:
	if is_held:
		return
	is_held = true
	_grab_offset = global_position - grab_point
	z_index = HELD_Z_INDEX
	_animate_lift(true)
	picked_up.emit(self)


func drop() -> void:
	if not is_held:
		return
	is_held = false
	z_index = _rest_z_index
	# Last-dropped object renders (and picks) above its siblings.
	get_parent().move_child(self, -1)
	_animate_lift(false)
	dropped.emit(self)


func _event_to_world(event: InputEventMouse) -> Vector2:
	return get_canvas_transform().affine_inverse() * event.position


func _follow_point(point: Vector2) -> void:
	var target := point + _grab_offset
	if drag_bounds.has_area():
		target = target.clamp(drag_bounds.position, drag_bounds.end)
	global_position = target


func _animate_lift(lifted: bool) -> void:
	if _lift_tween:
		_lift_tween.kill()
	_lift_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_lift_tween.tween_property(self, "scale", Vector2.ONE * (lift_scale if lifted else 1.0), LIFT_TIME)
	if shadow:
		_lift_tween.tween_property(shadow, "position",
				lift_shadow_offset if lifted else rest_shadow_offset, LIFT_TIME)
