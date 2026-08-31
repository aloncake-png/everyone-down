extends Node2D
# EVERYONE DOWN! — playable prototype v0.2
# L-drag: dig (drag starting on a mark: erase). R-drag: pan. Wheel: zoom.
# 1-5: pick building (per tab), click: place. Click building: card. R+click: rally. F11: fullscreen. Esc: menu.

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

# ---------------- BALANCE KNOBS ----------------
var BAL := {
	"pop_start": 500,
	"death_period_start": 4.0,
	"death_accel": 0.99,
	"descend_period": 1.4,
	"dig_time": 0.9,
	"rock_dig_mult": 2.2,
	"start_iron": 24,
	"start_rare": 0,
	"swarm_time": 1200.0,          # 20 minutes to the Big Swarm
	"trog_pop": 220,               # THEIR finite population
	"warren_period_start": 12.0,
	"warren_accel": 0.985,
	"noise_pull": 3.0,
	"breach_wave": 6,
	"warren_start_delay": 120.0,
	"mine_period": 3.0,            # seconds per mining tick
	"ore_per_cell": 20,            # units per deposit cell before depletion
	"trog_hp": 2, "trog_big_hp": 6,
	"soldier_range": 70.0, "soldier_fire": 0.7, "soldier_dmg": 1,
	"turret_range": 100.0, "turret_fire": 0.22,
	"trog_speed": 34.0, "dude_speed": 46.0,
	"fog_radius": 4.6,
	"rally_life": 25.0,
}

const BLD := {
	"living":   {"size": Vector2i(3, 2), "sprite": "bld_living", "label": "n_living", "cost_iron": 10, "cost_rare": 0, "workers": 0, "beds": 8, "food": 0, "power": 0, "need": "", "tab": 0},
	"farm":     {"size": Vector2i(3, 2), "sprite": "bld_farm", "label": "n_farm", "cost_iron": 8, "cost_rare": 0, "workers": 2, "beds": 0, "food": 30, "power": 0, "need": "water", "tab": 0},
	"power":    {"size": Vector2i(2, 3), "sprite": "bld_power", "label": "n_power", "cost_iron": 12, "cost_rare": 0, "workers": 2, "beds": 0, "food": 0, "power": 40, "need": "vent", "tab": 0},
	"mine":     {"size": Vector2i(2, 2), "sprite": "bld_mine", "label": "n_mine", "cost_iron": 10, "cost_rare": 0, "workers": 2, "beds": 0, "food": 0, "power": -5, "need": "ore", "tab": 0},
	"lab":      {"size": Vector2i(2, 2), "sprite": "bld_lab1", "label": "n_lab", "cost_iron": 12, "cost_rare": 0, "workers": 2, "beds": 0, "food": 0, "power": -5, "need": "", "tab": 0},
	"armory":   {"size": Vector2i(2, 2), "sprite": "bld_armory", "label": "n_armory", "cost_iron": 15, "cost_rare": 0, "workers": 2, "beds": 0, "food": 0, "power": -10, "need": "", "tab": 1},
	"turret":   {"size": Vector2i(2, 2), "sprite": "bld_turret", "label": "n_turret", "cost_iron": 8, "cost_rare": 2, "workers": 1, "beds": 0, "food": 0, "power": -5, "need": "tech_arms", "tab": 1},
	"barricade": {"size": Vector2i(1, 2), "sprite": "bld_barricade", "label": "n_barricade", "cost_iron": 4, "cost_rare": 0, "workers": 0, "beds": 0, "food": 0, "power": 0, "need": "", "tab": 1},
}
const TABS := [["living", "farm", "power", "mine", "lab"], ["armory", "turret", "barricade"]]

const TECH := {
	"picks":  {"label": "t_picks", "cost_iron": 20, "cost_rare": 0, "time": 45.0},
	"arms":   {"label": "t_arms", "cost_iron": 30, "cost_rare": 0, "time": 60.0},
	"drills": {"label": "t_drills", "cost_iron": 0, "cost_rare": 15, "time": 60.0},
}

# ---------------- WORLD ----------------
var grid := []
var ore_left := {}             # Vector2i -> units remaining
var terrain_img: Image
var terrain_tex: ImageTexture
var tile_imgs := {}
var water_cells := []
var water_frame := 0
var vent_cells := [Vector2i(6, 23), Vector2i(27, 45)]
var pockets := []              # {cells, kind, amount, opened, node}

var world: Node2D
var bld_layer: Node2D
var actor_layer: Node2D
var fx_layer: Node2D
var light_layer: Node2D
var marker_layer: Node2D
var cam: Camera2D
var canvas_mod: CanvasModulate
var light_tex: Texture2D
var fog_img: Image
var fog_tex: ImageTexture

# ---------------- SIM STATE ----------------
var pop_top := 0
var free_dudes := []
var soldiers := []
var trogs := []
var buildings := []
var dig_marks := {}
var dig_reserved := {}
var iron := 0
var rare := 0
var beds := 0
var food_cap := 0
var power_cap := 0
var power_used := 0
var death_clock := 0.0
var death_period := 4.0
var descend_clock := 0.0
var game_time := 0.0
var swarm_left := 1200.0
var swarm_started := false
var game_over := false
var warren_heads := []
var warren_clock := 0.0
var warren_period := 9.0
var trog_pool := 220
var noise_points := []
var astar: AStarGrid2D
var sfx := {}
var autotest := false
var techs := {"picks": false, "arms": false, "drills": false}
var dig_time := 0.9
var rally_flags := []          # {node, pos, age}

# ---------------- UI ----------------
const UIS := 1.5               # UI scale
const UIW := 426               # logical UI width (640/UIS)
const UIH := 240               # logical UI height (360/UIS)
var ui: CanvasLayer
var chips := {}
var seismo: Control
var build_sel := ""
var build_tab := 0
var ghost: Node2D
var toast_rect: TextureRect
var end_card: TextureRect
var card: Control              # building card panel
var card_bld = null
var shake_amt := 0.0
var slots := []
var tab_btns := []

func _ready() -> void:
	autotest = "--autotest" in OS.get_cmdline_user_args()
	randomize()
	death_period = BAL.death_period_start
	warren_period = BAL.warren_period_start
	swarm_left = BAL.swarm_time
	pop_top = BAL.pop_start
	trog_pool = BAL.trog_pop
	iron = BAL.start_iron
	rare = BAL.start_rare
	dig_time = BAL.dig_time
	_load_tiles()
	_build_grid()
	_build_layers()
	_render_terrain()
	_build_astar()
	_build_fog()
	_build_ui()
	_build_audio()
	_start_state()
	if autotest:
		_run_autotest()

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
			row.append(AIR if y < 8 else (SURF if y == 8 else DIRT))
		grid.append(row)
	var rocks := [Vector2i(5, 14), Vector2i(31, 12), Vector2i(3, 30), Vector2i(34, 26),
		Vector2i(8, 44), Vector2i(30, 40), Vector2i(14, 55), Vector2i(26, 58), Vector2i(6, 62)]
	for r in rocks:
		for dy in range(-1, 3):
			for dx in range(-2, 3):
				if abs(dx) + abs(dy) < 4:
					_set_cell(r.x + dx, r.y + dy, ROCK)
	var lakes := [[6, 17, 4], [23, 17, 5], [12, 28, 4], [31, 33, 4], [5, 38, 3], [22, 44, 5], [33, 50, 3], [10, 50, 4]]
	for l in lakes:
		for i in l[2]:
			_set_cell(l[0] + i, l[1], WATER)
			water_cells.append(Vector2i(l[0] + i, l[1]))
			_set_cell(l[0] + i, l[1] + 1, ROCK)
	for c in [Vector2i(9, 20), Vector2i(28, 22), Vector2i(15, 34), Vector2i(33, 38), Vector2i(7, 33)]:
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(2, 1), Vector2i(1, 2)]:
			_set_cell(c.x + d.x, c.y + d.y, IRON)
			ore_left[Vector2i(c.x + d.x, c.y + d.y)] = BAL.ore_per_cell
	for c in [Vector2i(12, 52), Vector2i(27, 50), Vector2i(18, 60), Vector2i(31, 60), Vector2i(8, 58)]:
		for d in [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)]:
			_set_cell(c.x + d.x, c.y + d.y, RARE)
			ore_left[Vector2i(c.x + d.x, c.y + d.y)] = BAL.ore_per_cell
	for v in vent_cells:
		for dx in range(-1, 3):
			_set_cell(v.x + dx, v.y + 1, ROCK)
	# queen chamber + warren (heads start DEEP — long climb up)
	for y in range(65, 70):
		for x in range(14, 27):
			_set_cell(x, y, TROG)
	var seeds := [[16, 65, -1], [20, 65, 0], [25, 65, 1]]
	for s in seeds:
		var x: int = s[0]
		for y in range(65, 60, -1):
			_set_cell(x, y, TROG)
			_set_cell(x + 1, y, TROG)
			if (y * 7 + x) % 3 == 0:
				x = clampi(x + s[2], 3, TW - 4)
		warren_heads.append(Vector2i(x, 60))
	# sealed cave pockets (hidden by fog until you tunnel in)
	_make_pocket(Rect2i(5, 26, 3, 2), "iron", 14)
	_make_pocket(Rect2i(29, 29, 3, 2), "trogs", 3)
	_make_pocket(Rect2i(12, 41, 4, 2), "iron", 18)
	_make_pocket(Rect2i(24, 36, 3, 2), "trogs", 3)
	_make_pocket(Rect2i(6, 54, 3, 2), "rare", 8)
	_make_pocket(Rect2i(33, 55, 3, 2), "trogs", 4)
	_make_pocket(Rect2i(17, 47, 4, 2), "rare", 6)

func _make_pocket(r: Rect2i, kind: String, amount: int) -> void:
	var cells := []
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			if grid[y][x] == DIRT:
				grid[y][x] = DUG
				cells.append(Vector2i(x, y))
	if cells.is_empty():
		return
	var node = null
	if kind != "trogs":
		node = Sprite2D.new()
		node.texture = load("res://assets/sprites/crate.png")
		node.centered = false
		var last: Vector2i = cells[cells.size() - 1]
		node.position = Vector2(last.x * T + 1, (last.y + 1) * T - 12)
	pockets.append({"cells": cells, "kind": kind, "amount": amount, "opened": false, "node": node})

func _set_cell(x: int, y: int, v: int) -> void:
	if x >= 0 and x < TW and y >= 0 and y < TH:
		grid[y][x] = v

func _build_layers() -> void:
	world = Node2D.new()
	add_child(world)
	var sky := Sprite2D.new()
	sky.texture = load("res://assets/tiles/backdrop.png")
	sky.centered = false
	sky.position = Vector2(0, -12)
	world.add_child(sky)
	var cave_img := Image.create(TW * T, TH * T, false, Image.FORMAT_RGBA8)
	for y in range(8, TH):
		for x in TW:
			cave_img.blit_rect(tile_imgs[DUG][(x * 7 + y * 13) % 4], Rect2i(0, 0, T, T), Vector2i(x * T, y * T))
	var cave_spr := Sprite2D.new()
	cave_spr.texture = ImageTexture.create_from_image(cave_img)
	cave_spr.centered = false
	world.add_child(cave_spr)
	terrain_img = Image.create(TW * T, TH * T, false, Image.FORMAT_RGBA8)
	terrain_tex = ImageTexture.create_from_image(terrain_img)
	var terr := Sprite2D.new()
	terr.texture = terrain_tex
	terr.centered = false
	world.add_child(terr)
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
	for p in pockets:
		if p.node != null:
			bld_layer.add_child(p.node)
	_feature("res://assets/sprites/shaft_head.png", Vector2(304, 8 * T - 24))
	_anim_feature(["res://assets/sprites/vent_0.png", "res://assets/sprites/vent_1.png"], Vector2(6 * T, 23 * T), 0.5)
	_anim_feature(["res://assets/sprites/vent_0.png", "res://assets/sprites/vent_1.png"], Vector2(27 * T, 45 * T), 0.6)
	_anim_feature(["res://assets/sprites/queen_0.png", "res://assets/sprites/queen_1.png"], Vector2(13 * T, 68 * T - 16), 0.8)
	cam = Camera2D.new()
	cam.position = Vector2(320, 160)
	cam.limit_left = 0
	cam.limit_right = TW * T
	cam.limit_top = -20
	cam.limit_bottom = TH * T
	add_child(cam)
	cam.make_current()
	canvas_mod = CanvasModulate.new()
	canvas_mod.color = Color(0.47, 0.44, 0.52)
	add_child(canvas_mod)
	light_tex = load("res://assets/fx/light_halo.png")
	_add_light(Vector2(320, 30), 9.0, Color(1.0, 0.62, 0.42), 0.9)
	_add_light(Vector2(320, 118), 1.6, Color(1.0, 0.85, 0.6), 1.0)

func _feature(path: String, pos: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(path)
	s.centered = false
	s.position = pos
	bld_layer.add_child(s)
	return s

func _anim_feature(paths: Array, pos: Vector2, period: float) -> void:
	var s := _feature(paths[0], pos)
	var frames := []
	for p in paths:
		frames.append(load(p))
	var t := Timer.new()
	t.wait_time = period
	t.autostart = true
	s.add_child(t)
	var st := {"i": 0}
	t.timeout.connect(func():
		st.i = (st.i + 1) % frames.size()
		s.texture = frames[st.i])

func _add_light(pos: Vector2, sc: float, col: Color, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_tex
	l.position = pos
	l.texture_scale = sc
	l.color = col
	l.energy = energy
	light_layer.add_child(l)
	return l

func _render_terrain() -> void:
	for y in TH:
		for x in TW:
			_paint_cell(x, y)
	terrain_tex.update(terrain_img)

func _paint_cell(x: int, y: int) -> void:
	var v: int = grid[y][x]
	var dst := Vector2i(x * T, y * T)
	if v == AIR or v == DUG:
		terrain_img.fill_rect(Rect2i(dst.x, dst.y, T, T), Color(0, 0, 0, 0))
		return
	var variants: Array = tile_imgs[v]
	var im: Image = variants[water_frame] if v == WATER else variants[(x * 7 + y * 13) % variants.size()]
	terrain_img.blit_rect(im, Rect2i(0, 0, T, T), dst)

func _update_cells(cells: Array) -> void:
	for c in cells:
		_paint_cell(c.x, c.y)
	terrain_tex.update(terrain_img)

func _build_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, TW, TH)
	astar.cell_size = Vector2(T, T)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	for y in TH:
		for x in TW:
			astar.set_point_solid(Vector2i(x, y), not _walkable(x, y))

func _walkable(x: int, y: int) -> bool:
	var v: int = grid[y][x]
	return v == AIR or v == DUG or v == SURF or v == TROG

func _open_cell(c: Vector2i) -> void:
	astar.set_point_solid(c, false)

# ---------------- FOG OF WAR ----------------

func _build_fog() -> void:
	fog_img = Image.create(TW, TH, false, Image.FORMAT_RGBA8)
	fog_img.fill(Color(0.03, 0.02, 0.03, 1.0))
	fog_tex = ImageTexture.create_from_image(fog_img)
	var fs := Sprite2D.new()
	fs.texture = fog_tex
	fs.centered = false
	fs.scale = Vector2(T, T)
	fs.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # soft fog edges
	world.add_child(fs)
	for y in range(0, 10):
		for x in TW:
			fog_img.set_pixel(x, y, Color(0, 0, 0, 0))
	fog_tex.update(fog_img)

func reveal(c: Vector2i, radius: float = -1.0) -> void:
	if radius < 0:
		radius = BAL.fog_radius
	var r := int(ceil(radius))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := c.x + dx
			var y := c.y + dy
			if x < 0 or x >= TW or y < 0 or y >= TH:
				continue
			if Vector2(dx, dy).length() <= radius:
				fog_img.set_pixel(x, y, Color(0, 0, 0, 0))
	fog_tex.update(fog_img)

# ---------------- START ----------------

func _start_state() -> void:
	var start := []
	for y in range(9, 13):
		start.append(Vector2i(19, y))
		start.append(Vector2i(20, y))
	for x in range(17, 24):
		start.append(Vector2i(x, 11))
		start.append(Vector2i(x, 12))
	for c in start:
		if grid[c.y][c.x] != ROCK:
			grid[c.y][c.x] = DUG
			_open_cell(c)
			reveal(c)
	_update_cells(start)
	for i in 3:
		_spawn_free(Vector2((18 + i * 2) * T + 8, 13 * T))
	for i in 14:
		var d := _actor("worker" if i % 3 else "free", Vector2(110 + (i * 73) % 420, 8 * T))
		d.set_meta("cosmetic", true)
		_wander_topside(d)

# ---------------- ACTORS ----------------

class Actor extends Node2D:
	var spr: Sprite2D
	var frames := {}
	var state := "idle"
	var fi := 0
	var ft := 0.0
	var fps := 6.0
	var path := []
	var speed := 46.0
	var hp := 1
	var task := {}
	var wander_t := 0.0
	func setup(defs: Dictionary) -> void:
		spr = Sprite2D.new()
		for k in defs:
			var arr := []
			for p in defs[k]:
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
		if path.size() > 0:
			var tgt: Vector2 = path[0]
			var d := tgt - position
			if d.length() < 2.5:
				path.pop_front()
				if path.is_empty() and state == "walk":
					set_state("idle")
			else:
				position += d.normalized() * speed * delta
				if abs(d.x) > 1.0:
					spr.flip_h = d.x < 0

func _actor(kind: String, pos: Vector2) -> Actor:
	var a := Actor.new()
	a.position = pos
	a.speed = BAL.dude_speed
	actor_layer.add_child(a)
	if kind == "soldier":
		a.setup({"idle": ["res://assets/sprites/soldier_0.png"],
			"walk": ["res://assets/sprites/soldier_0.png", "res://assets/sprites/soldier_1.png"],
			"shoot": ["res://assets/sprites/soldier_1.png", "res://assets/sprites/soldier_0.png"]})
		a.hp = 3
	elif kind == "trog" or kind == "trog_big":
		a.setup({"idle": ["res://assets/sprites/%s_0.png" % kind],
			"walk": ["res://assets/sprites/%s_0.png" % kind, "res://assets/sprites/%s_1.png" % kind]})
		a.fps = 8.0
		a.speed = BAL.trog_speed * (0.8 if kind == "trog_big" else 1.0)
		a.hp = BAL.trog_big_hp if kind == "trog_big" else BAL.trog_hp
	else:
		var w := "worker" if kind == "worker" else "free"
		a.setup({"idle": ["res://assets/sprites/%s_walk_0.png" % w],
			"walk": ["res://assets/sprites/%s_walk_0.png" % w, "res://assets/sprites/%s_walk_1.png" % w],
			"dig": ["res://assets/sprites/worker_dig_0.png", "res://assets/sprites/worker_dig_1.png"]})
	return a

func _spawn_free(pos: Vector2) -> Actor:
	var a := _actor("worker", pos)
	a.task = {"kind": "free"}
	a.wander_t = randf() * 3.0
	free_dudes.append(a)
	return a

func _wander_topside(a: Actor) -> void:
	if not is_instance_valid(a):
		return
	a.path = [Vector2(90.0 + randf() * 440.0, 8 * T)]
	a.set_state("walk")
	get_tree().create_timer(1.5 + randf() * 2.5).timeout.connect(func():
		if is_instance_valid(a):
			get_tree().create_timer(0.5 + randf() * 1.5).timeout.connect(func(): _wander_topside(a)))

# underground idle wander: amble to a nearby open cell
func _tick_wander(delta: float) -> void:
	for d in free_dudes:
		if not is_instance_valid(d) or d.task.get("kind", "") != "free":
			continue
		if not d.path.is_empty():
			continue
		d.wander_t -= delta
		if d.wander_t <= 0.0:
			d.wander_t = 1.2 + randf() * 2.8
			var c := _cell_of(d)
			for attempt in 6:
				var n := Vector2i(c.x + randi_range(-4, 4), c.y + randi_range(-2, 2))
				if n.x < 1 or n.x >= TW - 1 or n.y < 8 or n.y >= TH:
					continue
				if not astar.is_point_solid(n):
					var pts := _path_points(c, n)
					if pts.size() > 0 and pts.size() < 12:
						d.path = pts
						d.set_state("walk")
					break

# ---------------- FX / AUDIO ----------------

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

func _build_audio() -> void:
	for n in ["dig", "pop", "blip", "gun", "roar", "heart", "squeak", "drone", "steam"]:
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/audio/%s.wav" % n)
		add_child(p)
		sfx[n] = p
	sfx["blip"].volume_db = -18
	sfx["dig"].volume_db = -10
	sfx["gun"].volume_db = -12
	sfx["squeak"].volume_db = -8
	sfx["drone"].volume_db = -14
	var st: AudioStreamWAV = sfx["drone"].stream
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_end = st.data.size() / 2
	sfx["drone"].play()

func _play(n: String) -> void:
	if sfx.has(n) and not autotest:
		sfx[n].play()

# ---------------- UI ----------------

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.scale = Vector2(UIS, UIS)
	add_child(ui)
	var topbar := ColorRect.new()
	topbar.color = Color(0.05, 0.035, 0.05, 0.9)
	topbar.size = Vector2(UIW, 20)
	ui.add_child(topbar)
	var defs := [["pop", "res://assets/ui/ic_pop.png"], ["below", "res://assets/ui/ic_below.png"],
		["food", "res://assets/ui/ic_food.png"], ["power", "res://assets/ui/ic_power.png"],
		["iron", "res://assets/ui/ic_iron.png"], ["rare", "res://assets/ui/ic_rare.png"]]
	var x := 3.0
	for d in defs:
		var chip := UIChip.new()
		chip.icon = load(d[1])
		chip.digits = load("res://assets/ui/digits.png")
		chip.chip_bg = load("res://assets/ui/chip.png")
		chip.position = Vector2(x, 3)
		ui.add_child(chip)
		chips[d[0]] = chip
		x += 49
	chips["pop"].text = str(pop_top)
	chips["iron"].text = str(iron)
	seismo = Seismo.new()
	seismo.panel = load("res://assets/ui/seismo.png")
	seismo.lbl = load("res://assets/ui/lbl_swarm.png")
	seismo.digits = load("res://assets/ui/digits.png")
	seismo.position = Vector2(UIW - 95, 24)
	ui.add_child(seismo)
	var botbar := ColorRect.new()
	botbar.color = Color(0.05, 0.035, 0.05, 0.9)
	botbar.position = Vector2(0, UIH - 40)
	botbar.size = Vector2(UIW, 40)
	ui.add_child(botbar)
	for i in 2:
		var tb := TabBtn.new()
		tb.tex = load("res://assets/ui/tab_%s.png" % (["industry", "defense"][i]))
		tb.idx = i
		tb.game = self
		tb.position = Vector2(4, UIH - 39 + i * 13)
		ui.add_child(tb)
		tab_btns.append(tb)
		tb.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				build_tab = tb.idx
				_select_build("")
				_layout_slots())
	_layout_slots()
	var help := TextureRect.new()
	help.texture = load("res://assets/ui/lbl_help2.png")
	help.scale = Vector2(0.55, 0.55)
	help.position = Vector2(4, UIH - 9)
	help.modulate.a = 0.65
	ui.add_child(help)
	toast_rect = TextureRect.new()
	toast_rect.modulate.a = 0.0
	ui.add_child(toast_rect)
	end_card = TextureRect.new()
	end_card.visible = false
	ui.add_child(end_card)
	card = null
	ghost = Node2D.new()
	ghost.visible = false
	ghost.modulate = Color(1, 1, 1, 0.55)
	var gs := Sprite2D.new()
	gs.name = "spr"
	gs.centered = false
	ghost.add_child(gs)
	world.add_child(ghost)

func _layout_slots() -> void:
	for s in slots:
		s.queue_free()
	slots.clear()
	var bx := 70.0
	var names: Array = TABS[build_tab]
	for i in names.size():
		var name: String = names[i]
		var slot := BuildSlot.new()
		slot.bname = name
		slot.digits = load("res://assets/ui/digits.png")
		slot.ic_iron = load("res://assets/ui/ic_iron.png")
		slot.ic_rare = load("res://assets/ui/ic_rare.png")
		slot.cost_iron = BLD[name].cost_iron
		slot.cost_rare = BLD[name].cost_rare
		var sname: String = BLD[name].sprite
		slot.tex = load("res://assets/sprites/%s%s.png" % [sname, "" if name == "barricade" else ("_0" if name == "turret" else "_1_0")])
		slot.idx = i + 1
		slot.position = Vector2(bx, UIH - 38)
		slot.game = self
		ui.add_child(slot)
		slots.append(slot)
		slot.gui_input.connect(func(ev):
			if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
				_select_build(name))
		bx += 48

class UIChip extends Control:
	var icon: Texture2D
	var digits: Texture2D
	var chip_bg: Texture2D
	var text: String = "0":
		set(v):
			text = v
			queue_redraw()
	func _draw() -> void:
		draw_texture(chip_bg, Vector2.ZERO)
		draw_texture(icon, Vector2(3, 2))
		var x := 42.0 - text.length() * 5.0
		for ch in text:
			var i := "0123456789/:".find(ch)
			if i >= 0:
				draw_texture_rect_region(digits, Rect2(x, 3, 5, 7), Rect2(i * 4, 0, 5, 7))
			x += 5.0

class TabBtn extends Control:
	var tex: Texture2D
	var idx := 0
	var game: Node
	func _init() -> void:
		custom_minimum_size = Vector2(62, 12)
		size = Vector2(62, 12)
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var on: bool = game != null and game.build_tab == idx
		draw_rect(Rect2(0, 0, 62, 12), Color(0.35, 0.27, 0.18, 0.95) if on else Color(0.14, 0.10, 0.12, 0.9))
		if tex:
			draw_texture_rect(tex, Rect2(4, 2, tex.get_width() * 0.6, tex.get_height() * 0.6), false)

class BuildSlot extends Control:
	var bname := ""
	var tex: Texture2D
	var digits: Texture2D
	var ic_iron: Texture2D
	var ic_rare: Texture2D
	var cost_iron := 0
	var cost_rare := 0
	var idx := 1
	var game: Node
	func _init() -> void:
		custom_minimum_size = Vector2(44, 36)
		size = Vector2(44, 36)
	func _draw() -> void:
		var selected: bool = game != null and game.build_sel == bname
		draw_rect(Rect2(0, 0, 44, 36), Color(0.16, 0.12, 0.14, 0.9))
		draw_rect(Rect2(0, 0, 44, 36), Color(0.9, 0.75, 0.4, 0.95) if selected else Color(0.35, 0.28, 0.32, 0.8), false, 1.0)
		if tex:
			var sc := minf(38.0 / tex.get_width(), 20.0 / tex.get_height())
			draw_texture_rect(tex, Rect2((44 - tex.get_width() * sc) / 2.0, 2, tex.get_width() * sc, tex.get_height() * sc), false)
		var i := "0123456789/:".find(str(idx))
		draw_texture_rect_region(digits, Rect2(2, 2, 5, 7), Rect2(i * 4, 0, 5, 7))
		var cx := 4.0
		if cost_iron > 0:
			draw_texture_rect(ic_iron, Rect2(cx, 25, 9, 9), false)
			cx += 9
			for ch in str(cost_iron):
				var j := "0123456789/:".find(ch)
				draw_texture_rect_region(digits, Rect2(cx, 26, 5, 7), Rect2(j * 4, 0, 5, 7))
				cx += 5
			cx += 3
		if cost_rare > 0:
			draw_texture_rect(ic_rare, Rect2(cx, 25, 9, 9), false)
			cx += 9
			for ch in str(cost_rare):
				var j := "0123456789/:".find(ch)
				draw_texture_rect_region(digits, Rect2(cx, 26, 5, 7), Rect2(j * 4, 0, 5, 7))
				cx += 5

class Seismo extends Control:
	var panel: Texture2D
	var lbl: Texture2D
	var digits: Texture2D
	var intensity := 0.2
	var phase := 0.0
	var countdown := -1
	func _process(delta: float) -> void:
		phase += delta * (2.0 + intensity * 14.0)
		queue_redraw()
	func _draw() -> void:
		draw_texture(panel, Vector2.ZERO)
		var pts := PackedVector2Array()
		for i in range(0, 84, 2):
			var t := phase + i * 0.31
			var a: float = (sin(t) * 0.5 + sin(t * 2.7) * 0.3 + sin(t * 6.1) * 0.2) * intensity * 6.5
			pts.append(Vector2(4 + i, 11 + a))
		draw_polyline(pts, Color(1.0, 0.45, 0.28), 1.0)
		draw_texture(lbl, Vector2(4, 20), Color(1, 1, 1, 0.9))
		if countdown >= 0:
			var s := "%d:%02d" % [countdown / 60, countdown % 60]
			var x := 86.0 - s.length() * 5.0
			for ch in s:
				var i := "0123456789/:".find(ch)
				if i >= 0:
					draw_texture_rect_region(digits, Rect2(x, 20, 5, 7), Rect2(i * 4, 0, 5, 7))
				x += 5.0

func toast(name: String) -> void:
	var tex: Texture2D = load("res://assets/ui/%s.png" % name)
	toast_rect.texture = tex
	toast_rect.position = Vector2((UIW - tex.get_width()) / 2.0, 46)
	toast_rect.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(toast_rect, "modulate:a", 0.0, 0.6)

# ---------------- BUILDING CARD ----------------

class BCard extends Control:
	var game: Node
	var b = null
	var labels := {}
	var digits: Texture2D
	func _init() -> void:
		custom_minimum_size = Vector2(130, 96)
		size = Vector2(130, 96)
		mouse_filter = Control.MOUSE_FILTER_STOP
	func _gui_input(ev: InputEvent) -> void:
		if not (ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT):
			return
		var p: Vector2 = ev.position
		if Rect2(4, 44, 58, 12).has_point(p):
			game._card_toggle()
		elif Rect2(66, 44, 60, 12).has_point(p):
			game._card_demolish()
		elif b != null and b.name == "lab":
			for i in 3:
				if Rect2(4, 58 + i * 12, 122, 11).has_point(p):
					game._card_research(["picks", "arms", "drills"][i])
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if b == null:
			return
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.08, 0.055, 0.08, 0.95))
		draw_rect(Rect2(0, 0, size.x, size.y), Color(0.55, 0.42, 0.25), false, 1.0)
		draw_texture_rect(labels["name"], Rect2(4, 3, labels["name"].get_width() * 0.7, labels["name"].get_height() * 0.7), false)
		draw_texture_rect(labels["status"], Rect2(4, 16, labels["status"].get_width() * 0.7, labels["status"].get_height() * 0.7), false)
		draw_texture_rect(labels["staff"], Rect2(4, 29, labels["staff"].get_width() * 0.7, labels["staff"].get_height() * 0.7), false)
		var s := "%d/%d" % [b.workers.size(), b.need_workers]
		var x := 46.0
		for ch in s:
			var i := "0123456789/:".find(ch)
			if i >= 0:
				draw_texture_rect_region(digits, Rect2(x, 30, 5, 7), Rect2(i * 4, 0, 5, 7))
			x += 5.0
		draw_rect(Rect2(4, 44, 58, 12), Color(0.25, 0.20, 0.22))
		draw_texture_rect(labels["toggle"], Rect2(8, 46, labels["toggle"].get_width() * 0.7, labels["toggle"].get_height() * 0.7), false)
		draw_rect(Rect2(66, 44, 60, 12), Color(0.30, 0.14, 0.14))
		draw_texture_rect(labels["demolish"], Rect2(69, 46, labels["demolish"].get_width() * 0.55, labels["demolish"].get_height() * 0.55), false)
		if b.name == "lab":
			for i in 3:
				var key: String = ["picks", "arms", "drills"][i]
				var done: bool = game.techs[key]
				var active: bool = b.research.get("key", "") == key
				var col := Color(0.16, 0.30, 0.20) if done else (Color(0.32, 0.26, 0.14) if active else Color(0.20, 0.16, 0.20))
				draw_rect(Rect2(4, 58 + i * 12, 122, 11), col)
				if active:
					var prog: float = b.research.progress / game.TECH[key].time
					draw_rect(Rect2(4, 58 + i * 12, 122 * prog, 11), Color(0.85, 0.65, 0.3, 0.35))
				draw_texture_rect(labels[key], Rect2(7, 60 + i * 12, labels[key].get_width() * 0.6, labels[key].get_height() * 0.6), false)

func _open_card(b) -> void:
	_close_card()
	card = BCard.new()
	card.game = self
	card.b = b
	card.digits = load("res://assets/ui/digits.png")
	card.labels = {
		"name": load("res://assets/ui/%s.png" % BLD[b.name].label),
		"status": _status_tex(b),
		"staff": load("res://assets/ui/c_staff.png"),
		"toggle": load("res://assets/ui/c_toggle.png"),
		"demolish": load("res://assets/ui/c_demolish.png"),
		"picks": load("res://assets/ui/t_picks.png"),
		"arms": load("res://assets/ui/t_arms.png"),
		"drills": load("res://assets/ui/t_drills.png"),
	}
	card.size.y = 96.0 if b.name == "lab" else 60.0
	card.position = Vector2(UIW - 136, 24)
	ui.add_child(card)
	card_bld = b

func _status_tex(b) -> Texture2D:
	if b.forced_off:
		return load("res://assets/ui/c_off.png")
	if b.workers.size() < b.need_workers:
		return load("res://assets/ui/c_nostaff.png")
	if not b.on:
		return load("res://assets/ui/c_nopower.png")
	return load("res://assets/ui/c_working.png")

func _close_card() -> void:
	if card != null and is_instance_valid(card):
		card.queue_free()
	card = null
	card_bld = null

func _card_toggle() -> void:
	if card_bld != null:
		card_bld.forced_off = not card_bld.forced_off
		card.labels["status"] = _status_tex(card_bld)

func _card_demolish() -> void:
	if card_bld != null:
		_demolish(card_bld)
		_close_card()

func _card_research(key: String) -> void:
	var b = card_bld
	if b == null or b.name != "lab" or techs[key] or not b.on:
		return
	if b.research.get("key", "") != "":
		return
	if iron < TECH[key].cost_iron or rare < TECH[key].cost_rare:
		toast("toast_iron")
		return
	iron -= TECH[key].cost_iron
	rare -= TECH[key].cost_rare
	b.research = {"key": key, "progress": 0.0}
	_refresh_stats()

# ---------------- INPUT ----------------

var panning := false
var painting := false
var erase_mode := false
var rally_key := false

func _unhandled_input(event: InputEvent) -> void:
	if game_over:
		if event is InputEventKey and event.pressed:
			get_tree().change_scene_to_file("res://scenes/Menu.tscn")
		return
	if event is InputEventKey:
		if event.keycode == KEY_R:
			rally_key = event.pressed
		if not event.pressed:
			return
		if event.keycode == KEY_ESCAPE:
			if card != null:
				_close_card()
			elif build_sel != "":
				_select_build("")
			else:
				get_tree().change_scene_to_file("res://scenes/Menu.tscn")
		elif event.keycode == KEY_F11:
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
			var i: int = event.keycode - KEY_1
			var names: Array = TABS[build_tab]
			if i < names.size():
				_select_build(names[i])
		elif event.keycode == KEY_TAB:
			build_tab = 1 - build_tab
			_select_build("")
			_layout_slots()
	elif event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			panning = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom(1)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom(-1)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				if rally_key:
					_set_rally(get_global_mouse_position())
				elif build_sel != "":
					_try_place(build_sel)
				else:
					var b = _building_at_mouse()
					if b != null:
						_open_card(b)
					else:
						_close_card()
						painting = true
						erase_mode = dig_marks.has(_mouse_cell())
						_paint_at_mouse()
			else:
				painting = false
	elif event is InputEventMouseMotion:
		if panning:
			cam.position -= event.relative / cam.zoom.x
			cam.position.x = clampf(cam.position.x, 0, TW * T)
			cam.position.y = clampf(cam.position.y, 0, TH * T)
		elif painting and build_sel == "":
			_paint_at_mouse()

func _building_at_mouse():
	var c := _mouse_cell()
	for b in buildings:
		if c in b.cells:
			return b
	return null

func _zoom(dir: int) -> void:
	var levels := [1.0, 1.5, 2.0]
	var cur := levels.find(cam.zoom.x)
	if cur == -1:
		cur = 0
	var nxt: int = clampi(cur + dir, 0, levels.size() - 1)
	var tw := create_tween()
	tw.tween_property(cam, "zoom", Vector2(levels[nxt], levels[nxt]), 0.18)

func _mouse_cell() -> Vector2i:
	var wp := get_global_mouse_position()
	return Vector2i(int(wp.x / T), int(wp.y / T))

func _paint_at_mouse() -> void:
	var c := _mouse_cell()
	if c.x < 1 or c.x >= TW - 1 or c.y < 9 or c.y >= TH:
		return
	if erase_mode:
		if dig_marks.has(c):
			dig_marks[c].queue_free()
			dig_marks.erase(c)
			if dig_reserved.has(c):
				var d: Actor = dig_reserved[c]
				if is_instance_valid(d):
					d.task = {"kind": "free"}
					d.set_state("idle")
					free_dudes.append(d)
				dig_reserved.erase(c)
		return
	if dig_marks.has(c):
		return
	var v: int = grid[c.y][c.x]
	if v == ROCK and not techs.drills:
		toast("toast_norock")
		return
	if v != DIRT and v != ROCK:
		return
	var mk := ColorRect.new()
	mk.color = Color(1.0, 0.85, 0.4, 0.35)
	mk.position = Vector2(c.x * T, c.y * T)
	mk.size = Vector2(T, T)
	marker_layer.add_child(mk)
	dig_marks[c] = mk

func _select_build(name: String) -> void:
	build_sel = name
	ghost.visible = name != ""
	if name != "":
		var sname: String = BLD[name].sprite
		var p := "res://assets/sprites/%s%s.png" % [sname, "" if name == "barricade" else ("_0" if name == "turret" else "_1_0")]
		(ghost.get_node("spr") as Sprite2D).texture = load(p)
	for s in slots:
		s.queue_redraw()

# ---------------- RALLY ----------------

func _set_rally(pos: Vector2) -> void:
	if rally_flags.size() >= 2:
		var oldest: Dictionary = rally_flags.pop_front()
		if is_instance_valid(oldest.node):
			oldest.node.queue_free()
	var f := Sprite2D.new()
	f.texture = load("res://assets/sprites/flag_0.png")
	f.centered = false
	f.position = pos + Vector2(-6, -16)
	fx_layer.add_child(f)
	var t := Timer.new()
	t.wait_time = 0.3
	t.autostart = true
	f.add_child(t)
	var st := {"i": 0}
	t.timeout.connect(func():
		st.i = 1 - st.i
		f.texture = load("res://assets/sprites/flag_%d.png" % st.i))
	rally_flags.append({"node": f, "pos": pos, "age": 0.0})
	toast("toast_rally")
	_play("blip")
	var idle := []
	for d in free_dudes:
		if is_instance_valid(d) and d.task.get("kind", "") == "free":
			idle.append(d)
	for s in soldiers:
		if is_instance_valid(s):
			idle.append(s)
	for i in idle.size():
		var target: Dictionary = rally_flags[i % rally_flags.size()]
		var d: Actor = idle[i]
		d.path = _path_points(_cell_of(d), Vector2i(int(target.pos.x / T), int(target.pos.y / T)))
		d.set_state("walk")

func _tick_rally(delta: float) -> void:
	for f in rally_flags.duplicate():
		f.age += delta
		if f.age > BAL.rally_life:
			if is_instance_valid(f.node):
				f.node.queue_free()
			rally_flags.erase(f)

# ---------------- PLACEMENT ----------------

func _footprint(name: String, c: Vector2i) -> Array:
	var sz: Vector2i = BLD[name].size
	var cells := []
	for dy in sz.y:
		for dx in sz.x:
			cells.append(Vector2i(c.x + dx, c.y - dy))
	return cells

func _neighbors8(cells: Array) -> Array:
	var out := {}
	for c in cells:
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n := Vector2i(c.x + dx, c.y + dy)
				if not n in cells and n.x >= 0 and n.x < TW and n.y >= 0 and n.y < TH:
					out[n] = true
	return out.keys()

func _placement_valid(name: String, c: Vector2i) -> Dictionary:
	var cells := _footprint(name, c)
	for cc in cells:
		if cc.x < 0 or cc.x >= TW or cc.y < 9 or cc.y >= TH:
			return {"ok": false, "why": "toast_space"}
		if grid[cc.y][cc.x] != DUG:
			return {"ok": false, "why": "toast_space"}
		for b in buildings:
			if cc in b.cells:
				return {"ok": false, "why": "toast_space"}
	var sz: Vector2i = BLD[name].size
	for dx in sz.x:
		var below := Vector2i(c.x + dx, c.y + 1)
		if below.y >= TH or _walkable(below.x, below.y):
			return {"ok": false, "why": "toast_space"}
	var need: String = BLD[name].need
	if need == "vent":
		var found := false
		for v in vent_cells:
			for cc in cells:
				if cc == v or Vector2i(cc.x, cc.y + 1) == v:
					found = true
		if not found:
			return {"ok": false, "why": "toast_vent"}
	elif need == "water":
		var found := false
		for dx in sz.x:
			if grid[c.y + 1][c.x + dx] == WATER:
				found = true
		if not found:
			return {"ok": false, "why": "toast_water"}
	elif need == "ore":
		var found := false
		for dx in sz.x:
			var below2 := Vector2i(c.x + dx, c.y + 1)
			if below2.y < TH and (grid[below2.y][below2.x] == IRON or grid[below2.y][below2.x] == RARE):
				found = true
		if not found:
			return {"ok": false, "why": "toast_mine_ore"}
	elif need == "tech_arms":
		if not techs.arms:
			return {"ok": false, "why": "toast_norock"}
	if iron < BLD[name].cost_iron or rare < BLD[name].cost_rare:
		return {"ok": false, "why": "toast_iron"}
	return {"ok": true, "why": ""}

func _try_place(name: String) -> void:
	var c := _mouse_cell()
	var res := _placement_valid(name, c)
	if not res.ok:
		toast(res.why)
		return
	_place(name, c)
	_select_build("")

func _place(name: String, c: Vector2i) -> void:
	iron -= BLD[name].cost_iron
	rare -= BLD[name].cost_rare
	var s := Sprite2D.new()
	var sname: String = BLD[name].sprite
	s.texture = load("res://assets/sprites/%s%s.png" % [sname, "" if name == "barricade" else ("_0" if name == "turret" else "_0_0")])
	s.centered = false
	s.position = Vector2(c.x * T, (c.y + 1) * T - s.texture.get_height())
	bld_layer.add_child(s)
	var b := {"name": name, "node": s, "cells": _footprint(name, c), "on": false, "forced_off": false,
		"workers": [], "need_workers": BLD[name].workers, "frame": 0, "light": null, "fire_cd": 0.0,
		"hp": 10, "mine_t": 0.0, "research": {},
		"base": Vector2(c.x * T + BLD[name].size.x * T / 2.0, (c.y + 1) * T)}
	if name != "barricade" and name != "turret":
		b.light = _add_light(b.base + Vector2(0, -12), 1.8, Color(1.0, 0.83, 0.55), 0.0)
		var t := Timer.new()
		t.wait_time = 0.55
		t.autostart = true
		s.add_child(t)
		t.timeout.connect(func():
			if b.on:
				b.frame = 1 - b.frame
				var p := "res://assets/sprites/%s_1_%d.png" % [sname, b.frame]
				if ResourceLoader.exists(p):
					s.texture = load(p))
	if name == "barricade":
		b.on = true
		for cc in b.cells:
			astar.set_point_solid(cc, true)
	buildings.append(b)
	s.scale = Vector2(1.0, 0.1)
	var tw := create_tween()
	tw.tween_property(s, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	puff(b.base, Color(0.6, 0.45, 0.3), 14, 12.0)
	_play("pop")
	_add_noise(b.base, 3.0)
	_refresh_stats()

func _demolish(b) -> void:
	iron += int(BLD[b.name].cost_iron * 0.5)
	rare += int(BLD[b.name].cost_rare * 0.5)
	for w in b.workers:
		if is_instance_valid(w):
			w.task = {"kind": "free"}
			free_dudes.append(w)
	if b.light != null:
		b.light.queue_free()
	if b.name == "barricade":
		for cc in b.cells:
			astar.set_point_solid(cc, false)
	b.node.queue_free()
	buildings.erase(b)
	_refresh_stats()

func _refresh_stats() -> void:
	beds = 0
	food_cap = 0
	power_cap = 0
	power_used = 0
	for b in buildings:
		if not b.on:
			continue
		var d: Dictionary = BLD[b.name]
		beds += d.beds
		food_cap += d.food
		if d.power > 0:
			power_cap += d.power
		else:
			power_used += -d.power
	chips["food"].text = str(food_cap)
	chips["power"].text = str(power_cap - power_used)
	chips["iron"].text = str(iron)
	chips["rare"].text = str(rare)

# ---------------- SIM ----------------

func _process(delta: float) -> void:
	if game_over:
		return
	game_time += delta
	_tick_topside(delta)
	_tick_descend(delta)
	_tick_dig(delta)
	_tick_wander(delta)
	_tick_buildings(delta)
	_tick_mines(delta)
	_tick_research(delta)
	_tick_rally(delta)
	_tick_warren(delta)
	_tick_swarm(delta)
	_tick_combat(delta)
	_tick_ui(delta)
	_tick_ghost()
	if shake_amt > 0.01:
		cam.offset = Vector2(randf_range(-shake_amt, shake_amt), randf_range(-shake_amt, shake_amt))
		shake_amt *= pow(0.02, delta)
	else:
		cam.offset = Vector2.ZERO
	_water_tick(delta)

var _accel_clock := 0.0
func _tick_topside(delta: float) -> void:
	death_clock += delta
	_accel_clock += delta
	if _accel_clock > 10.0:
		_accel_clock = 0.0
		death_period *= BAL.death_accel
		warren_period *= BAL.warren_accel
	if death_clock >= death_period and pop_top > 0:
		death_clock = 0.0
		pop_top -= 1
		chips["pop"].text = str(pop_top)
		if cam.position.y < 300 and randf() < 0.4:
			puff(Vector2(100 + randf() * 440, 8 * T - 4), Color(0.7, 0.3, 0.2), 5, 4.0)

func _pop_below() -> int:
	var n := free_dudes.size() + soldiers.size() + dig_reserved.size()
	for b in buildings:
		n += b.workers.size()
	return n

func _tick_descend(delta: float) -> void:
	descend_clock += delta
	if descend_clock < BAL.descend_period:
		return
	descend_clock = 0.0
	var below := _pop_below()
	if pop_top <= 0 or below >= beds + 3:
		return
	if food_cap > 0 and below >= food_cap + 6:
		return
	pop_top -= 1
	chips["pop"].text = str(pop_top)
	var a := _spawn_free(Vector2(316, 8 * T))
	a.set_state("walk")
	var wp := [Vector2(316, 8 * T)]
	for y in range(9, 13):
		if grid[y][19] == DUG:
			wp.append(Vector2(316, y * T + T))
	a.path = wp
	_play("blip")

func _tick_dig(delta: float) -> void:
	for c in dig_marks.keys():
		if dig_reserved.has(c):
			continue
		var stand := _dig_stand_cell(c)
		if stand == Vector2i(-1, -1):
			continue
		var d := _nearest_free(Vector2(c.x * T + 8, c.y * T + 8))
		if d == null:
			break
		dig_reserved[c] = d
		free_dudes.erase(d)
		d.task = {"kind": "dig", "cell": c, "stand": stand, "progress": 0.0, "arrived": false}
		d.set_state("walk")
		d.path = _path_points(_cell_of(d), stand)
	for c in dig_reserved.keys():
		var d: Actor = dig_reserved[c]
		if not is_instance_valid(d):
			dig_reserved.erase(c)
			continue
		if d.path.is_empty():
			if not d.task.arrived:
				d.task.arrived = true
				d.set_state("dig")
				d.spr.flip_h = c.x < d.task.stand.x
			d.task.progress += delta
			if fmod(d.task.progress, 0.45) < delta:
				puff(Vector2(c.x * T + 8, c.y * T + 8), Color(0.55, 0.38, 0.25), 5, 5.0)
				_play("dig")
			var need: float = dig_time * (BAL.rock_dig_mult if grid[c.y][c.x] == ROCK else 1.0)
			if d.task.progress >= need:
				_finish_dig(c, d)

func _finish_dig(c: Vector2i, d: Actor) -> void:
	grid[c.y][c.x] = DUG
	_open_cell(c)
	_update_cells([c])
	reveal(c)
	_add_noise(Vector2(c.x * T + 8, c.y * T + 8), 1.0)
	_check_pockets(c)
	if dig_marks.has(c):
		dig_marks[c].queue_free()
		dig_marks.erase(c)
	dig_reserved.erase(c)
	d.task = {"kind": "free"}
	d.set_state("idle")
	free_dudes.append(d)

func _check_pockets(c: Vector2i) -> void:
	for p in pockets:
		if p.opened:
			continue
		var adjacent := false
		for pc in p.cells:
			if abs(pc.x - c.x) + abs(pc.y - c.y) == 1:
				adjacent = true
				break
		if not adjacent:
			continue
		p.opened = true
		for pc in p.cells:
			_open_cell(pc)
			reveal(pc)
		var center: Vector2i = p.cells[p.cells.size() / 2]
		if p.kind == "trogs":
			toast("toast_breach")
			_play("roar")
			shake(3.0)
			for i in mini(p.amount, trog_pool):
				trog_pool -= 1
				var tr := _actor("trog", Vector2(center.x * T + 8, (center.y + 1) * T) + Vector2(randf_range(-8, 8), 0))
				tr.set_state("walk")
				tr.set_meta("attack_cd", 0.0)
				trogs.append(tr)
		else:
			toast("toast_pocket")
			_play("pop")
			if p.kind == "iron":
				iron += p.amount
			else:
				rare += p.amount
			if p.node != null and is_instance_valid(p.node):
				puff(p.node.position + Vector2(7, 6), Color(0.9, 0.75, 0.4), 16, 8.0)
				p.node.queue_free()
			_refresh_stats()

func _dig_stand_cell(c: Vector2i) -> Vector2i:
	for off in [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]:
		var n: Vector2i = c + off
		if n.x >= 0 and n.x < TW and n.y >= 8 and n.y < TH and _walkable(n.x, n.y) and grid[n.y][n.x] != TROG:
			return n
	return Vector2i(-1, -1)

func _cell_of(a: Actor) -> Vector2i:
	return Vector2i(clampi(int(a.position.x / T), 0, TW - 1), clampi(int((a.position.y - 1) / T), 0, TH - 1))

func _path_points(from: Vector2i, to: Vector2i) -> Array:
	if astar.is_point_solid(from):
		for off in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
			if not astar.is_point_solid(from + off):
				from = from + off
				break
	if astar.is_point_solid(from) or astar.is_point_solid(to):
		return []
	var pts := astar.get_point_path(from, to)
	var out := []
	for p in pts:
		out.append(Vector2(p.x + T / 2.0, p.y + T))
	return out

func _nearest_free(pos: Vector2) -> Actor:
	var best: Actor = null
	var bd := 1e9
	for d in free_dudes:
		if not is_instance_valid(d) or d.task.get("kind", "") != "free":
			continue
		var dist: float = d.position.distance_to(pos)
		if dist < bd:
			bd = dist
			best = d
	return best

func _tick_buildings(_delta: float) -> void:
	for b in buildings:
		b.workers = b.workers.filter(func(w): return is_instance_valid(w))
		if b.workers.size() < b.need_workers and not b.forced_off:
			var d := _nearest_free(b.base)
			if d != null:
				free_dudes.erase(d)
				b.workers.append(d)
				d.task = {"kind": "work", "bld": b}
				d.set_state("walk")
				d.path = _path_points(_cell_of(d), Vector2i(int(b.base.x / T), int(b.base.y / T) - 1))
		var was_on: bool = b.on
		var staffed: bool = b.workers.size() >= b.need_workers
		var pwr: int = BLD[b.name].power
		var powered: bool = pwr >= 0 or power_cap - power_used + (pwr if not b.on else 0) >= 0
		b.on = staffed and powered and not b.forced_off
		if b.name == "barricade":
			b.on = not b.forced_off
		if b.on != was_on:
			var sname: String = BLD[b.name].sprite
			var p := "res://assets/sprites/%s_%d_0.png" % [sname, 1 if b.on else 0]
			if ResourceLoader.exists(p):
				b.node.texture = load(p)
			if b.light != null:
				b.light.energy = 1.15 if b.on else 0.0
			_refresh_stats()

func _tick_mines(delta: float) -> void:
	for b in buildings:
		if b.name != "mine" or not b.on:
			continue
		b.mine_t += delta
		if b.mine_t < BAL.mine_period:
			continue
		b.mine_t = 0.0
		var harvested := 0
		for n in _neighbors8(b.cells):
			if harvested >= 3:
				break
			var v: int = grid[n.y][n.x]
			if v == IRON or v == RARE:
				harvested += 1
				if v == IRON:
					iron += 1
				else:
					rare += 1
				ore_left[n] = ore_left.get(n, BAL.ore_per_cell) - 1
				if ore_left[n] <= 0:
					grid[n.y][n.x] = DIRT
					_update_cells([n])
		if harvested > 0:
			puff(b.base + Vector2(0, -10), Color(0.6, 0.5, 0.7), 4, 4.0)
			_add_noise(b.base, 1.5)
			_refresh_stats()

func _tick_research(delta: float) -> void:
	for b in buildings:
		if b.name != "lab" or not b.on or b.research.get("key", "") == "":
			continue
		b.research.progress += delta
		var key: String = b.research.key
		if b.research.progress >= TECH[key].time:
			b.research = {}
			techs[key] = true
			toast("toast_research")
			_play("pop")
			if key == "picks":
				dig_time = BAL.dig_time * 0.6
			elif key == "arms":
				BAL.soldier_dmg = 2
				BAL.soldier_fire = 0.5

func _add_noise(pos: Vector2, strength: float) -> void:
	noise_points.append({"pos": pos, "age": 0.0, "str": strength})
	if noise_points.size() > 30:
		noise_points.pop_front()
	seismo.intensity = clampf(seismo.intensity + strength * 0.02, 0.15, 1.0)

func _tick_warren(delta: float) -> void:
	for np in noise_points:
		np.age += delta
	noise_points = noise_points.filter(func(np): return np.age < 30.0)
	if game_time < BAL.warren_start_delay:
		return
	warren_clock += delta
	if warren_clock < warren_period:
		return
	warren_clock = 0.0
	for i in warren_heads.size():
		var h: Vector2i = warren_heads[i]
		var target := Vector2(h.x * T, (h.y - 8) * T)
		var best_w := 0.0
		for np in noise_points:
			var w: float = np.str * BAL.noise_pull / (1.0 + np.pos.distance_to(Vector2(h.x * T, h.y * T)) / 60.0)
			if w > best_w:
				best_w = w
				target = np.pos
		var dir := Vector2(target.x - h.x * T, target.y - h.y * T)
		var step := Vector2i(0, -1)
		if absf(dir.x) > absf(dir.y) * 0.8 and absf(dir.x) > 8:
			step = Vector2i(1 if dir.x > 0 else -1, 0)
		elif dir.y > 8:
			step = Vector2i(0, 1)
		var n := Vector2i(clampi(h.x + step.x, 2, TW - 3), clampi(h.y + step.y, 12, TH - 3))
		if grid[n.y][n.x] == ROCK or grid[n.y][n.x] == WATER or grid[n.y][n.x] == IRON or grid[n.y][n.x] == RARE:
			n = Vector2i(h.x, h.y - 1)
		if grid[n.y][n.x] == ROCK or grid[n.y][n.x] == WATER:
			continue
		if grid[n.y][n.x] == DUG or grid[n.y][n.x] == AIR:
			_breach(n, false)
			warren_heads[i] = n
			continue
		grid[n.y][n.x] = TROG
		astar.set_point_solid(n, false)
		_update_cells([n])
		warren_heads[i] = n
		if cam.position.distance_to(Vector2(n.x * T, n.y * T)) < 260:
			shake(0.6)
			_play("heart")

func _breach(at: Vector2i, big: bool) -> void:
	toast("toast_breach")
	shake(5.0)
	_play("roar")
	seismo.intensity = 1.0
	reveal(at, 3.0)
	var want: int = 999 if big else mini(3 + int(game_time / 300.0) * 2, BAL.breach_wave + 3)
	var count: int = mini(want, trog_pool)
	trog_pool -= count
	for i in count:
		var kind := "trog_big" if i % 6 == 5 else "trog"
		var tr := _actor(kind, Vector2(at.x * T + 8, at.y * T + T) + Vector2(randf_range(-6, 6), 0))
		tr.set_state("walk")
		tr.set_meta("attack_cd", 0.0)
		trogs.append(tr)

func _tick_swarm(delta: float) -> void:
	swarm_left -= delta
	seismo.countdown = maxi(0, int(swarm_left))
	seismo.intensity = maxf(seismo.intensity - delta * 0.03, clampf(1.0 - swarm_left / BAL.swarm_time, 0.15, 1.0))
	if swarm_left <= 0 and not swarm_started:
		swarm_started = true
		for h in warren_heads:
			_breach(h, true)
		get_tree().create_timer(90.0).timeout.connect(func():
			if not game_over and _pop_below() > 0:
				_end(true))

func _tick_combat(delta: float) -> void:
	trogs = trogs.filter(func(t): return is_instance_valid(t))
	soldiers = soldiers.filter(func(s): return is_instance_valid(s))
	for b in buildings:
		if b.name == "armory" and b.on and soldiers.size() < buildings.filter(func(x): return x.name == "armory").size() * 4:
			var d := _nearest_free(b.base)
			if d != null and free_dudes.size() > 2:
				free_dudes.erase(d)
				var s := _actor("soldier", d.position)
				s.task = {"kind": "soldier"}
				d.queue_free()
				soldiers.append(s)
	for tr in trogs:
		var tgt = null
		var bd := 1e9
		for d in free_dudes + soldiers:
			if is_instance_valid(d):
				var dist: float = tr.position.distance_to(d.position)
				if dist < bd:
					bd = dist
					tgt = d
		for b in buildings:
			var dist2: float = tr.position.distance_to(b.base)
			if dist2 < bd:
				bd = dist2
				tgt = b
		if tgt == null:
			continue
		var tpos: Vector2 = tgt.position if tgt is Actor else tgt.base
		if bd < 10.0:
			var cd: float = tr.get_meta("attack_cd") - delta
			tr.set_meta("attack_cd", cd)
			if cd <= 0:
				tr.set_meta("attack_cd", 1.0)
				if tgt is Actor:
					_kill_dude(tgt)
				else:
					tgt.hp -= 1
					puff(tgt.base + Vector2(0, -8), Color(0.9, 0.3, 0.2), 8, 6.0)
					if tgt.hp <= 0:
						_demolish_by_trog(tgt)
		elif tr.path.is_empty() or randf() < 0.02:
			tr.path = _path_points(_cell_of(tr), Vector2i(int(tpos.x / T), int(tpos.y / T) - 1))
			tr.set_state("walk")
	for s in soldiers:
		var near = null
		var bd2: float = BAL.soldier_range
		for tr in trogs:
			var dist3: float = s.position.distance_to(tr.position)
			if dist3 < bd2:
				bd2 = dist3
				near = tr
		var cd2: float = s.get_meta("fire_cd") if s.has_meta("fire_cd") else 0.0
		cd2 -= delta
		if near != null:
			s.spr.flip_h = near.position.x < s.position.x
			s.set_state("shoot")
			if cd2 <= 0:
				cd2 = BAL.soldier_fire
				_play("gun")
				_hit_trog(near, BAL.soldier_dmg)
		elif s.state == "shoot":
			s.set_state("idle")
		s.set_meta("fire_cd", cd2)
	for b in buildings:
		if b.name != "turret" or not b.on:
			continue
		b.fire_cd -= delta
		var near2 = null
		var bd3: float = BAL.turret_range
		for tr in trogs:
			var dist4: float = b.base.distance_to(tr.position)
			if dist4 < bd3:
				bd3 = dist4
				near2 = tr
		if near2 != null and b.fire_cd <= 0:
			b.fire_cd = BAL.turret_fire
			_play("gun")
			b.node.texture = load("res://assets/sprites/bld_turret_%d.png" % (randi() % 2))
			shake(0.4)
			_hit_trog(near2, 1)

func _hit_trog(tr: Actor, dmg: int) -> void:
	tr.hp -= dmg
	if tr.hp <= 0:
		puff(tr.position + Vector2(0, -6), Color(1.0, 0.5, 0.25), 12, 5.0)
		_play("squeak")
		trogs.erase(tr)
		tr.queue_free()

func _kill_dude(d: Actor) -> void:
	puff(d.position + Vector2(0, -8), Color(0.9, 0.3, 0.2), 10, 5.0)
	_play("squeak")
	free_dudes.erase(d)
	soldiers.erase(d)
	for b in buildings:
		b.workers.erase(d)
	d.queue_free()
	if _pop_below() <= 0 and pop_top <= 0:
		_end(false)

func _demolish_by_trog(b) -> void:
	for w in b.workers:
		if is_instance_valid(w):
			w.task = {"kind": "free"}
			free_dudes.append(w)
	if b.light != null:
		b.light.queue_free()
	if b.name == "barricade":
		for cc in b.cells:
			astar.set_point_solid(cc, false)
	puff(b.base + Vector2(0, -10), Color(0.9, 0.4, 0.2), 20, 12.0)
	b.node.queue_free()
	buildings.erase(b)
	if card_bld == b:
		_close_card()
	_refresh_stats()

func _end(won: bool) -> void:
	game_over = true
	end_card.texture = load("res://assets/ui/card_%s.png" % ("win" if won else "lose"))
	end_card.position = Vector2((UIW - end_card.texture.get_width()) / 2.0, 100)
	end_card.visible = true
	end_card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(end_card, "modulate:a", 1.0, 1.0)
	_play("pop" if won else "roar")

func _tick_ui(_delta: float) -> void:
	chips["below"].text = "%d/%d" % [_pop_below(), beds + 3]
	if card != null and card_bld != null:
		card.labels["status"] = _status_tex(card_bld)

func _tick_ghost() -> void:
	if build_sel == "":
		return
	var c := _mouse_cell()
	var spr: Sprite2D = ghost.get_node("spr")
	ghost.position = Vector2(c.x * T, (c.y + 1) * T - spr.texture.get_height())
	var ok: bool = _placement_valid(build_sel, c).ok
	ghost.modulate = Color(0.5, 1.0, 0.5, 0.6) if ok else Color(1.0, 0.4, 0.4, 0.5)

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

# ---------------- AUTOTEST ----------------

func _run_autotest() -> void:
	var script := [
		[0.5, func(): _autopaint(Rect2i(19, 13, 2, 4))],
		[1.0, func(): _autopaint(Rect2i(15, 15, 6, 2))],
		[8.0, func(): _autopaint(Rect2i(14, 17, 2, 3))],
		[9.0, func(): _autopaint(Rect2i(8, 18, 6, 2))],
		[20.0, func(): _try_place_at("living", Vector2i(16, 16))],
		[26.0, func(): _autopaint(Rect2i(21, 13, 4, 4))],
		[30.0, func(): _snap("t30")],
		[30.5, func(): iron += 40],
		[31.0, func(): _autopaint(Rect2i(6, 20, 3, 4))],
		[56.0, func(): _try_place_at("power", Vector2i(6, 23))],
		[49.0, func(): _try_place_at("farm", Vector2i(22, 16))],
		[52.0, func(): _try_place_at("lab", Vector2i(19, 16))],
		[58.0, func(): _try_place_at("mine", Vector2i(10, 19))],
		[66.0, func(): _card_test()],
		[70.0, func(): _snap("t70")],
		[71.0, func(): _set_rally(Vector2(18 * T, 12 * T))],
		[72.0, func(): _force_breach()],
		[78.0, func(): _snap("t78_fight")],
		[84.0, func(): _snap("t84")],
		[86.0, func(): get_tree().quit()],
	]
	for e in script:
		get_tree().create_timer(e[0]).timeout.connect(e[1])

func _card_test() -> void:
	for b in buildings:
		if b.name == "lab":
			card_bld = b
			iron += 30
			_card_research("picks")
			print("AUTOTEST research started: ", b.research)
			card_bld = null

func _autopaint(r: Rect2i) -> void:
	for y in range(r.position.y, r.position.y + r.size.y):
		for x in range(r.position.x, r.position.x + r.size.x):
			var c := Vector2i(x, y)
			if grid[y][x] == DIRT and not dig_marks.has(c):
				var mk := ColorRect.new()
				mk.color = Color(1.0, 0.85, 0.4, 0.35)
				mk.position = Vector2(c.x * T, c.y * T)
				mk.size = Vector2(T, T)
				marker_layer.add_child(mk)
				dig_marks[c] = mk

func _try_place_at(name: String, c: Vector2i) -> void:
	var res := _placement_valid(name, c)
	print("AUTOTEST place ", name, " at ", c, " -> ", res)
	if res.ok:
		_place(name, c)

func _force_breach() -> void:
	warren_heads[0] = Vector2i(19, 15)
	_breach(Vector2i(19, 14), false)

func _snap(tag: String) -> void:
	if DisplayServer.get_name() != "headless":
		var img := get_viewport().get_texture().get_image()
		var dir := ProjectSettings.globalize_path("res://tools/shots_game")
		DirAccess.make_dir_recursive_absolute(dir)
		img.save_png(dir + "/%s.png" % tag)
	print("AUTOTEST remaining marks: ", dig_marks.keys())
	print("AUTOTEST snap ", tag, " pop_top=", pop_top, " below=", _pop_below(), " iron=", iron, " rare=", rare,
		" beds=", beds, " food=", food_cap, " marks=", dig_marks.size(), " trogs=", trogs.size(),
		" blds=", buildings.size(), " pool=", trog_pool, " techs=", techs)
