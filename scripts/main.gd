extends Node2D
# EVERYONE DOWN! — staged demo director.
# One script builds the world and plays 6 cinematic beats. SPACE = next beat, ESC = quit.

const T := 16
const TW := 40
const TH := 72
const AIR := 0
const DIRT := 1
const ROCK := 2
const IRON := 3
const RARE := 4
const WATER := 5
const TROG := 6
const DUG := 7
const SURF := 8

var grid := []                 # grid[y][x] int codes
var terrain_img: Image
var terrain_tex: ImageTexture
var cave_img: Image
var tile_imgs := {}            # code -> Array[Image]
var water_cells := []          # for ripple animation
var water_frame := 0

var cam: Camera2D
var canvas_mod: CanvasModulate
var world: Node2D
var bld_layer: Node2D
var actor_layer: Node2D
var fx_layer: Node2D
var light_layer: Node2D
var marker_layer: Node2D

# UI
var ui: CanvasLayer
var bar_top: ColorRect
var bar_bot: ColorRect
var caption: TextureRect
var hint: TextureRect
var title_node: Control
var chips := {}
var seismo: Control
var flash_rect: ColorRect

# demo state
var beat := 0
var beat_clock := 0.0
var events := []               # [{t, fn, done}]
var beat_tweens := []
var pop_top := 500
var pop_below := 0
var stat_food := 0
var stat_power := 0
var stat_iron := 0
var stat_rare := 0
var seismo_intensity := 0.15
var shake_amt := 0.0
var dudes := []
var trogs := []
var buildings := {}
var trog_cells := []           # carved enemy tunnel cells
var sfx := {}
var auto_advance := true
var shots_mode := false
var record_mode := false

# ---------------------------------------------------------------- SETUP

func _ready() -> void:
	shots_mode = "--shots" in OS.get_cmdline_user_args()
	record_mode = "--record" in OS.get_cmdline_user_args()
	_load_tiles()
	_build_grid()
	_build_layers()
	_render_terrain()
	_build_lights()
	_build_ui()
	_build_audio()
	_start_beat(1)

func _load_tiles() -> void:
	tile_imgs[DIRT] = _imgs("res://assets/tiles/dirt_%d.png", 4)
	tile_imgs[DUG] = _imgs("res://assets/tiles/cave_%d.png", 4)
	tile_imgs[ROCK] = _imgs("res://assets/tiles/rock_%d.png", 4)
	tile_imgs[SURF] = _imgs("res://assets/tiles/surface_%d.png", 4)
	tile_imgs[TROG] = _imgs("res://assets/tiles/trog_%d.png", 4)
	tile_imgs[IRON] = _imgs("res://assets/tiles/iron_%d.png", 2)
	tile_imgs[RARE] = _imgs("res://assets/tiles/rare_%d.png", 2)
	tile_imgs[WATER] = _imgs("res://assets/tiles/water_%d.png", 3)

func _imgs(pattern: String, n: int) -> Array:
	var out := []
	for i in n:
		out.append(load(pattern % i).get_image())
	return out

func _build_grid() -> void:
	for y in TH:
		var row := []
		for x in TW:
			if y < 8:
				row.append(AIR)
			elif y == 8:
				row.append(SURF)
			else:
				row.append(DIRT)
		grid.append(row)
	# rock blobs (deterministic scatter)
	var rocks := [Vector2i(5, 14), Vector2i(31, 12), Vector2i(3, 30), Vector2i(34, 26),
		Vector2i(8, 44), Vector2i(30, 40), Vector2i(14, 55), Vector2i(26, 58), Vector2i(6, 62)]
	for r in rocks:
		for dy in range(-1, 3):
			for dx in range(-2, 3):
				if abs(dx) + abs(dy) < 4:
					_set_cell(r.x + dx, r.y + dy, ROCK)
	# water pockets (schematic: scattered short lakes)
	var lakes := [[6, 17, 4], [23, 17, 5], [12, 28, 4], [31, 33, 4], [5, 38, 3], [22, 44, 5], [33, 50, 3], [10, 50, 4]]
	for l in lakes:
		for i in l[2]:
			_set_cell(l[0] + i, l[1], WATER)
			water_cells.append(Vector2i(l[0] + i, l[1]))
	# iron clusters (mid depth)
	for c in [Vector2i(9, 20), Vector2i(28, 22), Vector2i(15, 34), Vector2i(33, 38), Vector2i(7, 33)]:
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 2)]:
			_set_cell(c.x + d.x, c.y + d.y, IRON)
	# rare metal (deep)
	for c in [Vector2i(12, 52), Vector2i(27, 50), Vector2i(18, 60), Vector2i(31, 60), Vector2i(8, 58)]:
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			_set_cell(c.x + d.x, c.y + d.y, RARE)
	# bedrock bases: every feature (lake, vent, ore) anchors into indestructible rock
	for l in lakes:
		for i in l[2]:
			_set_cell(l[0] + i, l[1] + 1, ROCK)
	for v in [Vector2i(9, 24), Vector2i(27, 46)]:
		for dx in range(-1, 3):
			_set_cell(v.x + dx, v.y, ROCK)
	# initial trog warren: winding tunnels from the queen upward
	_carve_trog_warren()

func _carve_trog_warren() -> void:
	# queen chamber
	for y in range(65, 70):
		for x in range(14, 27):
			_set_cell(x, y, TROG)
	# three winding branches climbing to ~row 52
	var seeds := [[16, 65, -1], [20, 65, 0], [25, 65, 1]]
	for s in seeds:
		var x: int = s[0]
		var drift: int = s[2]
		for y in range(65, 52, -1):
			_set_cell(x, y, TROG)
			_set_cell(x + 1, y, TROG)
			trog_cells.append(Vector2i(x, y))
			if (y * 7 + x) % 3 == 0:
				x = clampi(x + (1 if drift >= 0 else -1), 3, TW - 4)
			elif (y * 5 + x) % 4 == 0:
				x = clampi(x + drift, 3, TW - 4)

func _set_cell(x: int, y: int, v: int) -> void:
	if x >= 0 and x < TW and y >= 0 and y < TH:
		grid[y][x] = v

func _build_layers() -> void:
	world = Node2D.new()
	add_child(world)
	# sky backdrop
	var sky := Sprite2D.new()
	sky.texture = load("res://assets/tiles/backdrop.png")
	sky.centered = false
	sky.position = Vector2(0, -12)
	world.add_child(sky)
	# cave background under terrain
	cave_img = Image.create(TW * T, TH * T, false, Image.FORMAT_RGBA8)
	for y in range(8, TH):
		for x in TW:
			cave_img.blit_rect(tile_imgs[DUG][(x * 7 + y * 13) % 4], Rect2i(0, 0, T, T), Vector2i(x * T, y * T))
	var cave_spr := Sprite2D.new()
	cave_spr.texture = ImageTexture.create_from_image(cave_img)
	cave_spr.centered = false
	world.add_child(cave_spr)
	# terrain
	terrain_img = Image.create(TW * T, TH * T, false, Image.FORMAT_RGBA8)
	terrain_tex = ImageTexture.create_from_image(terrain_img)
	var terr_spr := Sprite2D.new()
	terr_spr.texture = terrain_tex
	terr_spr.centered = false
	world.add_child(terr_spr)
	marker_layer = Node2D.new()
	world.add_child(marker_layer)
	bld_layer = Node2D.new()
	world.add_child(bld_layer)
	actor_layer = Node2D.new()
	world.add_child(actor_layer)
	fx_layer = Node2D.new()
	world.add_child(fx_layer)
	light_layer = Node2D.new()
	world.add_child(light_layer)
	# world features
	_spawn_feature("res://assets/sprites/shaft_head.png", Vector2(304, 8 * T - 24), "shaft_head")
	_spawn_anim_feature(["res://assets/sprites/vent_0.png", "res://assets/sprites/vent_1.png"], Vector2(9 * T, 23 * T), 0.5)
	_spawn_anim_feature(["res://assets/sprites/vent_0.png", "res://assets/sprites/vent_1.png"], Vector2(27 * T, 45 * T), 0.6)
	_spawn_anim_feature(["res://assets/sprites/queen_0.png", "res://assets/sprites/queen_1.png"], Vector2(13 * T, 68 * T - 16), 0.8)
	# camera
	cam = Camera2D.new()
	cam.position = Vector2(320, 92)
	cam.limit_left = 0
	cam.limit_right = TW * T
	cam.limit_top = -20
	cam.limit_bottom = TH * T
	add_child(cam)
	cam.make_current()
	# global gloom (lights punch through)
	canvas_mod = CanvasModulate.new()
	canvas_mod.color = Color(0.47, 0.44, 0.52)
	add_child(canvas_mod)

func _spawn_feature(path: String, pos: Vector2, _name: String) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	s.position = pos
	bld_layer.add_child(s)
	return s

func _spawn_anim_feature(paths: Array, pos: Vector2, period: float) -> Sprite2D:
	var s := _spawn_feature(paths[0], pos, "")
	var frames := []
	for p in paths:
		frames.append(load(p))
	var t := Timer.new()
	t.wait_time = period
	t.autostart = true
	s.add_child(t)
	var state := {"i": 0}
	t.timeout.connect(func():
		state.i = (state.i + 1) % frames.size()
		s.texture = frames[state.i])
	return s

func _render_terrain() -> void:
	for y in TH:
		for x in TW:
			_paint_cell(x, y)
	terrain_tex.update(terrain_img)

func _paint_cell(x: int, y: int) -> void:
	var v: int = grid[y][x]
	var rect := Rect2i(0, 0, T, T)
	var dst := Vector2i(x * T, y * T)
	if v == AIR or v == DUG:
		terrain_img.fill_rect(Rect2i(dst.x, dst.y, T, T), Color(0, 0, 0, 0))
		return
	var variants: Array = tile_imgs[v]
	var img: Image = variants[(x * 7 + y * 13) % variants.size()]
	if v == WATER:
		img = variants[water_frame]
	terrain_img.blit_rect(img, rect, dst)

func _update_cells(cells: Array) -> void:
	for c in cells:
		_paint_cell(c.x, c.y)
	terrain_tex.update(terrain_img)

# ---------------------------------------------------------------- LIGHTS

var light_tex: Texture2D

func _build_lights() -> void:
	light_tex = load("res://assets/fx/light_halo.png")
	# topside: big dim apocalyptic warmth
	_add_light(Vector2(320, 30), 9.0, Color(1.0, 0.62, 0.42), 0.9)
	# shaft head lamp
	_add_light(Vector2(320, 118), 1.6, Color(1.0, 0.85, 0.6), 1.0)

func _add_light(pos: Vector2, sc: float, col: Color, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_tex
	l.position = pos
	l.texture_scale = sc
	l.color = col
	l.energy = energy
	light_layer.add_child(l)
	return l

# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	ui = CanvasLayer.new()
	add_child(ui)
	bar_top = ColorRect.new()
	bar_top.color = Color(0.05, 0.035, 0.05)
	bar_top.position = Vector2(0, 0)
	bar_top.size = Vector2(640, 26)
	ui.add_child(bar_top)
	bar_bot = ColorRect.new()
	bar_bot.color = Color(0.05, 0.035, 0.05)
	bar_bot.position = Vector2(0, 334)
	bar_bot.size = Vector2(640, 26)
	ui.add_child(bar_bot)
	# HUD chips (under top bar)
	var defs := [["pop", "res://assets/ui/ic_pop.png"], ["below", "res://assets/ui/ic_below.png"],
		["food", "res://assets/ui/ic_food.png"], ["power", "res://assets/ui/ic_power.png"],
		["iron", "res://assets/ui/ic_iron.png"], ["rare", "res://assets/ui/ic_rare.png"]]
	var x := 6.0
	for d in defs:
		var chip := UIChip.new()
		chip.icon = load(d[1])
		chip.digits = load("res://assets/ui/digits.png")
		chip.chip_bg = load("res://assets/ui/chip.png")
		chip.position = Vector2(x, 30)
		ui.add_child(chip)
		chips[d[0]] = chip
		x += 50
	chips["pop"].value = pop_top
	# seismograph top-right
	seismo = Seismo.new()
	seismo.panel = load("res://assets/ui/seismo.png")
	seismo.lbl = load("res://assets/ui/lbl_swarm.png")
	seismo.digits = load("res://assets/ui/digits.png")
	seismo.position = Vector2(640 - 98, 30)
	ui.add_child(seismo)
	# caption + hint
	caption = TextureRect.new()
	caption.modulate.a = 0.0
	ui.add_child(caption)
	hint = TextureRect.new()
	hint.texture = load("res://assets/ui/cap_hint.png")
	hint.scale = Vector2(0.5, 0.5)
	hint.position = Vector2(640 - 130, 344)
	hint.modulate.a = 0.55
	ui.add_child(hint)
	# flash overlay
	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 0.95, 0.85, 0)
	flash_rect.size = Vector2(640, 360)
	ui.add_child(flash_rect)
	# title (hidden)
	title_node = Control.new()
	title_node.visible = false
	ui.add_child(title_node)
	var tt := TextureRect.new()
	tt.texture = load("res://assets/ui/title.png")
	title_node.add_child(tt)
	var ts := TextureRect.new()
	ts.texture = load("res://assets/ui/title_sub.png")
	title_node.add_child(ts)
	var tw: float = tt.texture.get_width()
	tt.position = Vector2((640 - tw) / 2.0, 130)
	ts.position = Vector2((640 - ts.texture.get_width()) / 2.0, 200)

func _set_caption(idx: int) -> void:
	var tex: Texture2D = load("res://assets/ui/cap_%d.png" % idx)
	caption.texture = tex
	caption.position = Vector2((640 - tex.get_width()) / 2.0, 336)
	caption.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(caption, "modulate:a", 1.0, 0.6)
	beat_tweens.append(tw)

class UIChip extends Control:
	var icon: Texture2D
	var digits: Texture2D
	var chip_bg: Texture2D
	var value: int = 0:
		set(v):
			value = v
			queue_redraw()
	func _draw() -> void:
		draw_texture(chip_bg, Vector2.ZERO)
		draw_texture(icon, Vector2(3, 2))
		var s := str(value)
		var x := 42.0 - s.length() * 5.0
		for ch in s:
			var i := "0123456789/:".find(ch)
			draw_texture_rect_region(digits, Rect2(x, 3, 5, 7), Rect2(i * 4, 0, 5, 7))
			x += 5.0

class Seismo extends Control:
	var panel: Texture2D
	var lbl: Texture2D
	var digits: Texture2D
	var intensity := 0.15
	var phase := 0.0
	var countdown := -1     # seconds; -1 hidden
	func _process(delta: float) -> void:
		phase += delta * (2.0 + intensity * 14.0)
		queue_redraw()
	func _draw() -> void:
		draw_texture(panel, Vector2.ZERO)
		var pts := PackedVector2Array()
		for i in range(0, 84, 2):
			var t := phase + i * 0.31
			var a: float = sin(t) * 0.5 + sin(t * 2.7) * 0.3 + sin(t * 6.1) * 0.2
			a *= intensity * 6.5
			pts.append(Vector2(4 + i, 11 + a))
		draw_polyline(pts, Color(1.0, 0.45, 0.28), 1.0)
		draw_texture(lbl, Vector2(4, 20), Color(1, 1, 1, 0.9))
		if countdown >= 0:
			var s := "%d" % countdown
			var x := 84.0 - s.length() * 5.0
			for ch in s:
				var i := "0123456789/:".find(ch)
				draw_texture_rect_region(digits, Rect2(x, 20, 5, 7), Rect2(i * 4, 0, 5, 7))
				x += 5.0

# ---------------------------------------------------------------- AUDIO

func _build_audio() -> void:
	for n in ["dig", "pop", "blip", "gun", "roar", "heart", "squeak", "meteor", "drone", "steam"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/audio/%s.wav" % n)
		add_child(p)
		sfx[n] = p
	sfx["blip"].volume_db = -16
	sfx["dig"].volume_db = -8
	sfx["gun"].volume_db = -10
	sfx["squeak"].volume_db = -8
	sfx["drone"].volume_db = -14
	sfx["steam"].volume_db = -16
	for n in ["drone", "steam"]:
		var st: AudioStreamWAV = sfx[n].stream
		st.loop_mode = AudioStreamWAV.LOOP_FORWARD
		st.loop_end = st.data.size() / 2

func _play(n: String) -> void:
	if sfx.has(n):
		sfx[n].play()

# ---------------------------------------------------------------- ACTORS

class Actor extends Node2D:
	var spr: Sprite2D
	var frames := {}          # state -> Array[Texture2D]
	var state := "idle"
	var fi := 0
	var ft := 0.0
	var fps := 6.0
	var waypoints := []
	var speed := 42.0
	var on_arrive: Callable
	func setup(frame_defs: Dictionary) -> void:
		spr = Sprite2D.new()
		for k in frame_defs:
			var arr := []
			for p in frame_defs[k]:
				arr.append(load(p))
			frames[k] = arr
		add_child(spr)
		_apply()
	func set_state(s: String) -> void:
		if state != s and frames.has(s):
			state = s
			fi = 0
			_apply()
	func _apply() -> void:
		spr.texture = frames[state][fi % frames[state].size()]
		spr.offset = Vector2(-spr.texture.get_width() / 2.0, -float(spr.texture.get_height()))
	func _process(delta: float) -> void:
		ft += delta
		if ft > 1.0 / fps:
			ft = 0.0
			fi += 1
			_apply()
		if waypoints.size() > 0:
			var tgt: Vector2 = waypoints[0]
			var d := tgt - position
			if d.length() < 2.0:
				waypoints.pop_front()
				if waypoints.is_empty():
					if on_arrive.is_valid():
						var cb := on_arrive
						on_arrive = Callable()
						cb.call()
			else:
				var step := d.normalized() * speed * delta
				position += step
				if abs(d.x) > 1.0:
					spr.flip_h = d.x < 0

func _spawn_dude(pos: Vector2, kind: String = "worker") -> Actor:
	var a := Actor.new()
	a.position = pos
	actor_layer.add_child(a)
	if kind == "soldier":
		a.setup({"idle": ["res://assets/sprites/soldier_0.png"],
			"walk": ["res://assets/sprites/soldier_0.png", "res://assets/sprites/soldier_1.png"],
			"shoot": ["res://assets/sprites/soldier_1.png", "res://assets/sprites/soldier_0.png"]})
	else:
		var w := "worker" if kind == "worker" else "free"
		a.setup({"idle": ["res://assets/sprites/%s_walk_0.png" % w],
			"walk": ["res://assets/sprites/%s_walk_0.png" % w, "res://assets/sprites/%s_walk_1.png" % w],
			"dig": ["res://assets/sprites/worker_dig_0.png", "res://assets/sprites/worker_dig_1.png"]})
	dudes.append(a)
	return a

func _spawn_trog(pos: Vector2, big: bool = false) -> Actor:
	var a := Actor.new()
	a.position = pos
	a.speed = 65.0
	actor_layer.add_child(a)
	var n := "trog_big" if big else "trog"
	a.setup({"idle": ["res://assets/sprites/%s_0.png" % n],
		"walk": ["res://assets/sprites/%s_0.png" % n, "res://assets/sprites/%s_1.png" % n]})
	a.fps = 8.0
	trogs.append(a)
	return a

func _wander_topside(a: Actor) -> void:
	if not is_instance_valid(a) or a.state == "gone":
		return
	var x := 90.0 + fmod(absf(a.position.x * 31.7 + randf() * 400.0), 440.0)
	a.waypoints = [Vector2(x, 8 * T)]
	a.set_state("walk")
	a.on_arrive = func():
		a.set_state("idle")
		var t := get_tree().create_timer(0.6 + randf() * 1.6)
		t.timeout.connect(func(): _wander_topside(a))

# ---------------------------------------------------------------- FX

func puff(pos: Vector2, col: Color, amount: int = 10, spread: float = 8.0) -> void:
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = amount
	p.one_shot = true
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = 18.0
	p.initial_velocity_max = 46.0
	p.gravity = Vector2(0, 130)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.4
	p.color = col
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = spread
	fx_layer.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(func(): if is_instance_valid(p): p.queue_free())

func shake(amt: float) -> void:
	shake_amt = maxf(shake_amt, amt)

func flash(a: float = 0.85, dur: float = 0.35) -> void:
	flash_rect.color.a = a
	var tw := create_tween()
	tw.tween_property(flash_rect, "color:a", 0.0, dur)
	beat_tweens.append(tw)

func noise_ring(pos: Vector2, max_r: float = 90.0) -> void:
	var ring := NoiseRing.new()
	ring.position = pos
	ring.max_r = max_r
	fx_layer.add_child(ring)

class NoiseRing extends Node2D:
	var r := 4.0
	var max_r := 90.0
	func _process(delta: float) -> void:
		r += delta * 55.0
		if r > max_r:
			queue_free()
		queue_redraw()
	func _draw() -> void:
		var a := clampf(1.0 - r / max_r, 0.0, 1.0) * 0.7
		draw_arc(Vector2.ZERO, r, 0, TAU, 40, Color(1, 1, 0.9, a), 1.0)

# ---------------------------------------------------------------- WORLD OPS

func carve(cells: Array, kind: int = DUG, fx_puffs: bool = true) -> void:
	for c in cells:
		if grid[c.y][c.x] != ROCK:
			grid[c.y][c.x] = kind
	_update_cells(cells)
	if fx_puffs and cells.size() > 0:
		var c: Vector2i = cells[0]
		var col := Color(0.55, 0.38, 0.25) if kind == DUG else Color(0.55, 0.16, 0.2)
		puff(Vector2(c.x * T + 8, c.y * T + 8), col, 8)

func place_building(key: String, base: String, pos: Vector2, lit_light_scale: float = 1.6) -> void:
	if buildings.has(key):
		return
	var s := Sprite2D.new()
	s.texture = load("res://assets/sprites/%s_1_0.png" % base) if base.begins_with("bld_") and not base in ["bld_barricade"] else load("res://assets/sprites/%s.png" % base)
	s.centered = false
	s.position = pos
	bld_layer.add_child(s)
	var entry := {"node": s, "base": base, "on": true, "frame": 0, "light": null}
	# working animation flip
	if base != "bld_barricade":
		var t := Timer.new()
		t.wait_time = 0.55
		t.autostart = true
		s.add_child(t)
		t.timeout.connect(func():
			if entry.on:
				entry.frame = 1 - entry.frame
				var p := "res://assets/sprites/%s_1_%d.png" % [entry.base, entry.frame]
				if ResourceLoader.exists(p):
					s.texture = load(p))
		var l := _add_light(pos + Vector2(s.texture.get_width() / 2.0, s.texture.get_height() / 2.0), lit_light_scale, Color(1.0, 0.83, 0.55), 1.0)
		l.energy = 0.0
		var tw := create_tween()
		tw.tween_property(l, "energy", 1.15, 1.2)
		beat_tweens.append(tw)
		entry.light = l
	buildings[key] = entry
	# pop-in
	s.scale = Vector2(1.0, 0.1)
	var tw2 := create_tween()
	tw2.tween_property(s, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	beat_tweens.append(tw2)
	puff(pos + Vector2(s.texture.get_width() / 2.0, s.texture.get_height() - 2.0), Color(0.6, 0.45, 0.3), 14, 12.0)
	_play("pop")

func set_building_on(key: String, on: bool) -> void:
	if not buildings.has(key):
		return
	var b: Dictionary = buildings[key]
	b.on = on
	var p := "res://assets/sprites/%s_%d_0.png" % [b.base, 1 if on else 0]
	if ResourceLoader.exists(p):
		b.node.texture = load(p)
	if b.light != null:
		b.light.energy = 1.15 if on else 0.0

# ---------------------------------------------------------------- DIRECTOR CORE

func ev(t: float, fn: Callable) -> void:
	events.append({"t": t, "fn": fn, "done": false})

func every(t0: float, interval: float, count: int, fn: Callable) -> void:
	for i in count:
		ev(t0 + interval * i, fn)

func _process(delta: float) -> void:
	beat_clock += delta
	for e in events:
		if not e.done and beat_clock >= e.t:
			e.done = true
			e.fn.call()
	# camera shake decay
	if shake_amt > 0.01:
		cam.offset = Vector2(randf_range(-shake_amt, shake_amt), randf_range(-shake_amt, shake_amt))
		shake_amt *= pow(0.02, delta)
	else:
		cam.offset = Vector2.ZERO
	# water ripple
	_water_tick(delta)
	seismo.intensity = seismo_intensity

var _wt := 0.0
func _water_tick(delta: float) -> void:
	_wt += delta
	if _wt > 0.28:
		_wt = 0.0
		water_frame = (water_frame + 1) % 3
		var dirty := []
		for c in water_cells:
			if grid[c.y][c.x] == WATER:
				dirty.append(c)
		_update_cells(dirty)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE:
			_start_beat(beat + 1 if beat < 6 else 1)
		elif event.keycode == KEY_ESCAPE:
			get_tree().change_scene_to_file("res://scenes/Menu.tscn")

func _clear_beat() -> void:
	events.clear()
	for tw in beat_tweens:
		if tw is Tween and tw.is_valid():
			tw.kill()
	beat_tweens.clear()
	beat_clock = 0.0

func cam_to(pos: Vector2, zoom: float, dur: float) -> void:
	var tw := create_tween().set_parallel(true)
	tw.tween_property(cam, "position", pos, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(cam, "zoom", Vector2(zoom, zoom), dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	beat_tweens.append(tw)

func _start_beat(n: int) -> void:
	_clear_beat()
	beat = n
	match n:
		1: _beat1()
		2: _beat2()
		3: _beat3()
		4: _beat4()
		5: _beat5()
		6: _beat6()
	if shots_mode:
		var snap_t: float = [0.0, 4.0, 12.5, 16.0, 14.0, 9.0, 7.4][n]
		ev(snap_t, func(): _snap(n))
		ev(snap_t + 0.6, func(): _start_beat(n + 1) if n < 6 else get_tree().quit())
	elif auto_advance and n < 6:
		ev(_beat_len(n), func(): _start_beat(n + 1))

func _beat_len(n: int) -> float:
	return [0.0, 13.0, 15.0, 26.0, 17.0, 20.0, 999.0][n]

func _snap(n: int) -> void:
	var img := get_viewport().get_texture().get_image()
	var dir := ProjectSettings.globalize_path("res://tools/shots")
	DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(dir + "/beat_%d.png" % n)

# ---------------------------------------------------------------- BEATS

func _reset_world_soft() -> void:
	# used when looping back to beat 1
	for a in dudes: a.queue_free()
	for a in trogs: a.queue_free()
	dudes.clear()
	trogs.clear()
	pop_top = 500
	pop_below = 0
	chips["pop"].value = pop_top
	chips["below"].value = 0

func _beat1() -> void:
	if pop_top < 500:
		_reset_world_soft()
	title_node.visible = false
	sfx["drone"].play()
	cam.position = Vector2(320, 92)
	cam.zoom = Vector2.ONE
	seismo_intensity = 0.12
	_set_caption(1)
	# crowd topside
	for i in 26:
		var d := _spawn_dude(Vector2(100 + (i * 67) % 440, 8 * T), "free" if i % 3 == 0 else "worker")
		_wander_topside(d)
	# survivor countdown ticks
	every(0.8, 0.55, 20, func():
		pop_top -= 1
		chips["pop"].value = pop_top
		_play("blip"))
	# meteors
	every(1.0, 2.3, 6, func():
		var mx := 80.0 + randf() * 480.0
		var m := Sprite2D.new()
		m.texture = load("res://assets/fx/meteor.png")
		m.position = Vector2(mx + 90, -40)
		fx_layer.add_child(m)
		_play("meteor")
		var tw := create_tween()
		tw.tween_property(m, "position", Vector2(mx, 8 * T - 4), 0.55)
		tw.tween_callback(func():
			puff(m.position, Color(0.95, 0.5, 0.2), 18, 6.0)
			shake(3.5)
			m.queue_free())
		beat_tweens.append(tw))

func _shaft_cells(rows: Array) -> Array:
	var out := []
	for y in rows:
		out.append(Vector2i(19, y))
		out.append(Vector2i(20, y))
	return out

func _beat2() -> void:
	_set_caption(2)
	cam_to(Vector2(320, 210), 1.5, 2.0)
	seismo_intensity = 0.18
	# glowing dig markers appear down the shaft
	var markers := []
	for y in range(9, 22):
		var mk := ColorRect.new()
		mk.color = Color(1.0, 0.85, 0.4, 0.0)
		mk.position = Vector2(19 * T, y * T)
		mk.size = Vector2(2 * T, T)
		marker_layer.add_child(mk)
		markers.append(mk)
	for i in markers.size():
		var mk: ColorRect = markers[i]
		ev(0.5 + i * 0.12, func():
			mk.color.a = 0.45
			var tw := create_tween()
			tw.tween_property(mk, "color:a", 0.15, 0.5)
			beat_tweens.append(tw))
	# diggers descend the shaft, carving cell rows
	for i in range(9, 22):
		var y := i
		ev(2.0 + (i - 9) * 0.75, func():
			carve(_shaft_cells([y]))
			_play("dig")
			shake(1.2)
			if y < 21:
				pass)
	# two dig dudes riding the head of the tunnel
	ev(2.0, func():
		for k in 2:
			var d := _spawn_dude(Vector2(310 + k * 14, 8 * T), "worker")
			d.set_state("dig")
			var tw := create_tween()
			tw.tween_property(d, "position:y", 21.0 * T, 9.7)
			beat_tweens.append(tw))
	ev(3.0, func():
		for mk in markers:
			if is_instance_valid(mk):
				var tw := create_tween()
				tw.tween_property(mk, "color:a", 0.0, 4.0)
				tw.tween_callback(mk.queue_free)
				beat_tweens.append(tw))
	# dirt particles at tunnel head follow
	every(2.2, 0.75, 12, func():
		var head_y := clampi(9 + int((beat_clock - 2.0) / 0.75), 9, 21)
		puff(Vector2(320, head_y * T + 8), Color(0.55, 0.38, 0.25), 7))

func _rooms_cells() -> Dictionary:
	var living := []
	for y in range(13, 17):
		for x in range(11, 19):
			living.append(Vector2i(x, y))
	var farm := []
	for y in range(13, 17):
		for x in range(21, 29):
			farm.append(Vector2i(x, y))
	var hall := []
	for y in range(20, 24):
		for x in range(7, 30):
			hall.append(Vector2i(x, y))
	var links := []
	for y in range(17, 20):
		links.append(Vector2i(19, y))
		links.append(Vector2i(20, y))
	return {"living": living, "farm": farm, "hall": hall, "links": links}

func _force_dug_through_b2() -> void:
	carve(_shaft_cells(range(9, 22)), DUG, false)

func _beat3() -> void:
	_force_dug_through_b2()
	_set_caption(3)
	cam_to(Vector2(320, 270), 1.35, 3.0)
	sfx["steam"].play()
	seismo_intensity = 0.24
	var rooms := _rooms_cells()
	# carve rooms in waves (timelapse)
	var seq := [["living", 1.0], ["farm", 3.2], ["links", 5.4], ["hall", 6.4]]
	for s in seq:
		var cells: Array = rooms[s[0]]
		var t0: float = s[1]
		var chunk := 6
		var i := 0
		while i < cells.size():
			var slice := cells.slice(i, i + chunk)
			ev(t0 + (i / float(chunk)) * 0.22, func():
				carve(slice)
				if randf() < 0.4:
					_play("dig"))
			i += chunk
	# buildings pop in as rooms complete
	ev(4.2, func(): place_building("living", "bld_living", Vector2(12 * T, 17 * T - 32), 2.2))
	ev(6.0, func(): place_building("farm", "bld_farm", Vector2(22 * T, 17 * T - 24), 1.8))
	ev(9.0, func(): place_building("power", "bld_power", Vector2(8 * T, 24 * T - 40), 2.0))
	ev(10.5, func(): place_building("lab1", "bld_lab1", Vector2(15 * T, 24 * T - 32), 1.6))
	ev(11.5, func(): place_building("armory", "bld_armory", Vector2(24 * T, 24 * T - 24), 1.6))
	# people stream down and man the base
	var stations := [Vector2(14 * T, 17 * T), Vector2(24 * T, 17 * T), Vector2(9 * T + 8, 24 * T),
		Vector2(16 * T, 24 * T), Vector2(25 * T, 24 * T), Vector2(12 * T, 17 * T), Vector2(27 * T, 17 * T), Vector2(20 * T, 24 * T)]
	for i in 14:
		ev(4.5 + i * 1.1, func():
			var d := _spawn_dude(Vector2(316, 8 * T), "worker")
			var st: Vector2 = stations[i % stations.size()]
			d.set_state("walk")
			d.waypoints = [Vector2(316, 8 * T), Vector2(318, st.y), st]
			d.on_arrive = func(): d.set_state("idle")
			pop_top -= 1
			pop_below += 1
			chips["pop"].value = pop_top
			chips["below"].value = pop_below
			_play("blip"))
	# counters warm up as buildings come online
	ev(6.5, func(): _count_to("food", 60, 3.0))
	ev(9.5, func(): _count_to("power", 80, 3.0))
	ev(12.0, func(): _count_to("iron", 35, 6.0))

func _count_to(key: String, target: int, dur: float) -> void:
	var chip: UIChip = chips[key]
	var steps := 20
	for i in steps:
		ev(beat_clock + dur * i / steps, func():
			chip.value = int(target * (i + 1) / float(steps)))

func _force_state_b3() -> void:
	_force_dug_through_b2()
	var rooms := _rooms_cells()
	for k in rooms:
		carve(rooms[k], DUG, false)
	place_building("living", "bld_living", Vector2(12 * T, 17 * T - 32), 2.2)
	place_building("farm", "bld_farm", Vector2(22 * T, 17 * T - 24), 1.8)
	place_building("power", "bld_power", Vector2(8 * T, 24 * T - 40), 2.0)
	place_building("lab1", "bld_lab1", Vector2(15 * T, 24 * T - 32), 1.6)
	place_building("armory", "bld_armory", Vector2(24 * T, 24 * T - 24), 1.6)
	pop_top = 460
	pop_below = 26
	chips["pop"].value = pop_top
	chips["below"].value = pop_below
	chips["food"].value = 60
	chips["power"].value = 80
	chips["iron"].value = 35

func _deep_cells() -> Array:
	var out := []
	for y in range(24, 42):
		out.append(Vector2i(19, y))
		out.append(Vector2i(20, y))
	for y in range(38, 42):
		for x in range(15, 25):
			out.append(Vector2i(x, y))
	return out

func _beat4() -> void:
	_force_state_b3()
	carve(_deep_cells(), DUG, false)
	place_building("lab2", "bld_lab2", Vector2(16 * T, 42 * T - 32), 1.8)
	_set_caption(4)
	cam_to(Vector2(320, 660), 1.15, 3.5)
	seismo_intensity = 0.45
	sfx["heart"].play()
	every(2.0, 2.0, 8, func(): _play("heart"))
	# mining crew in the deep room
	for k in 3:
		var d := _spawn_dude(Vector2((16 + k * 3) * T, 42 * T), "worker")
		d.set_state("dig")
	# noise rings from the deep lab
	every(1.5, 2.4, 7, func():
		noise_ring(Vector2(18 * T, 41 * T), 150.0)
		_play("dig"))
	# trog tunnels creep upward in response
	var creeps := []
	var heads := [Vector2i(16, 52), Vector2i(21, 52), Vector2i(26, 53)]
	for h in 3:
		for step in 9:
			var hh := h
			var st := step
			ev(3.0 + step * 1.1 + h * 0.35, func():
				var head: Vector2i = heads[hh]
				var nx := clampi(head.x + [(-1), 0, 1][(head.y + hh) % 3], 3, TW - 4)
				var ny := head.y - 1
				heads[hh] = Vector2i(nx, ny)
				carve([Vector2i(nx, ny), Vector2i(nx + 1, ny)], TROG)
				trog_cells.append(Vector2i(nx, ny))
				shake(0.6)
				seismo_intensity = minf(0.9, seismo_intensity + 0.02))
	# glowing eyes blink inside their tunnels
	every(4.0, 1.6, 8, func():
		var c: Vector2i = trog_cells[randi() % trog_cells.size()]
		var e := Sprite2D.new()
		e.texture = load("res://assets/sprites/trog_0.png")
		e.modulate = Color(1, 1, 1, 0.0)
		e.position = Vector2(c.x * T + 8, c.y * T + 14)
		actor_layer.add_child(e)
		var tw := create_tween()
		tw.tween_property(e, "modulate:a", 0.9, 0.4)
		tw.tween_interval(0.5)
		tw.tween_property(e, "modulate:a", 0.0, 0.4)
		tw.tween_callback(e.queue_free)
		beat_tweens.append(tw))

func _corridor_cells() -> Array:
	var out := []
	for x in range(21, 36):
		out.append(Vector2i(x, 30))
		out.append(Vector2i(x, 31))
	return out

func _force_state_b4() -> void:
	_force_state_b3()
	carve(_deep_cells(), DUG, false)
	place_building("lab2", "bld_lab2", Vector2(16 * T, 42 * T - 32), 1.8)

func _beat5() -> void:
	_force_state_b4()
	_set_caption(5)
	# defended corridor at rows 30-31 heading right from the shaft
	carve(_corridor_cells(), DUG, false)
	place_building("barricade", "bld_barricade", Vector2(30 * T, 32 * T - 24), 1.2)
	var turret := Sprite2D.new()
	turret.texture = load("res://assets/sprites/bld_turret_0.png")
	turret.centered = false
	turret.position = Vector2(27 * T, 32 * T - 20)
	bld_layer.add_child(turret)
	buildings["turret"] = {"node": turret, "base": "bld_turret", "on": true, "frame": 0, "light": null}
	cam_to(Vector2(29 * T, 30 * T), 1.7, 1.5)
	_add_light(Vector2(27 * T, 31 * T), 2.4, Color(1.0, 0.83, 0.55), 1.1)
	seismo_intensity = 0.75
	# soldiers take position
	var soldiers := []
	for k in 3:
		var s := _spawn_dude(Vector2((25 - k) * T, 32 * T), "soldier")
		s.spr.flip_h = false
		soldiers.append(s)
	# THE BREACH
	ev(2.5, func():
		shake(6.0)
		_play("roar")
		flash(0.35, 0.3)
		carve([Vector2i(35, 30), Vector2i(35, 31), Vector2i(36, 30), Vector2i(36, 31)], TROG)
		puff(Vector2(35 * T, 31 * T), Color(0.6, 0.18, 0.22), 24, 14.0))
	# swarm floods in, dies at the barricade line
	for i in 14:
		ev(3.0 + i * 0.55, func():
			var big := i % 5 == 4
			var tr := _spawn_trog(Vector2(37 * T, 32 * T - (randi() % 8)), big)
			tr.set_state("walk")
			tr.spr.flip_h = true
			tr.waypoints = [Vector2(31 * T + 10 + (randi() % 10), 32 * T)]
			tr.on_arrive = func():
				# dies at the barricade
				puff(tr.position + Vector2(0, -6), Color(1.0, 0.5, 0.25), 12, 5.0)
				_play("squeak")
				trogs.erase(tr)
				tr.queue_free())
	# turret + soldiers firing
	every(3.2, 0.28, 40, func():
		_play("gun")
		turret.texture = load("res://assets/sprites/bld_turret_%d.png" % (randi() % 2))
		for s in soldiers:
			if randf() < 0.5:
				s.set_state("shoot")
		shake(0.7))
	# ONE GETS THROUGH
	ev(11.0, func():
		var tr := _spawn_trog(Vector2(37 * T, 32 * T), false)
		tr.speed = 95.0
		tr.set_state("walk")
		tr.spr.flip_h = true
		tr.waypoints = [Vector2(20 * T, 31 * T), Vector2(20 * T, 17 * T), Vector2(14 * T, 17 * T)]
		tr.on_arrive = func():
			set_building_on("living", false)
			_play("squeak")
			shake(2.5)
			puff(Vector2(14 * T, 17 * T - 10), Color(0.9, 0.3, 0.2), 16, 10.0)
			pop_below -= 2
			chips["below"].value = pop_below
			# scatter two dudes out of the building
			for k in 2:
				var d := _spawn_dude(Vector2(14 * T + k * 6, 17 * T), "free")
				d.set_state("walk")
				d.speed = 80.0
				d.waypoints = [Vector2((18 + k) * T, 17 * T)]
			# soldier chases and kills it
			get_tree().create_timer(1.6).timeout.connect(func():
				if is_instance_valid(tr):
					puff(tr.position, Color(1.0, 0.5, 0.25), 14, 6.0)
					_play("gun")
					_play("squeak")
					tr.queue_free()
				set_building_on("living", true)
				# a free dude walks back in — the quiet refill
				var d2 := _spawn_dude(Vector2(18 * T, 17 * T), "worker")
				d2.set_state("walk")
				d2.waypoints = [Vector2(14 * T, 17 * T)]
				d2.on_arrive = func(): d2.set_state("idle")))
	ev(11.5, func(): cam_to(Vector2(310, 300), 1.25, 1.8))

func _beat6() -> void:
	_force_state_b4()
	_set_caption(6)
	cam_to(Vector2(320, 66 * T), 1.1, 3.0)
	seismo_intensity = 1.0
	seismo.countdown = 5
	sfx["heart"].play()
	every(1.0, 1.0, 5, func():
		seismo.countdown -= 1
		_play("heart")
		shake(1.5 + (5 - seismo.countdown) * 0.8))
	# the rising wall of trogs in the queen chamber
	for i in 22:
		ev(0.5 + i * 0.18, func():
			var tr := _spawn_trog(Vector2((15 + (i * 13) % 11) * T, (69 - (i % 3)) * T), i % 4 == 0)
			tr.set_state("walk")
			tr.waypoints = [tr.position + Vector2((randf() - 0.5) * 40.0, -T * (2 + i % 3))]
			)
	ev(6.2, func():
		_play("roar")
		flash(1.0, 1.2)
		shake(8.0))
	if record_mode:
		ev(13.0, func(): get_tree().quit())
	ev(6.6, func():
		title_node.visible = true
		title_node.modulate.a = 0.0
		var tw := create_tween()
		tw.tween_property(title_node, "modulate:a", 1.0, 0.8)
		beat_tweens.append(tw)
		caption.modulate.a = 0.0)
