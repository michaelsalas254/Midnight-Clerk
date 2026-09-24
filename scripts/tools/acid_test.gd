class_name AcidTest
extends InspectionTool
## Drop the bottle onto an item to test its gold. Slides back to the tray.


func _begin_inspecting(item: PawnItemNode) -> void:
	item.apply_acid_test()
