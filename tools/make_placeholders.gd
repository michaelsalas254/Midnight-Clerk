extends SceneTree
## Writes flat-colour placeholder PNGs for any missing art so the project runs
## before the Higgsfield assets are downloaded.
## Usage: godot --headless --script res://tools/make_placeholders.gd

const PLACEHOLDERS := {
	"res://assets/backgrounds/desk_surface.png": [Vector2i(1344, 752), Color(0.28, 0.18, 0.11), false],
	"res://assets/backgrounds/shop_window.png": [Vector2i(1344, 752), Color(0.12, 0.2, 0.22), false],
	"res://assets/characters/customer_leather_jacket.png": [Vector2i(880, 1168), Color(0.35, 0.3, 0.28), true],
	"res://assets/items/gold_watch.png": [Vector2i(512, 512), Color(0.85, 0.68, 0.2), true],
	"res://assets/items/gold_watch_uv.png": [Vector2i(512, 512), Color(0.3, 1.0, 0.4), true],
	"res://assets/items/gold_chain.png": [Vector2i(512, 512), Color(0.95, 0.75, 0.25), true],
	"res://assets/tools/magnifying_glass.png": [Vector2i(512, 512), Color(0.7, 0.55, 0.3), true],
	"res://assets/tools/uv_blacklight.png": [Vector2i(512, 512), Color(0.3, 0.1, 0.5), true],
	"res://assets/tools/acid_bottle.png": [Vector2i(512, 512), Color(0.45, 0.25, 0.12), true],
}


func _init() -> void:
	for path in PLACEHOLDERS:
		if FileAccess.file_exists(path):
			continue
		var spec: Array = PLACEHOLDERS[path]
		var size: Vector2i = spec[0]
		var img := Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
		if spec[2]:
			# Sprite: a filled ellipse on transparency.
			var c := Vector2(size) / 2.0
			for y in size.y:
				for x in size.x:
					var d := (Vector2(x, y) - c) / (c * 0.8)
					if d.length_squared() <= 1.0:
						img.set_pixel(x, y, spec[1])
		else:
			img.fill(spec[1])
		DirAccess.make_dir_recursive_absolute(path.get_base_dir())
		img.save_png(path)
		print("placeholder: ", path)
	quit()
