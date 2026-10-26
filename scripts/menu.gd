extends Node2D
# EVERYONE DOWN! — main menu.

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.045, 0.07)
	bg.size = Vector2(640, 360)
	add_child(bg)
	var sky := Sprite2D.new()
	sky.texture = load("res://assets/tiles/backdrop.png")
	sky.centered = false
	sky.modulate = Color(0.6, 0.5, 0.55)
	add_child(sky)
	var ground := ColorRect.new()
	ground.color = Color(0.16, 0.10, 0.12)
	ground.position = Vector2(0, 128)
	ground.size = Vector2(640, 232)
	add_child(ground)
	var queen := Sprite2D.new()
	queen.texture = load("res://assets/sprites/queen_0.png")
	queen.centered = false
	queen.position = Vector2(288, 300)
	queen.modulate = Color(1, 1, 1, 0.35)
	add_child(queen)
	var title := Sprite2D.new()
	title.texture = load("res://assets/ui/title.png")
	title.centered = false
	title.position = Vector2((640 - title.texture.get_width()) / 2.0, 70)
	add_child(title)
	var sub := Sprite2D.new()
	sub.texture = load("res://assets/ui/title_sub.png")
	sub.centered = false
	sub.position = Vector2((640 - sub.texture.get_width()) / 2.0, 140)
	add_child(sub)
	_button("res://assets/ui/btn_play.png", 205, func(): get_tree().change_scene_to_file("res://scenes/Game.tscn"))
	_button("res://assets/ui/btn_movie.png", 245, func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	var lb := Button.new()
	lb.text = "LEMMINGS APOCALYPSE  (sign pivot, 2026-10-26)"
	lb.position = Vector2(200, 290)
	lb.size = Vector2(240, 24)
	lb.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Signs.tscn"))
	add_child(lb)
	# little parade of dudes across the bottom
	for i in 6:
		var s := Sprite2D.new()
		s.texture = load("res://assets/sprites/worker_walk_%d.png" % (i % 2))
		s.position = Vector2(-30 - i * 30, 356)
		add_child(s)
		var tw := create_tween().set_loops()
		tw.tween_property(s, "position:x", 700.0, 22.0 + i * 1.5)
		tw.tween_callback(func(): s.position.x = -30)
		var tf := Timer.new()
		tf.wait_time = 0.2
		tf.autostart = true
		s.add_child(tf)
		var st := {"f": 0}
		tf.timeout.connect(func():
			st.f = 1 - st.f
			s.texture = load("res://assets/sprites/worker_walk_%d.png" % st.f))

func _button(tex_path: String, y: float, action: Callable) -> void:
	var b := TextureButton.new()
	b.texture_normal = load(tex_path)
	b.position = Vector2((640 - b.texture_normal.get_width()) / 2.0, y)
	b.pressed.connect(action)
	b.mouse_entered.connect(func(): b.modulate = Color(1.3, 1.2, 1.0))
	b.mouse_exited.connect(func(): b.modulate = Color.WHITE)
	add_child(b)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
		elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			get_tree().change_scene_to_file("res://scenes/Game.tscn")
