class_name PawnItem
extends Resource
## Pure data describing one item a customer can bring to the counter.
##
## Create new items in the FileSystem dock: right-click > New Resource > PawnItem,
## then fill the fields in the Inspector. No code needed per item.

@export_group("Identity")
@export var item_name: String = "Unknown Item"
## What the customer claims the item is. Shown to the player.
@export_multiline var claimed_description: String = ""

@export_group("Sprites")
## Texture shown under normal desk light.
@export var default_sprite: Texture2D
## Texture shown while a UV light is on the item AND it has a UV-reactive trait.
@export var uv_revealed_sprite: Texture2D
## On-desk size in pixels (longest side). Keeps huge source art from filling the desk.
@export var desk_size: float = 260.0

@export_group("Appraisal")
## Weight in grams a genuine version of this item should have.
@export var expected_weight: float = 0.0
## Weight in grams this particular item actually has (for the scale tool later).
@export var actual_weight: float = 0.0
## Street value if the item is genuine.
@export var true_value: int = 0
## Street value if the item turns out to be counterfeit.
@export var counterfeit_value: int = 0

@export_group("Traits")
## Forged maker's mark / signature. Revealed by the UV Blacklight.
@export var has_fake_signature: bool = false
## Whether the item is presented as gold. Only gold items react to the Acid Test.
@export var claims_gold: bool = false
## Whether the gold is genuine. Ignored unless claims_gold is true.
@export var is_real_gold: bool = false
## Stolen goods. Future hook for the Silent Alarm / police system.
@export var is_stolen: bool = false
## What the player notices under the Magnifying Glass (hallmarks, serials, scratches).
@export_multiline var magnifier_note: String = "Nothing unusual up close."


## True if any trait makes this item a fake.
func is_counterfeit() -> bool:
	return has_fake_signature or (claims_gold and not is_real_gold)


## What the item is really worth once all traits are accounted for.
func get_actual_value() -> int:
	return counterfeit_value if is_counterfeit() else true_value
