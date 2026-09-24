class_name Desk
extends Node2D
## Owns mouse pickup for everything on the desk.
##
## One point query per click finds the topmost Draggable under the cursor
## (highest z_index, then latest in the tree = drawn on top), so overlapping
## tools and items never both grab the same click. Runs in _unhandled_input,
## so UI buttons always get first claim on clicks.

const PICK_MASK := 0b11  # Layer 1 = tools, layer 2 = items.
const MAX_HITS := 32


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or mb.button_index != MOUSE_BUTTON_LEFT or not mb.pressed:
		return
	var point := to_global(make_input_local(mb).position)
	var target := get_draggable_at(point)
	if target:
		get_viewport().set_input_as_handled()
		target.pick_up(point)


## Topmost Draggable whose grab shape contains `point`, or null.
func get_draggable_at(point: Vector2) -> Draggable:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = PICK_MASK
	var best: Draggable = null
	for hit in get_world_2d().direct_space_state.intersect_point(query, MAX_HITS):
		var candidate := hit.collider as Draggable
		if candidate == null or candidate.is_held:
			continue
		if best == null or _draws_above(candidate, best):
			best = candidate
	return best


static func _draws_above(a: CanvasItem, b: CanvasItem) -> bool:
	if a.z_index != b.z_index:
		return a.z_index > b.z_index
	return a.is_greater_than(b)
