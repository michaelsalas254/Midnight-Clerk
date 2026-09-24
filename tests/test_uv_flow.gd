extends SceneTree
## Headless smoke test: drags the UV light onto the fake watch with real mouse
## events and checks the texture swap.
## Usage: godot --headless --script res://tests/test_uv_flow.gd

var _failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(20)

	var item: PawnItemNode = main.get_node("%Items").get_child(0)
	var uv: UVBlacklight = main.get_node("%Tools/UVLight")
	var found: Array = []
	item.trait_revealed.connect(func(_i, id, _m): found.append(id))

	_check(item.sprite.texture == item.data.default_sprite, "item starts with default sprite")

	# Press on the UV light, drag across to the item, hold there.
	_mouse_button(uv.global_position, true)
	await _frames(3)
	_check(uv.is_held, "UV light picked up by click")
	_check(uv.beam.visible, "beam on while held")
	var start := uv.global_position
	for i in range(1, 21):
		_mouse_motion(start.lerp(item.global_position, i / 20.0))
		await _frames(1)
	await _frames(5)
	_check(uv.global_position.distance_to(item.global_position) < 2.0, "UV light followed the cursor")
	_check(item.sprite.texture == item.data.uv_revealed_sprite, "UV-revealed sprite shown")
	_check(found.has(&"fake_signature"), "fake_signature trait revealed")

	# Release: light turns off, texture reverts.
	_mouse_button(item.global_position, false)
	await _frames(5)
	_check(not uv.is_held and not uv.beam.visible, "UV light dropped and off")
	_check(item.sprite.texture == item.data.default_sprite, "default sprite restored")

	# Acid on the fake watch.
	var acid: AcidTest = main.get_node("%Tools/AcidTest")
	acid.global_position = item.global_position + Vector2(300, 0)
	await _frames(3)
	_mouse_button(acid.global_position, true)
	await _frames(2)
	_mouse_motion(item.global_position)
	await _frames(5)
	_mouse_button(item.global_position, false)
	await _frames(5)
	_check(found.has(&"fake_gold"), "acid reveals fake gold")

	print("\n%s (%d failures)" % ["PASS" if _failures == 0 else "FAIL", _failures])
	quit(_failures)


func _check(ok: bool, what: String) -> void:
	print(("  ok   " if ok else "  FAIL ") + what)
	if not ok:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame
		await process_frame


func _mouse_button(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = _to_window(pos)
	root.push_input(ev)


func _mouse_motion(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _to_window(pos)
	root.push_input(ev)


## push_input expects window coordinates; the headless window is tiny, so map
## world (viewport) coordinates through the stretch transform.
func _to_window(pos: Vector2) -> Vector2:
	return root.get_final_transform() * pos
