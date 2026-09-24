class_name Typewriter
extends RichTextLabel
## Reveals BBCode text one character at a time, with short beats on
## punctuation. Click the text to finish the current line instantly.
##
## Knows nothing about customers; CustomerDialogue feeds it lines and waits
## for line_finished.

signal line_finished
## Fired per revealed character. Hook for typing blips.
signal character_typed(character: String)

@export var characters_per_second: float = 45.0
## Extra pause (seconds) after sentence-ending and mid-sentence punctuation.
@export var sentence_pause: float = 0.28
@export var comma_pause: float = 0.1

var _typing := false
var _cps := 45.0
var _budget := 0.0  # Characters we're allowed to reveal; negative = pausing.
var _parsed := ""


func _ready() -> void:
	set_process(false)


## Start typing `bbcode`. Replaces whatever was showing.
func type_line(bbcode: String, cps: float = characters_per_second) -> void:
	text = bbcode
	_parsed = get_parsed_text()
	_cps = maxf(cps, 1.0)
	_budget = 0.0
	visible_characters = 0
	_typing = true
	set_process(true)
	if _parsed.is_empty():
		_finish()


## Show the whole line now. No-op if nothing is typing.
func skip() -> void:
	if _typing:
		_finish()


func is_typing() -> bool:
	return _typing


func _process(delta: float) -> void:
	_budget += delta * _cps
	while _typing and _budget >= 1.0:
		_budget -= 1.0
		visible_characters += 1
		var ch := _parsed[visible_characters - 1]
		character_typed.emit(ch)
		if visible_characters >= _parsed.length():
			_finish()
		elif ch in ".!?":
			_budget -= sentence_pause * _cps
		elif ch in ",;:-":
			_budget -= comma_pause * _cps


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT and _typing:
		skip()
		accept_event()


func _finish() -> void:
	_typing = false
	set_process(false)
	visible_characters = -1
	line_finished.emit()
