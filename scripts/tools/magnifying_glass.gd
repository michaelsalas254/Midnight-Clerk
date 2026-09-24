class_name MagnifyingGlass
extends InspectionTool
## Hover over an item while held to read its fine details.


func _begin_inspecting(item: PawnItemNode) -> void:
	item.inspect_magnified()
