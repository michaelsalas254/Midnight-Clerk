extends SceneTree
## Headless smoke test: drags the UV light onto the fake watch with real mouse
## events and checks the texture swap, then walks the customer dialogue state
## machine through a whole shift (reveal reactions, reject, haggle, alarm).
## Usage: godot --headless --script res://tests/test_uv_flow.gd

var _failures := 0


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(2)

	# --- Customer 1 walks in ---
	var dialogue: CustomerDialogue = main.get_node("%CustomerDialogue")
	var text: Typewriter = main.get_node("%DialogueText")
	var reject_button: Button = main.get_node("%RejectButton")
	_check(dialogue.state == CustomerDialogue.State.ARRIVING, "first customer arriving")
	_check(reject_button.disabled, "actions locked until the customer reaches the counter")
	await _until(func() -> bool: return dialogue.state == CustomerDialogue.State.GREETING)
	_check(dialogue.customer.customer_name == "Vince", "Vince greets you")
	_check(main.get_node("%Items").get_child_count() == 1, "item placed when the customer arrives")
	_check(not reject_button.disabled, "actions unlocked on arrival")
	await _frames(3)
	_check(text.is_typing() and text.visible_characters < text.get_total_character_count(),
			"greeting types out")
	# A real click on the dialogue text skips the line.
	_mouse_button(text.get_global_rect().get_center(), true)
	_mouse_button(text.get_global_rect().get_center(), false)
	await _frames(2)
	_check(dialogue.state == CustomerDialogue.State.WAITING and not text.is_typing(),
			"click skips greeting -> WAITING")
	await _frames(10)

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
	_check(dialogue.state == CustomerDialogue.State.REACTING, "customer reacts to the UV reveal")
	_check("purple lamp" in text.get_parsed_text(), "trait-specific reaction line")
	_check(dialogue.nervousness > dialogue.customer.nervousness, "nervousness rises on reveal")

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
	_check("Bad light" in text.get_parsed_text(), "customer reacts to the acid test")
	dialogue.skip_line()
	await _frames(2)
	_check(dialogue.state == CustomerDialogue.State.WAITING, "back to WAITING after reaction")

	# --- Reject: LEAVING -> IDLE -> next customer ---
	reject_button.pressed.emit()
	_check(dialogue.state == CustomerDialogue.State.LEAVING, "reject -> LEAVING")
	_check(reject_button.disabled, "actions locked while leaving")
	dialogue.react_to_trait(&"fake_gold")
	_check(dialogue.state == CustomerDialogue.State.LEAVING, "reveals ignored once leaving")
	await _until(func() -> bool: return dialogue.customer and dialogue.customer.customer_name == "Danny")
	_check(dialogue.state == CustomerDialogue.State.ARRIVING, "Vince left, Danny arriving")
	await _frames(2)
	_check(main.get_node("%Items").get_child_count() == 0, "old item cleared before next arrival")

	# --- Customer 2: lowball but acceptable offer -> haggle, then accept ---
	await _until(func() -> bool: return dialogue.state == CustomerDialogue.State.GREETING)
	var states: Array = []
	dialogue.state_changed.connect(func(to, _from): states.append(to))
	main.get_node("%OfferInput").value = 400
	main.get_node("%OfferButton").pressed.emit()
	_check(dialogue.state == CustomerDialogue.State.NEGOTIATING, "offer -> NEGOTIATING")
	_check("$400" in text.get_parsed_text(), "haggle line quotes the offer")
	await _until(func() -> bool: return dialogue.state == CustomerDialogue.State.LEAVING)
	_check("never here" in text.get_parsed_text(), "accepts after haggling")
	_check(states == [CustomerDialogue.State.NEGOTIATING, CustomerDialogue.State.LEAVING],
			"GREETING -> NEGOTIATING -> LEAVING")

	# --- Customer 3: alarm, then the shift ends ---
	await _until(func() -> bool: return dialogue.state == CustomerDialogue.State.GREETING 			and dialogue.customer.customer_name == "Mrs. Albescu")
	main.get_node("%AlarmButton").pressed.emit()
	_check("police" in text.get_parsed_text(), "alarm line")
	await _until(func() -> bool: return "Shift over" in text.get_parsed_text())
	_check(dialogue.state == CustomerDialogue.State.IDLE and dialogue.customer == null,
			"IDLE with no customer after the last one leaves")

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


## Wait (real time) until `cond` holds; fails the run if it never does.
func _until(cond: Callable, timeout_sec: float = 10.0) -> void:
	var deadline := Time.get_ticks_msec() + int(timeout_sec * 1000.0)
	while not cond.call():
		if Time.get_ticks_msec() > deadline:
			_check(false, "timed out waiting")
			return
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
