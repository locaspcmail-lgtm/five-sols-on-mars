extends SceneTree
## Recorta as 5 imagens de referência do print enviado e salva em res://art/.

func _init() -> void:
	var src := OS.get_environment("SRC_IMG")
	var img := Image.load_from_file(src)
	print("origem: ", img.get_width(), "x", img.get_height())
	var regions := {
		"paineis": Rect2i(28, 38, 727, 406),
		"rover": Rect2i(771, 38, 726, 406),
		"perfuracao": Rect2i(28, 460, 727, 405),
		"base": Rect2i(771, 460, 726, 405),
		"vista": Rect2i(28, 881, 727, 286),
	}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art"))
	for k in regions:
		var r: Rect2i = regions[k]
		var part := img.get_region(r)
		var path := ProjectSettings.globalize_path("res://art/%s.png" % k)
		part.save_png(path)
		print(k, " -> ", part.get_width(), "x", part.get_height())
	quit()
