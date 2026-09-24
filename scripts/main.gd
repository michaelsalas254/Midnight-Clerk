extends Node2D
## Top-level coordinator. Owns the customer queue and routes signals between
## the desk (items, tools) and the UI. Contains no inspection rules itself.

## Items customers will bring in, in order. Drag .tres files from data/items here.
@export var item_queue: Array[PawnItem] = []
@export var item_scene: PackedScene
@export var starting_cash: int = 5000
## Area (in world space) that draggables may be moved within.
@export var desk_bounds := Rect2(80, 600, 1300, 440)

var cash: int = 0
var _queue_index := -1
var _current_item: PawnItemNode

@onready var customer_portrait: TextureRect = %CustomerPortrait
@onready var dialogue_text: RichTextLabel = %DialogueText
@onready var inspection_log: RichTextLabel = %InspectionLog
@onready var cash_label: Label = %CashLabel
@onready var offer_input: SpinBox = %OfferInput
@onready var offer_button: Button = %OfferButton
@onready var reject_button: Button = %RejectButton
@onready var alarm_button: Button = %AlarmButton
@onready var item_spawn: Marker2D = %ItemSpawn
@onready var items_root: Node2D = %Items
@onready var tools_root: Node2D = %Tools


func _ready() -> void:
	# Crisp dragging: deliver every motion event instead of merging them per frame.
	Input.use_accumulated_input = false

	cash = starting_cash
	_update_cash()

	for tool in tools_root.get_children():
		if tool is InspectionTool:
			tool.drag_bounds = desk_bounds
			tool.inspection_started.connect(_on_tool_inspection_started)

	offer_button.pressed.connect(_on_offer_pressed)
	reject_button.pressed.connect(_on_reject_pressed)
	alarm_button.pressed.connect(_on_alarm_pressed)

	_next_customer()


# --- Customer flow ---------------------------------------------------------

func _next_customer() -> void:
	if _current_item:
		_current_item.queue_free()
		_current_item = null
	_queue_index += 1
	if _queue_index >= item_queue.size():
		_end_shift()
		return
	_spawn_item(item_queue[_queue_index])
	_set_actions_enabled(true)


func _spawn_item(data: PawnItem) -> void:
	var item: PawnItemNode = item_scene.instantiate()
	item.data = data
	item.drag_bounds = desk_bounds
	item.trait_revealed.connect(_on_item_trait_revealed)
	item.inspected.connect(_on_item_inspected)
	items_root.add_child(item)
	_current_item = item

	# Slide the item across the counter from the customer's side.
	item.global_position = item_spawn.global_position + Vector2(0, -160)
	item.modulate.a = 0.0
	var tween := create_tween().set_parallel().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(item, "global_position", item_spawn.global_position, 0.35)
	tween.tween_property(item, "modulate:a", 1.0, 0.2)

	customer_portrait.modulate.a = 1.0
	dialogue_text.text = "[i]\"%s\"[/i]" % data.claimed_description
	offer_input.value = roundi(data.true_value * 0.5)
	inspection_log.clear()
	_last_log_line = ""
	_log("[b]%s[/b] placed on the desk." % data.item_name)


func _end_shift() -> void:
	_set_actions_enabled(false)
	customer_portrait.modulate.a = 0.0
	dialogue_text.text = "[b]Shift over.[/b] You walk out with $%d." % cash
	_log("No more customers tonight.")


func _resolve(message: String) -> void:
	_set_actions_enabled(false)
	_log(message)
	_update_cash()
	get_tree().create_timer(1.6).timeout.connect(_next_customer)


# --- Action buttons --------------------------------------------------------

func _on_offer_pressed() -> void:
	var data := _current_item.data
	var offer := int(offer_input.value)
	if offer > cash:
		_log("[color=salmon]You don't have $%d in the register.[/color]" % offer)
		return
	# The customer believes the item is genuine and haggles against that.
	if offer < data.true_value * 0.25:
		dialogue_text.text = "[i]\"$%d? You're robbing me. I'm out.\"[/i]" % offer
		_resolve("Customer walked. No deal.")
		return
	var worth := data.get_actual_value()
	cash += worth - offer
	dialogue_text.text = "[i]\"Pleasure doing business.\"[/i]"
	var profit := worth - offer
	var color := "palegreen" if profit >= 0 else "salmon"
	_resolve("Bought for $%d, really worth $%d. [color=%s]%+d[/color]" % [offer, worth, color, profit])


func _on_reject_pressed() -> void:
	var data := _current_item.data
	dialogue_text.text = "[i]\"Your loss, pal.\"[/i]"
	if data.is_counterfeit():
		_resolve("[color=palegreen]Good call. It was a fake.[/color]")
	else:
		_resolve("[color=khaki]It was genuine. You passed on a deal.[/color]")


func _on_alarm_pressed() -> void:
	var data := _current_item.data
	if data.is_stolen:
		dialogue_text.text = "[i]\"Wait, why are the lights flashing--\"[/i]"
		cash += 200
		_resolve("[color=palegreen]Stolen goods. Police reward: +$200.[/color]")
	else:
		cash -= 150
		_resolve("[color=salmon]False alarm. Police fine: -$150.[/color]")


# --- Inspection signals ----------------------------------------------------

func _on_item_trait_revealed(_item: PawnItemNode, _trait_id: StringName, message: String) -> void:
	_log("[color=violet][b]FOUND:[/b][/color] " + message)


func _on_item_inspected(_item: PawnItemNode, tool_name: String, message: String) -> void:
	_log("[color=gray]%s:[/color] %s" % [tool_name, message])


func _on_tool_inspection_started(_tool: InspectionTool, _item: PawnItemNode) -> void:
	pass  # Hook for sound effects / tutorial prompts.


# --- UI helpers ------------------------------------------------------------

var _last_log_line := ""

func _log(line: String) -> void:
	if line == _last_log_line:
		return  # Hovering the magnifier back and forth shouldn't spam the log.
	_last_log_line = line
	inspection_log.append_text(line + "\n")


func _update_cash() -> void:
	cash_label.text = "Register: $%d" % cash
	offer_input.max_value = maxi(cash, 0)


func _set_actions_enabled(enabled: bool) -> void:
	offer_button.disabled = not enabled
	reject_button.disabled = not enabled
	alarm_button.disabled = not enabled
