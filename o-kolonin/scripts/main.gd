extends Node
## Växlar mellan huvudmeny, nationsval och spelvärlden.

const MainMenu = preload("res://scripts/ui/main_menu.gd")
const NationSelect = preload("res://scripts/ui/nation_select.gd")
const World = preload("res://scripts/world/world.gd")
const AutoTest = preload("res://scripts/debug/autotest.gd")

var current: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	randomize()
	# Testläge för utveckling (används bara med argument efter "--").
	var test := AutoTest.new()
	test.main = self
	test.parse()
	if test.active():
		add_child(test)
		test.run()
		return
	show_menu()


func _swap(n: Node) -> void:
	if current != null:
		current.queue_free()
	current = n
	add_child(n)


func show_menu() -> void:
	var m := MainMenu.new()
	m.main = self
	_swap(m)


func show_select() -> void:
	var s := NationSelect.new()
	s.main = self
	_swap(s)


func start_game(settings: Dictionary) -> void:
	Game.new_game(settings)
	var w := World.new()
	w.process_mode = Node.PROCESS_MODE_PAUSABLE
	w.ended.connect(_on_ended)
	_swap(w)


func _on_ended(_why: String) -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	Game.world = null
	show_menu()
