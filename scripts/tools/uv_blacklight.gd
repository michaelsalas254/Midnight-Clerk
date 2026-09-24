class_name UVBlacklight
extends InspectionTool
## Shines while held. Any item under the beam is told it is exposed to UV;
## the item decides whether that reveals anything (see PawnItemNode).

@onready var beam: Sprite2D = $Sensor/Beam


func _begin_inspecting(item: PawnItemNode) -> void:
	item.set_uv_exposure(true)


func _end_inspecting(item: PawnItemNode) -> void:
	item.set_uv_exposure(false)


func _set_active_visuals(active: bool) -> void:
	beam.visible = active
