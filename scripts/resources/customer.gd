class_name Customer
extends Resource
## Pure data describing one person who walks up to the counter, and the item
## they bring. Read by CustomerDialogue; never mutated at runtime.
##
## Create new customers in the FileSystem dock: right-click > New Resource >
## Customer, fill the fields, and drag the .tres into Main > Customer Queue.
##
## Any line may use {name}, {item} and {offer}; they are filled in when spoken.

@export_group("Identity")
@export var customer_name: String = "Stranger"
@export var portrait: Texture2D
## The item they put on the counter.
@export var item: PawnItem

@export_group("Personality")
## 0 = ice cold, 1 = sweating bullets. Speeds up their speech, makes the
## portrait tremble, and rises each time you catch something on their item.
@export_range(0.0, 1.0, 0.05) var nervousness: float = 0.2
## How much nervousness goes up per revealed trait.
@export_range(0.0, 1.0, 0.05) var nervousness_per_trait: float = 0.25

@export_group("Lines")
## First words at the counter. The item's claimed_description follows.
@export var greeting_lines: Array[String] = []
## trait_id (e.g. "fake_signature", "fake_gold") -> what they say when you find it.
@export var trait_reactions: Dictionary = {}
## Said for any revealed trait not listed in trait_reactions.
@export var default_trait_reaction: String = "That... that wasn't there before."
## Said before accepting a lowball (but not insulting) offer.
@export var haggle_lines: Array[String] = []
## Said when they accept your offer.
@export var accept_lines: Array[String] = []
## Said when your offer is too insulting and they walk.
@export var refuse_lines: Array[String] = []
## Said when you reject the item and send them off.
@export var leave_lines: Array[String] = []
## Said when you hit the Silent Alarm.
@export var alarm_lines: Array[String] = []


## The reaction line for a revealed trait (falls back to default_trait_reaction).
func get_trait_reaction(trait_id: StringName) -> String:
	# Accept both String and StringName keys; the Inspector writes Strings.
	if trait_reactions.has(trait_id):
		return trait_reactions[trait_id]
	if trait_reactions.has(String(trait_id)):
		return trait_reactions[String(trait_id)]
	return default_trait_reaction
