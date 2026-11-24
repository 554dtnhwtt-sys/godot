extends SceneTree
## Utvecklingsverktyg: laddar alla skript och skriver ut vilka som inte går att kompilera.

func _init() -> void:
	for f in ["res://scripts/ui/res_icon.gd", "res://scripts/world/governor.gd", "res://scripts/world/island.gd", "res://scripts/world/building.gd", "res://scripts/world/overlay.gd", "res://scripts/ui/hud.gd", "res://scripts/world/world.gd"]:
		var s = load(f)
		print(f, " -> ", "OK" if s != null and s.can_instantiate() else "FEL")
	quit()
