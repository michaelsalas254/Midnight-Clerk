class_name CustomerDialogue
extends Node
## Drives the customer at the counter: portrait slide-in/out and what they say.
##
##   IDLE -> ARRIVING -> GREETING -> WAITING <-> REACTING
##                                     |            |
##                                     v            v
##                                 NEGOTIATING -> LEAVING -> IDLE
##
## Main tells it what happened through the public methods (present,
## react_to_trait, negotiate, send_away). It reports back only through
## signals. It never decides a deal's outcome and never blocks inspection.

signal state_changed(state: State, previous: State)
## The customer reached the counter and started talking. Put their item down.
signal customer_arrived(customer: Customer)
## The customer is gone (portrait off screen). Safe to bring the next one.
signal customer_left(customer: Customer)

enum State { IDLE, ARRIVING, GREETING, WAITING, REACTING, NEGOTIATING, LEAVING }
enum Farewell { REJECTED, ALARM }

## Legal moves. Anything else is a bug in the caller and gets refused.
const TRANSITIONS := {
	State.IDLE: [State.ARRIVING],
	State.ARRIVING: [State.GREETING],
	State.GREETING: [State.WAITING, State.REACTING, State.NEGOTIATING, State.LEAVING],
	State.WAITING: [State.REACTING, State.NEGOTIATING, State.LEAVING],
	State.REACTING: [State.WAITING, State.REACTING, State.NEGOTIATING, State.LEAVING],
	State.NEGOTIATING: [State.LEAVING],
	State.LEAVING: [State.IDLE],
}
## States where the customer is at the counter and will respond to the player.
const LISTENING := [State.GREETING, State.WAITING, State.REACTING]

const FALLBACK_GREETING := "Evening."
const FALLBACK_HAGGLE := "{offer}? That's low. ...Fine."
const FALLBACK_ACCEPT := "Pleasure doing business."
const FALLBACK_REFUSE := "{offer}? You're robbing me. I'm out."
const FALLBACK_LEAVE := "Your loss, pal."
const FALLBACK_ALARM := "Wait, why are the lights flashing--"

@export var portrait: TextureRect
@export var text: Typewriter
@export var speaker_label: Label

@export_group("Timing")
@export var slide_distance: float = 560.0
@export var slide_time: float = 0.45
## Pause after the last line before the customer walks off.
@export var read_time: float = 1.1
## Pause between a haggle line and the line that closes the deal.
@export var haggle_beat: float = 0.5

@export_group("Delivery")
## Typing speed at nervousness 0 and 1.
@export var calm_cps: float = 38.0
@export var nervous_cps: float = 75.0
## Above this nervousness their lines shake and the portrait trembles.
@export_range(0.0, 1.0) var shaky_above: float = 0.6
@export var tremble_pixels: float = 5.0

@export_group("Negotiation")
## Accepted offers below this fraction of the claimed value get a haggle line first.
@export_range(0.0, 1.0) var haggle_below: float = 0.6

var state := State.IDLE
var customer: Customer
## Runtime copy; the Customer resource is never written to.
var nervousness := 0.0

var _offer := 0
var _pending_traits: Array[StringName] = []
var _step := 0  # Bumped per sequence step so stale callbacks do nothing.
var _at_counter := false
var _rest_position := Vector2.ZERO
var _portrait_tween: Tween
var _clock := 0.0


func _ready() -> void:
	_rest_position = portrait.position
	portrait.position = _offstage_position()
	portrait.modulate.a = 0.0
	speaker_label.text = ""
	text.text = ""


func _process(delta: float) -> void:
	if not _at_counter:
		return
	_clock += delta
	var amount := maxf(nervousness - shaky_above, 0.0) / maxf(1.0 - shaky_above, 0.01)
	var wobble := Vector2(sin(_clock * 31.0), cos(_clock * 23.0) * 0.5) * tremble_pixels * amount
	portrait.position = _rest_position + wobble


# --- Public API ------------------------------------------------------------

## Walk a new customer up to the counter. Only valid while IDLE.
func present(who: Customer) -> void:
	if not _set_state(State.ARRIVING):
		return
	customer = who
	nervousness = who.nervousness
	_pending_traits.clear()
	_offer = 0
	portrait.texture = who.portrait
	speaker_label.text = who.customer_name
	text.text = ""
	_step += 1
	_then(_slide_portrait(true).finished, _step, _greet)


## The player found something on their item. Ignored once the deal is done.
func react_to_trait(trait_id: StringName) -> void:
	if state == State.ARRIVING:
		_pending_traits.append(trait_id)  # Too quick; they'll react once settled.
		return
	if state not in LISTENING:
		return
	nervousness = minf(nervousness + customer.nervousness_per_trait, 1.0)
	_set_state(State.REACTING)
	_say(customer.get_trait_reaction(trait_id), _settle)


## The player made an offer. `accepted` is decided by Main, not here.
func negotiate(offer: int, accepted: bool) -> void:
	if state not in LISTENING:
		return
	_offer = offer
	_set_state(State.NEGOTIATING)
	if not accepted:
		_leave(_pick(customer.refuse_lines, FALLBACK_REFUSE))
		return
	var closing := _pick(customer.accept_lines, FALLBACK_ACCEPT)
	if offer < customer.item.true_value * haggle_below:
		_say(_pick(customer.haggle_lines, FALLBACK_HAGGLE),
				func() -> void: _wait(haggle_beat, func() -> void: _leave(closing)))
	else:
		_leave(closing)


## The player turned them away (Reject) or called the police (Silent Alarm).
func send_away(reason: Farewell) -> void:
	if state not in LISTENING:
		return
	match reason:
		Farewell.REJECTED:
			_leave(_pick(customer.leave_lines, FALLBACK_LEAVE))
		Farewell.ALARM:
			_leave(_pick(customer.alarm_lines, FALLBACK_ALARM))


## Narrator text with nobody at the counter (e.g. end of shift).
func announce(bbcode: String) -> void:
	if state != State.IDLE:
		return
	_step += 1
	speaker_label.text = ""
	text.type_line(bbcode, calm_cps)


## Finish the line being typed right now.
func skip_line() -> void:
	text.skip()


func is_at_counter() -> bool:
	return _at_counter


# --- Sequence steps --------------------------------------------------------

func _greet() -> void:
	_at_counter = true
	_set_state(State.GREETING)
	customer_arrived.emit(customer)
	var greeting := _pick(customer.greeting_lines, FALLBACK_GREETING)
	_say("%s %s" % [greeting, customer.item.claimed_description], _settle)


## Back to WAITING; react to anything found while they were still walking up.
func _settle() -> void:
	if not _set_state(State.WAITING):
		return
	if not _pending_traits.is_empty():
		react_to_trait(_pending_traits.pop_front())


func _leave(line: String) -> void:
	_set_state(State.LEAVING)
	_say(line, func() -> void: _wait(read_time, _exit))


func _exit() -> void:
	_at_counter = false
	_step += 1
	_then(_slide_portrait(false).finished, _step, _on_offstage)


func _on_offstage() -> void:
	var who := customer
	customer = null
	_set_state(State.IDLE)
	customer_left.emit(who)


# --- Helpers ---------------------------------------------------------------

func _set_state(to: State) -> bool:
	if to not in TRANSITIONS[state]:
		push_error("CustomerDialogue: illegal transition %s -> %s"
				% [State.keys()[state], State.keys()[to]])
		return false
	var previous := state
	state = to
	state_changed.emit(to, previous)
	return true


## Type a customer line, then run `next` (unless another step took over).
func _say(line: String, next: Callable) -> void:
	_step += 1
	_then(text.line_finished, _step, next)
	text.type_line(_dress(line), lerpf(calm_cps, nervous_cps, nervousness))


func _wait(seconds: float, next: Callable) -> void:
	_step += 1
	_then(get_tree().create_timer(seconds).timeout, _step, next)


## One-shot connect that only fires if no newer step has started since.
func _then(sig: Signal, step: int, next: Callable) -> void:
	var guarded := func() -> void:
		if step == _step:
			next.call()
	sig.connect(guarded, CONNECT_ONE_SHOT)


## Fill placeholders, quote it, and make it shake if they're rattled.
func _dress(line: String) -> String:
	var filled := line.format({
		"name": customer.customer_name,
		"item": customer.item.item_name if customer.item else "item",
		"offer": "$%d" % _offer,
	})
	var quoted := "[i]\"%s\"[/i]" % filled
	if nervousness > shaky_above:
		quoted = "[shake rate=18.0 level=6]%s[/shake]" % quoted
	return quoted


func _pick(lines: Array[String], fallback: String) -> String:
	return lines.pick_random() if not lines.is_empty() else fallback


func _slide_portrait(entering: bool) -> Tween:
	if _portrait_tween:
		_portrait_tween.kill()
	var easing := Tween.EASE_OUT if entering else Tween.EASE_IN
	_portrait_tween = create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(easing)
	_portrait_tween.tween_property(portrait, "position",
			_rest_position if entering else _offstage_position(), slide_time)
	_portrait_tween.tween_property(portrait, "modulate:a", 1.0 if entering else 0.0, slide_time * 0.8)
	return _portrait_tween


func _offstage_position() -> Vector2:
	return _rest_position - Vector2(slide_distance, 0)
