extends Node2D
# LEMMINGS APOCALYPSE — the sign-economy pivot mock-up (2026-10-26).
# You never touch a lemming. You plant SIGNS. A sign says "this ground is now a thing."
# Civilians build it, one crowns himself boss, it runs on groups of three until you pull the sign.
# Controls: click a sign in the bar (or 1-9/QWERTY keys), click the map to plant. Right-click a sign: pick it up.
# R-drag / WASD: pan. Wheel: zoom. Esc: cancel. P: pause. F11: fullscreen. Backspace: menu.

const T := 16
const TW := 64
const TH := 84
const SURF_Y := 10               # row of grass tiles; lemmings walk on row SURF_Y-1

enum { SKY, AIR, SURF, DIRT, ROCK, DUG, BUGDUG, SPOT_FLAG, SPOT_INST, BORE }

# ---------------- BALANCE KNOBS ----------------
var BAL := {
	"lem_start": 60,
	"income_base": 25.0,         # seconds per free lemming with 0 flags
	"income_flag_bonus": 1.0,    # period = base / (1 + flags * bonus)
	"sign_tick": 90.0,           # seconds per sign point
	"start_points": 2,
	"group": 3,
	"convert_time": 12.0,
	"school_cap": 9,             # graduates per school before it only trains replacements
	"dig_time": 1.6, "rock_mult": 2.6, "eng_dig_mult": 0.55,
	"lem_speed": 42.0, "bug_speed": 30.0,
	"gas_top": 16,               # rows below SURF_Y where gas begins
	"gas_fire_penalty": 0.6, "gas_bug_bonus": 0.6,
	"pump_radius": 8.0, "seismic_radius": 10.0, "fog_radius": 4.5,
	"nest_spawn_start": 32.0, "nest_spawn_min": 6.0, "nest_spawn_ramp": 30.0,
	"bug_cap_base": 6, "bug_cap_per_min": 3.0,
	"bug_hp": 5, "queen_hp": 80, "queen_meal": 50,
	"infest_grow": 0.05,         # cells per second of nest radius growth (scaled by gas)
	"infest_max_r": 16.0,
	"nest_spread_period": 150.0, "nest_max": 14,
	"raid_group_minutes": 4.0,   # +1 raider per spawn every N minutes
	"sol_range": 6.5, "sol_fire": 0.8, "mg_range": 8.0, "mg_fire": 0.3,
	"bomb_period": 3.0, "bomb_radius": 2.5, "bomb_dmg": 4, "shaft_bombs": 6,
	"zone_hp": 20, "bug_zone_dmg": 1.5,
	"grab_time_sol": 1.6, "grab_time_eng": 0.8,
}

# Sign catalog. w/h = footprint. build = {type, n, time}. crew = {type, n}. out = conversion output.
const SIGNS := {
	"excavate":  {"name": "EXCAVATE", "key": "1", "w": 6, "h": 5, "crew": {"type": "civ", "n": 4}, "desc": "Civilians sink a ladder shaft and clear a room in the bottom three rows. Must touch open ground."},
	"nogo":      {"name": "NO-GO", "key": "2", "w": 1, "h": 1, "desc": "Lemmings will not walk within 3 tiles of this sign."},
	"training":  {"name": "TRAINING", "key": "3", "w": 6, "h": 2, "build": {"type": "civ", "n": 3, "time": 10.0}, "crew": {"type": "civ", "n": 3}, "out": "sol", "desc": "A sergeant drills civilians in threes. They come out SOLDIERS."},
	"engschool": {"name": "ENGINEERS", "key": "4", "w": 6, "h": 2, "build": {"type": "civ", "n": 3, "time": 10.0}, "crew": {"type": "civ", "n": 3}, "out": "eng", "desc": "A master engineer teaches civilians in threes. They come out ENGINEERS."},
	"patrol":    {"name": "PATROL", "key": "5", "w": 12, "h": 4, "crew": {"type": "sol", "n": 5}, "desc": "Five soldiers roam this strip and shoot anything that crawls. Soldiers fight sideways."},
	"shaft":     {"name": "STRIKE SHAFT", "key": "6", "w": 1, "h": 12, "crew": {"type": "eng", "n": 3}, "desc": "Three engineers bore a narrow hole and drop firebombs on whatever is under it. One-shot: the sign comes back when the bombs are spent."},
	"flag":      {"name": "FLAG", "key": "7", "w": 3, "h": 2, "crew": {"type": "civ", "n": 3}, "desc": "Plant on a flag spot. More lemmings trickle in, and you get another flag sign."},
	"workshop":  {"name": "WORKSHOP", "key": "8", "w": 4, "h": 2, "build": {"type": "civ", "n": 3, "time": 10.0}, "crew": {"type": "eng", "n": 2}, "desc": "Engineers man it. Unlocks SEISMIC and GAS PUMP signs."},
	"institute": {"name": "INSTITUTE", "key": "9", "w": 4, "h": 2, "build": {"type": "civ", "n": 3, "time": 12.0}, "crew": {"type": "civ", "n": 1}, "desc": "Plant on an institute spot. +1 sign point now, +1 every two minutes."},
	"mg":        {"name": "MG POST", "key": "Q", "w": 2, "h": 1, "build": {"type": "sol", "n": 2, "time": 6.0}, "crew": {"type": "sol", "n": 2}, "cost": 1, "desc": "Two soldiers dig in and hold the line. Needs a sign point."},
	"idiot":     {"name": "IDIOTS", "key": "W", "w": 6, "h": 2, "build": {"type": "civ", "n": 3, "time": 8.0}, "crew": {"type": "any", "n": 3}, "out": "civ", "cost": 1, "desc": "A professor of stupid makes soldiers and engineers watch videos until they forget everything."},
	"seismic":   {"name": "SEISMIC", "key": "E", "w": 2, "h": 2, "build": {"type": "eng", "n": 2, "time": 6.0}, "crew": {"type": "eng", "n": 2}, "cost": 1, "locked": true, "desc": "Two engineers listen to the walls. Shows the infestation and bugs nearby."},
	"pump":      {"name": "GAS PUMP", "key": "R", "w": 2, "h": 2, "build": {"type": "eng", "n": 2, "time": 8.0}, "crew": {"type": "eng", "n": 2}, "cost": 1, "locked": true, "desc": "Two engineers pump the gas out of this area. Bugs hate clean air."},
	"base":      {"name": "REAR AREA", "key": "T", "w": 10, "h": 4, "cost": 1, "desc": "Idle lemmings hang out here."},
}
const CATS := {
	"move":  {"name": "MOVEMENT", "key": "1", "icon": "icon_cat_move", "signs": ["excavate", "nogo", "base", "flag"], "start": 5, "desc": "Where lemmings go and dig."},
	"civic": {"name": "CIVIC", "key": "2", "icon": "icon_cat_civic", "signs": ["training", "engschool", "idiot", "institute"], "start": 3, "desc": "Schools: turn lemmings into other lemmings."},
	"eng":   {"name": "ENGINEERING", "key": "3", "icon": "icon_engschool", "signs": ["shaft", "workshop", "seismic", "pump"], "start": 2, "desc": "Engineers fight down."},
	"mil":   {"name": "MILITARY", "key": "4", "icon": "icon_patrol", "signs": ["patrol", "mg"], "start": 2, "desc": "Soldiers fight sideways."},
}
const CAT_ORDER := ["move", "civic", "eng", "mil"]

# ---------------- WORLD ----------------
var grid := PackedInt32Array()
var infest := PackedFloat32Array()
var nogo := PackedInt32Array()
var fogv := PackedFloat32Array()     # 1 = hidden
var terrain_img: Image
var terrain_tex: ImageTexture
var tiles := {}
var fog_img: Image
var fog_tex: ImageTexture
var over_img: Image                  # gas + infestation overlay
var over_tex: ImageTexture
var astar: AStarGrid2D               # lemmings
var bstar: AStarGrid2D               # bugs (dirt is slow, not solid)
var flag_spots := []
var inst_spots := []
var nests := []                      # {cell, r, node, t}
var queen := {}                      # {cell, pos, hp, fed, mega, node, path, dig_t}
var pumps := []
var world: Node2D
var prop_layer: Node2D
var actor_layer: Node2D
var fx_layer: Node2D
var sign_layer: Node2D
var cam: Camera2D

# ---------------- SIM ----------------
var lems := []
var bugs := []
var signs := []
var hand := {}
var unlocked := {}
var points := 0
var sign_clock := 0.0
var income_clock := 0.0
var alloc_clock := 0.0
var fog_clock := 0.0
var infest_clock := 0.0
var game_time := 0.0
var flags := 0
var kidnapped := 0
var bugs_killed := 0
var paused := false
var game_over := false
var autotest := false
var base_cell := Vector2i(32, SURF_Y - 1)
var rng := RandomNumberGenerator.new()

# ---------------- UI ----------------
var ui: CanvasLayer
var sel := ""
var ghost: Node2D
var ghost_rect: ColorRect
var top_lbl: Label
var tip_lbl: Label
var toast_lbl: Label
var toast_t := 0.0
var end_lbl: Label
var slot_nodes := {}
var drag := false
var tex_cache := {}

func _ready() -> void:
	autotest = "--autotest" in OS.get_cmdline_user_args()
	shots = "--shots" in OS.get_cmdline_user_args()
	if shots:
		Engine.time_scale = 3.0
	rng.seed = 20261026
	for c in CATS:
		hand[c] = CATS[c].start
		ledger[c].append(["Start", CATS[c].start])
	ledger.points.append(["Start", BAL.start_points])
	for k in SIGNS:
		unlocked[k] = not SIGNS[k].get("locked", false)
	points = BAL.start_points
	_load_tiles()
	_build_grid()
	_build_layers()
	_render_terrain()
	_build_astar()
	_build_overlays()
	_start_state()
	_build_ui()
	if autotest:
		_run_autotest()

func tex(n: String) -> Texture2D:
	if not tex_cache.has(n):
		tex_cache[n] = load("res://assets/signs/%s.png" % n)
	return tex_cache[n]

func _load_tiles() -> void:
	for k in ["dirt", "rock", "dug", "bugdug", "sky", "surf"]:
		var arr := []
		for i in 4:
			arr.append(Image.load_from_file(ProjectSettings.globalize_path("res://assets/signs/t_%s_%d.png" % [k, i])))
		tiles[k] = arr
	for k in ["e_top", "e_floor", "e_left", "e_right", "e_bug_top", "e_bug_bot", "e_bug_left", "e_bug_right", "spot_flag", "spot_inst"]:
		tiles[k] = Image.load_from_file(ProjectSettings.globalize_path("res://assets/signs/%s.png" % k))

func idx(x: int, y: int) -> int:
	return y * TW + x

func cell(x: int, y: int) -> int:
	if x < 0 or x >= TW or y < 0 or y >= TH:
		return ROCK
	return grid[idx(x, y)]

func is_open(x: int, y: int) -> bool:
	var v := cell(x, y)
	return v == AIR or v == DUG or v == BUGDUG or v == SPOT_FLAG or v == SPOT_INST

func is_diggable(x: int, y: int) -> bool:
	var v := cell(x, y)
	return v == DIRT or v == ROCK or v == SURF

func _build_grid() -> void:
	grid.resize(TW * TH)
	infest.resize(TW * TH)
	nogo.resize(TW * TH)
	fogv.resize(TW * TH)
	for y in TH:
		for x in TW:
			var v := DIRT
			if y < SURF_Y - 1:
				v = SKY
			elif y == SURF_Y - 1:
				v = AIR
			elif y == SURF_Y:
				v = SURF
			else:
				# rock bands + rock blobs
				var n := _noise(x, y)
				if (y > 22 and y < 25 and n > 0.5) or (y > 44 and y < 47 and n > 0.5) or n > 0.84:
					v = ROCK
			grid[idx(x, y)] = v
			fogv[idx(x, y)] = 0.0 if y < SURF_Y + 3 else 1.0
	# starting trench (the rear area) — like Andy's: surface base, dug into the ground
	for y in range(SURF_Y, SURF_Y + 3):
		for x in range(22, 42):
			grid[idx(x, y)] = DUG
	# flag spots: in small pre-dug pockets, increasingly deep / far
	for c in [Vector2i(10, 19), Vector2i(53, 21), Vector2i(20, 36), Vector2i(46, 40), Vector2i(8, 56), Vector2i(56, 58)]:
		_pocket(c, 2, DUG)
		grid[idx(c.x, c.y)] = SPOT_FLAG
		flag_spots.append(c)
	for c in [Vector2i(32, 30), Vector2i(31, 52)]:
		_pocket(c, 2, DUG)
		grid[idx(c.x, c.y)] = SPOT_INST
		inst_spots.append(c)
	# bug country: organic blobs with nests, queen chamber at the bottom
	var nest_cells := [Vector2i(12, 70), Vector2i(50, 72), Vector2i(28, 66), Vector2i(40, 76), Vector2i(6, 78), Vector2i(58, 66)]
	for c in nest_cells:
		_blob(c, 4)
		nests.append({"cell": c, "r": 3.0, "t": 20.0 + rng.randf() * 30.0})
	_blob(Vector2i(32, 79), 6)
	for i in range(nest_cells.size()):
		_tunnel(nest_cells[i], Vector2i(32, 79))
	queen = {"cell": Vector2i(32, 79), "pos": Vector2(32 * T + T / 2.0, 79 * T + T), "hp": BAL.queen_hp, "fed": 0, "mega": false, "path": [], "dig_t": 0.0, "spawn_t": 0.0}

func _noise(x: int, y: int) -> float:
	var v := int(x * 374761393 + y * 668265263) & 0xFFFFFFFF
	v = (v ^ (v >> 13)) * 1274126177 & 0xFFFFFFFF
	v = (v ^ (v >> 16)) & 0xFFFF
	var a := v / 65535.0
	var b := sin(x * 0.35 + y * 0.2) * 0.5 + 0.5
	return a * 0.6 + b * 0.4

func _pocket(c: Vector2i, r: int, v: int) -> void:
	for dy in range(-r + 1, r):
		for dx in range(-r, r + 1):
			var x := c.x + dx
			var y := c.y + dy
			if x > 0 and x < TW - 1 and y > SURF_Y and y < TH - 1 and grid[idx(x, y)] != SPOT_FLAG and grid[idx(x, y)] != SPOT_INST:
				grid[idx(x, y)] = v

func _blob(c: Vector2i, r: int) -> void:
	for dy in range(-r, r + 1):
		for dx in range(-r - 1, r + 2):
			var x := c.x + dx
			var y := c.y + dy
			if x <= 0 or x >= TW - 1 or y <= SURF_Y + 2 or y >= TH - 1:
				continue
			if Vector2(dx * 0.8, dy).length() <= r - rng.randf() * 1.2:
				grid[idx(x, y)] = BUGDUG

func _tunnel(a: Vector2i, b: Vector2i) -> void:
	var p := a
	var guard := 0
	while p != b and guard < 400:
		guard += 1
		if rng.randf() < 0.5 and p.x != b.x:
			p.x += sign(b.x - p.x)
		elif p.y != b.y:
			p.y += sign(b.y - p.y)
		else:
			p.x += sign(b.x - p.x)
		if p.x > 0 and p.x < TW - 1 and p.y > SURF_Y + 2 and p.y < TH - 1:
			grid[idx(p.x, p.y)] = BUGDUG
			if rng.randf() < 0.4 and p.x + 1 < TW - 1:
				grid[idx(p.x + 1, p.y)] = BUGDUG

func _build_layers() -> void:
	world = Node2D.new()
	add_child(world)
	terrain_img = Image.create(TW * T, TH * T, false, Image.FORMAT_RGBA8)
	terrain_tex = ImageTexture.create_from_image(terrain_img)
	var ts := Sprite2D.new()
	ts.texture = terrain_tex
	ts.centered = false
	world.add_child(ts)
	prop_layer = Node2D.new()
	world.add_child(prop_layer)
	actor_layer = Node2D.new()
	world.add_child(actor_layer)
	fx_layer = Node2D.new()
	world.add_child(fx_layer)
	sign_layer = Node2D.new()
	world.add_child(sign_layer)
	# nests + queen sprites
	for n in nests:
		var s := Sprite2D.new()
		s.texture = tex("bug_nest")
		s.position = Vector2(n.cell.x * T + T / 2.0, n.cell.y * T + T - 10)
		prop_layer.add_child(s)
		n["node"] = s
	var q := Sprite2D.new()
	q.texture = tex("bug_queen")
	q.position = queen.pos - Vector2(0, 20)
	prop_layer.add_child(q)
	queen["node"] = q
	cam = Camera2D.new()
	cam.position = Vector2(base_cell.x * T, (SURF_Y + 2) * T)
	cam.zoom = Vector2(1.6, 1.6)
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = TW * T
	cam.limit_bottom = TH * T
	add_child(cam)
	cam.make_current()

func _render_terrain() -> void:
	for y in TH:
		for x in TW:
			_paint_cell(x, y)
	terrain_tex.update(terrain_img)

func _paint_cell(x: int, y: int) -> void:
	var v := grid[idx(x, y)]
	var k := "dirt"
	match v:
		SKY: k = "sky"
		AIR: k = "sky"
		SURF: k = "surf"
		ROCK: k = "rock"
		DUG, SPOT_FLAG, SPOT_INST, BORE: k = "dug"
		BUGDUG: k = "bugdug"
	var src: Image = tiles[k][(x * 7 + y * 13) % 4]
	if v == SKY or v == AIR:
		var f := float(y) / float(SURF_Y)
		terrain_img.fill_rect(Rect2i(x * T, y * T, T, T), Color(0.16, 0.12, 0.18).lerp(Color(0.55, 0.36, 0.28), f * f))
		if v == AIR:
			terrain_img.blend_rect(tiles.sky[(x * 7) % 4], Rect2i(0, 0, T, T), Vector2i(x * T, y * T))
		return
	terrain_img.blit_rect(src, Rect2i(0, 0, T, T), Vector2i(x * T, y * T))
	var dst := Vector2i(x * T, y * T)
	if v == BORE:
		terrain_img.blend_rect(tiles.e_left, Rect2i(0, 0, T, T), dst)
		terrain_img.blend_rect(tiles.e_right, Rect2i(0, 0, T, T), dst)
		if cell(x, y + 1) != BORE:
			terrain_img.blend_rect(tiles.e_floor, Rect2i(0, 0, T, T), dst)
		return
	if v == DUG or v == SPOT_FLAG or v == SPOT_INST:
		if not is_open(x, y - 1) and cell(x, y - 1) != SKY:
			terrain_img.blend_rect(tiles.e_top, Rect2i(0, 0, T, T), dst)
		if not is_open(x, y + 1):
			terrain_img.blend_rect(tiles.e_floor, Rect2i(0, 0, T, T), dst)
		if not is_open(x - 1, y):
			terrain_img.blend_rect(tiles.e_left, Rect2i(0, 0, T, T), dst)
		if not is_open(x + 1, y):
			terrain_img.blend_rect(tiles.e_right, Rect2i(0, 0, T, T), dst)
		if v == SPOT_FLAG:
			terrain_img.blend_rect(tiles.spot_flag, Rect2i(0, 0, T, T), dst)
		elif v == SPOT_INST:
			terrain_img.blend_rect(tiles.spot_inst, Rect2i(0, 0, T, T), dst)
	elif v == BUGDUG:
		if not is_open(x, y - 1):
			terrain_img.blend_rect(tiles.e_bug_top, Rect2i(0, 0, T, T), dst)
		if not is_open(x, y + 1):
			terrain_img.blend_rect(tiles.e_bug_bot, Rect2i(0, 0, T, T), dst)
		if not is_open(x - 1, y):
			terrain_img.blend_rect(tiles.e_bug_left, Rect2i(0, 0, T, T), dst)
		if not is_open(x + 1, y):
			terrain_img.blend_rect(tiles.e_bug_right, Rect2i(0, 0, T, T), dst)

func _repaint_around(c: Vector2i) -> void:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var x := c.x + dx
			var y := c.y + dy
			if x >= 0 and x < TW and y >= 0 and y < TH:
				_paint_cell(x, y)
	terrain_tex.update(terrain_img)

func _build_astar() -> void:
	astar = AStarGrid2D.new()
	astar.region = Rect2i(0, 0, TW, TH)
	astar.cell_size = Vector2(T, T)
	astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	astar.update()
	bstar = AStarGrid2D.new()
	bstar.region = Rect2i(0, 0, TW, TH)
	bstar.cell_size = Vector2(T, T)
	bstar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_NEVER
	bstar.update()
	for y in TH:
		for x in TW:
			_sync_cell(Vector2i(x, y))

func _sync_cell(c: Vector2i) -> void:
	var v := grid[idx(c.x, c.y)]
	var open := is_open(c.x, c.y)
	astar.set_point_solid(c, not open or nogo[idx(c.x, c.y)] > 0)
	if v == SKY:
		bstar.set_point_solid(c, true)
	elif open:
		bstar.set_point_solid(c, false)
		bstar.set_point_weight_scale(c, 1.0 if v == BUGDUG else 1.6)
	elif v == ROCK:
		bstar.set_point_solid(c, false)
		bstar.set_point_weight_scale(c, 20.0)
	else:
		bstar.set_point_solid(c, false)
		bstar.set_point_weight_scale(c, 7.0)

func set_cell(c: Vector2i, v: int) -> void:
	grid[idx(c.x, c.y)] = v
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := Vector2i(c.x + dx, c.y + dy)
			if n.x >= 0 and n.x < TW and n.y >= 0 and n.y < TH:
				_sync_cell(n)
	_repaint_around(c)

# ---------------- OVERLAYS: fog, gas, infestation ----------------
func _build_overlays() -> void:
	fog_img = Image.create(TW, TH, false, Image.FORMAT_RGBA8)
	fog_tex = ImageTexture.create_from_image(fog_img)
	over_img = Image.create(TW, TH, false, Image.FORMAT_RGBA8)
	over_tex = ImageTexture.create_from_image(over_img)
	for t in [over_tex, fog_tex]:
		var s := Sprite2D.new()
		s.texture = t
		s.centered = false
		s.scale = Vector2(T, T)
		s.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		world.add_child(s)
	_update_overlays()

func gas_at(x: int, y: int) -> float:
	var top: int = SURF_Y + BAL.gas_top
	if y < top:
		return 0.0
	var g: float = clamp(float(y - top) / float(TH - top), 0.0, 1.0) * 0.9 + 0.1
	for p in pumps:
		var d: float = Vector2(x - p.x, y - p.y).length()
		if d < BAL.pump_radius:
			g *= clamp(d / BAL.pump_radius, 0.0, 1.0) * 0.5
	return g

func _update_overlays() -> void:
	for y in TH:
		for x in TW:
			var i := idx(x, y)
			var g := gas_at(x, y)
			var inf := infest[i]
			var col := Color(0.35, 0.8, 0.2, g * 0.28)
			if inf > 0.0:
				col = col.lerp(Color(0.9, 0.15, 0.2, 0.25 + inf * 0.45), clamp(inf * 1.5, 0.0, 1.0))
			over_img.set_pixel(x, y, col)
			var f := fogv[i]
			if f > 0.0 and inf > 0.05:
				fog_img.set_pixel(x, y, Color(0.3, 0.02, 0.05, 0.55))   # the infestation shows through the fog
			else:
				fog_img.set_pixel(x, y, Color(0.02, 0.01, 0.02, f * 0.93))
	over_tex.update(over_img)
	fog_tex.update(fog_img)

func reveal(c: Vector2i, radius: float) -> void:
	var r := int(ceil(radius))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var x := c.x + dx
			var y := c.y + dy
			if x < 0 or x >= TW or y < 0 or y >= TH:
				continue
			if Vector2(dx, dy).length() <= radius:
				fogv[idx(x, y)] = 0.0

func is_hidden(c: Vector2i) -> bool:
	return fogv[idx(c.x, c.y)] > 0.0

# ---------------- ACTORS ----------------
class Lem extends Node2D:
	var kind := "civ"
	var spr: Sprite2D
	var hat: Sprite2D
	var frames := []
	var anim_t := 0.0
	var path := []
	var speed := 42.0
	var job = null          # Dictionary (sign) or null
	var role := ""
	var timer := 0.0
	var hp := 1
	var wander_t := 0.0
	var scream_t := 0.0
	var carried := false
	var face := 1
	var rank := ""          # "", "sergeant", "master"
	var pose := ""
	var pose_frames := []
	var pose_rate := 4.0
	var g_ref = null
	func set_kind(k: String, g) -> void:
		kind = k
		g_ref = g
		frames = [g.tex("lem_%s_0" % k), g.tex("lem_%s_1" % k)]
		spr.texture = frames[0]
		hp = 3 if k == "sol" else (2 if k == "eng" else 1)
		if pose != "":
			set_pose(pose, pose_rate)
	func set_pose(p: String, rate: float = 4.0) -> void:
		pose = p
		pose_rate = rate
		if p == "":
			pose_frames = []
			return
		pose_frames = [g_ref.tex("lem_%s_%s_0" % [kind, p]), g_ref.tex("lem_%s_%s_1" % [kind, p])]
	func anim(delta: float, moving: bool) -> void:
		if scream_t > 0.0:
			scream_t -= delta
			spr.texture = frames[0] if kind != "civ" else spr.texture
			return
		if moving:
			anim_t += delta * 8.0
			spr.texture = frames[int(anim_t) % 2]
			spr.flip_h = face < 0
		elif pose != "" and not pose_frames.is_empty():
			anim_t += delta * pose_rate
			spr.texture = pose_frames[int(anim_t) % 2]
			spr.flip_h = face < 0
		else:
			spr.texture = frames[0]

class Bug extends Node2D:
	var spr: Sprite2D
	var frames := []
	var anim_t := 0.0
	var path := []
	var target = null       # Lem
	var carrying = null     # Lem
	var hp := 3
	var dig_t := 0.0
	var grab_t := 0.0
	var retarget_t := 0.0
	var home := Vector2i()
	var state := "hunt"
	var flash_t := 0.0

func _spawn_lem(kind: String, pos: Vector2) -> Lem:
	var l := Lem.new()
	l.spr = Sprite2D.new()
	l.spr.offset = Vector2(0, -8)
	l.add_child(l.spr)
	l.hat = Sprite2D.new()
	l.hat.offset = Vector2(0, -18)
	l.hat.visible = false
	l.add_child(l.hat)
	l.position = pos
	l.speed = BAL.lem_speed * (0.9 + rng.randf() * 0.2)
	l.set_kind(kind, self)
	l.wander_t = rng.randf() * 3.0
	actor_layer.add_child(l)
	lems.append(l)
	return l

func _spawn_bug(c: Vector2i) -> Bug:
	var b := Bug.new()
	b.spr = Sprite2D.new()
	b.spr.offset = Vector2(0, -6)
	b.add_child(b.spr)
	b.frames = [tex("bug_raider_0"), tex("bug_raider_1")]
	b.spr.texture = b.frames[0]
	b.position = cell_pos(c)
	b.hp = BAL.bug_hp
	b.home = c
	actor_layer.add_child(b)
	bugs.append(b)
	return b

func cell_pos(c: Vector2i) -> Vector2:
	return Vector2(c.x * T + T / 2.0, c.y * T + T)

func cell_of(n: Node2D) -> Vector2i:
	return Vector2i(int(n.position.x / T), int((n.position.y - 1.0) / T))

func _start_state() -> void:
	for i in BAL.lem_start:
		var x := 22 * T + rng.randf() * 20 * T
		_spawn_lem("civ", Vector2(x, (SURF_Y + 3) * T + T))
	# the default rear area sign over the starting trench
	_place_sign("base", Vector2i(27, SURF_Y - 1), true)
	for l in lems:
		reveal(cell_of(l), BAL.fog_radius)
	_recompute_infest()
	_update_overlays()

# ---------------- PATHING ----------------
func path_to(from: Vector2i, to: Vector2i, grid_: AStarGrid2D) -> Array:
	if grid_.is_point_solid(from):
		for off in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
			var n: Vector2i = from + off
			if n.x >= 0 and n.x < TW and n.y >= 0 and n.y < TH and not grid_.is_point_solid(n):
				from = n
				break
	if grid_.is_point_solid(from) or grid_.is_point_solid(to):
		return []
	var pts := grid_.get_point_path(from, to)
	var out := []
	for p in pts:
		out.append(Vector2(p.x + T / 2.0, p.y + T))
	return out

func _move_along(n: Node2D, delta: float, speed: float) -> bool:
	# returns true if moved
	if n.path.is_empty():
		return false
	var tgt: Vector2 = n.path[0]
	var d := tgt - n.position
	var step := speed * delta
	if d.length() <= step:
		n.position = tgt
		n.path.pop_front()
	else:
		n.position += d.normalized() * step
	if n is Lem and abs(d.x) > 0.5:
		n.face = 1 if d.x > 0 else -1
	return true

func _open_neighbor(c: Vector2i) -> Vector2i:
	# an open, walkable cell adjacent to c (prefers below/side), or (-1,-1)
	for off in [Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1)]:
		var n: Vector2i = c + off
		if n.x >= 0 and n.x < TW and n.y >= 0 and n.y < TH and not astar.is_point_solid(n):
			return n
	return Vector2i(-1, -1)

func _reachable(c: Vector2i) -> bool:
	return not astar.is_point_solid(c) and not path_to(base_cell, c, astar).is_empty()

# ---------------- SIGNS ----------------
func is_foundation(c: Vector2i) -> bool:
	for s in signs:
		if s.type in ["excavate", "nogo", "patrol", "base", "shaft"]:
			continue
		if c.y == s.rect.end.y and c.x >= s.rect.position.x and c.x < s.rect.end.x:
			return true
	return false

func _rect_has_foundation(r: Rect2i) -> bool:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if is_foundation(Vector2i(x, y)):
				return true
	return false

func cat_of(type: String) -> String:
	for c in CATS:
		if type in CATS[c].signs:
			return c
	return "move"

func sign_rect(type: String, c: Vector2i) -> Rect2i:
	return Rect2i(c, Vector2i(SIGNS[type].w, SIGNS[type].h))

func _overlaps(r: Rect2i, ignore_types: Array = ["nogo", "patrol", "base"]) -> bool:
	for s in signs:
		if s.type in ignore_types:
			continue
		if s.rect.intersects(r):
			return true
	return false

func placement(type: String, c: Vector2i) -> Dictionary:
	var r := sign_rect(type, c)
	if r.position.x < 1 or r.end.x > TW - 1 or r.position.y < SURF_Y - 1 or r.end.y > TH - 1:
		return {"ok": false, "why": "Off the map."}
	match type:
		"excavate":
			if r.position.y < SURF_Y:
				return {"ok": false, "why": "Dig below the surface."}
			if _overlaps(r):
				return {"ok": false, "why": "Overlaps another sign."}
			var diggable := 0
			var touching := false
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if is_diggable(x, y):
						diggable += 1
						for off in [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]:
							var n: Vector2i = Vector2i(x, y) + off
							if is_open(n.x, n.y) and cell(n.x, n.y) != BUGDUG:
								touching = true
					elif is_open(x, y):
						touching = true
			if diggable == 0:
				return {"ok": false, "why": "Nothing to dig here."}
			if not touching:
				return {"ok": false, "why": "Must touch an open area."}
			if _rect_has_foundation(r):
				return {"ok": false, "why": "That ground holds up a building."}
			return {"ok": true}
		"nogo":
			return {"ok": true}
		"patrol", "base":
			var open := 0
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if is_open(x, y) and not astar.is_point_solid(Vector2i(x, y)):
						open += 1
			if open < 4:
				return {"ok": false, "why": "Needs open ground to stand on."}
			return {"ok": true}
		"shaft":
			if _overlaps(r):
				return {"ok": false, "why": "Overlaps another sign."}
			for x in range(r.position.x, r.end.x):
				if not is_open(x, r.position.y):
					return {"ok": false, "why": "Top row must be open floor."}
			if is_open(r.position.x, r.position.y + 1):
				return {"ok": false, "why": "Nothing to bore into."}
			if _rect_has_foundation(r):
				return {"ok": false, "why": "That ground holds up a building."}
			return {"ok": true}
		"flag", "institute":
			var want := SPOT_FLAG if type == "flag" else SPOT_INST
			var spot := Vector2i(-1, -1)
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if cell(x, y) == want:
						spot = Vector2i(x, y)
			if spot.x < 0:
				return {"ok": false, "why": "Must sit on a %s spot." % ("flag" if type == "flag" else "institute")}
			if _overlaps(r):
				return {"ok": false, "why": "Overlaps another sign."}
			if not _reachable(spot):
				return {"ok": false, "why": "Dig a way to it first."}
			return {"ok": true, "spot": spot}
		_:
			# zone: footprint must be open, reachable, and sit on a floor
			if _overlaps(r):
				return {"ok": false, "why": "Overlaps another sign."}
			for y in range(r.position.y, r.end.y):
				for x in range(r.position.x, r.end.x):
					if not is_open(x, y) or cell(x, y) == BUGDUG:
						return {"ok": false, "why": "Needs dug-out ground."}
			for x in range(r.position.x, r.end.x):
				if is_open(x, r.end.y):
					return {"ok": false, "why": "Needs a floor under it."}
			if not _reachable(Vector2i(r.position.x, r.end.y - 1)):
				return {"ok": false, "why": "Lemmings can't get there."}
			return {"ok": true}

func _place_sign(type: String, c: Vector2i, free: bool = false) -> Dictionary:
	var pl := placement(type, c)
	if not pl.ok:
		toast(pl.why)
		return {}
	if not free:
		if hand.get(cat_of(type), 0) <= 0:
			toast("No %s signs left." % CATS[cat_of(type)].name)
			return {}
		hand[cat_of(type)] -= 1
	var r := sign_rect(type, c)
	var s := {"type": type, "rect": r, "cell": c, "phase": "build" if SIGNS[type].has("build") else "active",
		"progress": 0.0, "crew": [], "hp": BAL.zone_hp, "timer": 0.0, "cycle": 0.0, "props": [], "done": false,
		"spot": pl.get("spot", Vector2i(-1, -1)), "work": Vector2i(r.position.x + r.size.x / 2, r.end.y - 1), "dig_cells": [], "bomb_t": 0.0}
	if type == "shaft":
		s.work = Vector2i(r.position.x, r.position.y)
		s["bombs"] = BAL.shaft_bombs
	if type == "excavate":
		_refresh_dig_cells(s)
		s.work = _dig_stand(s)
	if type == "flag" or type == "institute":
		s.work = s.spot
	# sign board
	var node := Node2D.new()
	var board := Sprite2D.new()
	board.texture = tex("sign_%s" % type)
	board.position = Vector2(r.position.x * T + T / 2.0 + (2 if type != "nogo" else 0), r.end.y * T - 13)
	if type == "excavate" or type == "shaft":
		board.position = Vector2(r.position.x * T + 8, r.position.y * T - 2)
	node.add_child(board)
	node.set_meta("sign", s)
	sign_layer.add_child(node)
	s["node"] = node
	s["board"] = board
	# zone outline
	var outline := ColorRect.new()
	outline.position = Vector2(r.position * T)
	outline.size = Vector2(r.size * T)
	outline.color = Color(1, 1, 1, 0.0)
	outline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_child(outline)
	s["outline"] = outline
	signs.append(s)
	s["enabled"] = true
	if SIGNS[type].has("build"):
		var site := _add_prop(s, "prop_site", Vector2(r.position.x * T + r.size.x * T / 2.0, r.end.y * T - 8))
		site.modulate = Color(1, 1, 1, 0.8)
		s["site"] = site
	match type:
		"nogo":
			_apply_nogo(c, 1)
		"base":
			pass
		"excavate":
			pass
		"shaft":
			for y in range(r.position.y + 1, r.end.y):
				for x in range(r.position.x, r.end.x):
					s.dig_cells.append(Vector2i(x, y))
	_refresh_slots()
	return s

func _apply_nogo(c: Vector2i, d: int) -> void:
	for dy in range(-3, 4):
		for dx in range(-3, 4):
			var n := c + Vector2i(dx, dy)
			if n.x < 0 or n.x >= TW or n.y < 0 or n.y >= TH or Vector2(dx, dy).length() > 3.2:
				continue
			nogo[idx(n.x, n.y)] += d
			_sync_cell(n)

func _dig_stand(s: Dictionary) -> Vector2i:
	# an open cell adjacent to the footprint, highest first (lemmings come from above)
	var best := Vector2i(-1, -1)
	for c in s.dig_cells:
		var n := _open_neighbor(c)
		if n.x >= 0 and (best.x < 0 or n.y < best.y):
			best = n
	if best.x < 0:
		best = s.work
	return best

func _make_plan(s: Dictionary) -> void:
	# A room in the bottom 3 rows, reached by a 1-wide ladder shaft from wherever the block touches open ground.
	var r: Rect2i = s.rect
	var room_top := r.end.y - 3
	var entry := Vector2i(-1, -1)
	var best := 1e9
	var cx := r.position.x + r.size.x / 2
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			var c := Vector2i(x, y)
			var touches := false
			for off in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
				var n: Vector2i = c + off
				if not r.has_point(n) and is_open(n.x, n.y) and cell(n.x, n.y) != BUGDUG:
					touches = true
			if is_open(x, y) and cell(x, y) != BUGDUG:
				touches = true
			if touches:
				var score: float = (y - r.position.y) * 10.0 + abs(x - cx)
				if y >= room_top:
					score = abs(x - cx) * 0.1
				if score < best:
					best = score
					entry = c
	var plan := []
	var shaft := []
	if entry.x >= 0:
		var y := entry.y
		while y < room_top:
			shaft.append(Vector2i(entry.x, y))
			y += 1
	for y in range(room_top, r.end.y):
		for x in range(r.position.x, r.end.x):
			plan.append(Vector2i(x, y))
	s["shaft"] = shaft
	s["plan"] = shaft + plan

func _refresh_dig_cells(s: Dictionary) -> void:
	s.dig_cells.clear()
	if not s.has("plan"):
		_make_plan(s)
	for c in s.plan:
		if is_diggable(c.x, c.y) and not is_foundation(c):
			s.dig_cells.append(c)

func remove_sign(s: Dictionary, give_back: bool = true) -> void:
	if not s in signs:
		return
	signs.erase(s)
	for l in s.crew.duplicate():
		_release(l)
	if s.type == "nogo":
		_apply_nogo(s.cell, -1)
	if s.type == "pump":
		pumps.erase(s.rect.position)
		_update_overlays()
	for p in s.props:
		if is_instance_valid(p):
			p.queue_free()
	if is_instance_valid(s.node):
		s.node.queue_free()
	if give_back:
		hand[cat_of(s.type)] = hand.get(cat_of(s.type), 0) + 1
	_refresh_slots()

func _release(l: Lem) -> void:
	if not is_instance_valid(l):
		return
	if l.job != null and l in l.job.crew:
		l.job.crew.erase(l)
	l.job = null
	l.role = ""
	l.path = []
	l.hat.visible = l.rank != ""
	l.timer = 0.0
	l.set_pose("")
	if l.has_meta("spot"):
		l.remove_meta("spot")

func _add_prop(s: Dictionary, name: String, pos: Vector2) -> Sprite2D:
	var p := Sprite2D.new()
	p.texture = tex(name)
	p.position = pos
	prop_layer.add_child(p)
	s.props.append(p)
	return p

func _activate(s: Dictionary) -> void:
	s.phase = "active"
	s.progress = 0.0
	var r: Rect2i = s.rect
	var fy := r.end.y * T
	if s.has("site") and is_instance_valid(s.site):
		s.props.erase(s.site)
		s.site.queue_free()
	puff(Vector2(r.position.x * T + r.size.x * T / 2.0, fy - 8), Color(0.9, 0.8, 0.5), 16, 14.0)
	_play("pop")
	match s.type:
		"training":
			for i in 3:
				_add_prop(s, "prop_target", Vector2(r.position.x * T + 20 + i * 24, fy - 8))
			_add_prop(s, "prop_podium", Vector2(r.position.x * T + 8, fy - 8))
		"engschool":
			_add_prop(s, "prop_engine", Vector2(r.position.x * T + 48, fy - 8))
			_add_prop(s, "prop_podium", Vector2(r.position.x * T + 8, fy - 8))
		"idiot":
			_add_prop(s, "prop_tv", Vector2(r.position.x * T + 48, fy - 8))
		"mg":
			_add_prop(s, "prop_mg", Vector2(r.position.x * T + 16, fy - 8))
		"workshop":
			_add_prop(s, "prop_workshop", Vector2(r.position.x * T + 32, fy - 12))
		"seismic":
			_add_prop(s, "prop_thumper", Vector2(r.position.x * T + 16, fy - 12))
		"pump":
			var p := _add_prop(s, "prop_pump", Vector2(r.position.x * T + 16, fy - 16))
			p.z_index = -1
			pumps.append(r.position)
			_update_overlays()
		"institute":
			_add_prop(s, "prop_institute", Vector2(s.spot.x * T + 8, s.spot.y * T + 4))
			gain_point("Institute opened")
	# keep the first builder as the operator (hat)
	if s.has("build") or SIGNS[s.type].has("build"):
		var op = null
		for l in s.crew.duplicate():
			if op == null and (SIGNS[s.type].crew.type == "any" or l.kind == SIGNS[s.type].crew.type or s.type in ["training", "engschool", "idiot", "institute"]):
				op = l
			else:
				_release(l)
		if op != null and s.type in ["training", "engschool"]:
			s.crew.erase(op)
			var rank_needed := "sergeant" if s.type == "training" else "master"
			var boss = _free_ranked(rank_needed)
			if boss == null and not schools_ever.get(s.type, false):
				boss = op             # the very first school: a civilian crowns himself
				boss.rank = rank_needed
				boss.set_kind("sol" if s.type == "training" else "eng", self)
				toast("%s crowns himself %s." % ["A civilian", "Sergeant" if s.type == "training" else "Master Engineer"])
			else:
				_release(op)
			if boss == null:
				s.phase = "staffing"
				toast("%s built, but it needs a free %s to run it." % [SIGNS[s.type].name, rank_needed])
				_refresh_slots()
				return
			schools_ever[s.type] = true
			_seat_boss(s, boss)
		elif op != null and s.type in ["idiot", "institute"]:
			op.role = "operator"
			op.hat.texture = tex("hat_prof")
			op.hat.visible = true
			op.path = path_to(cell_of(op), Vector2i(r.position.x, r.end.y - 1), astar)
			op.set_pose("boss", 1.5)
			op.face = 1
			s["operator"] = op
			s.crew.erase(op)
		elif op != null:
			_release(op)
	_refresh_slots()

var schools_ever := {}
func _free_ranked(rank: String):
	var best = null
	for l in lems:
		if is_instance_valid(l) and not l.carried and l.rank == rank and l.job == null and l.role == "":
			best = l
			break
	return best

func _seat_boss(s: Dictionary, boss: Lem) -> void:
	var r: Rect2i = s.rect
	boss.job = s
	boss.role = "operator"
	boss.hat.texture = tex("hat_sergeant" if boss.rank == "sergeant" else "hat_master")
	boss.hat.visible = true
	boss.path = path_to(cell_of(boss), Vector2i(r.position.x, r.end.y - 1), astar)
	boss.set_pose("boss", 1.5)
	boss.face = 1
	s["operator"] = boss
	s["roster"] = []
	s["boss_done"] = false
	s.phase = "active"

func _roster_alive(s: Dictionary) -> int:
	var n := 0
	for l in s.get("roster", []).duplicate():
		if is_instance_valid(l) and l in lems and l.kind == SIGNS[s.type].out and not l.carried:
			n += 1
		else:
			s.roster.erase(l)
	return n

func _want(s: Dictionary) -> Dictionary:
	# what kind of lemming does this sign want right now, and how many more
	var d: Dictionary = SIGNS[s.type]
	if s.done or not s.get("enabled", true):
		return {}
	if s.phase == "build":
		return {"type": d.build.type, "n": d.build.n - s.crew.size()}
	if s.phase == "staffing":
		return {}
	if d.has("crew"):
		if s.type == "flag" and s.get("planted", false):
			return {}
		if s.type in ["training", "engschool"]:
			var missing: int = BAL.school_cap - _roster_alive(s)
			if missing <= 0:
				if s.get("boss_done", false):
					return {}
				missing = 1            # the last graduate becomes a sergeant / master engineer
			return {"type": d.crew.type, "n": min(missing, d.crew.n) - s.crew.size()}
		return {"type": d.crew.type, "n": d.crew.n - s.crew.size()}
	return {}

func _tick_alloc() -> void:
	# deeper sign wins, within each lemming type
	var sorted := signs.duplicate()
	sorted.sort_custom(func(a, b): return a.rect.position.y > b.rect.position.y)
	var idle := {"civ": [], "sol": [], "eng": []}
	for l in lems:
		if l.job == null and not l.carried:
			idle[l.kind].append(l)
	for s in sorted:
		var w := _want(s)
		if w.is_empty() or w.n <= 0:
			continue
		var pool := []
		if w.type == "any":
			pool = idle.sol + idle.eng
		else:
			pool = idle[w.type]
		if pool.is_empty():
			continue
		var wp := cell_pos(s.work)
		pool.sort_custom(func(a, b): return a.position.distance_squared_to(wp) < b.position.distance_squared_to(wp))
		var n: int = min(w.n, pool.size())
		var picked := pool.slice(0, n)
		for l in picked:
			var target: Vector2i = s.work if not astar.is_point_solid(s.work) else _open_neighbor(s.work)
			if target.x < 0:
				break
			var p := path_to(cell_of(l), target, astar)
			if p.is_empty():
				continue
			l.job = s
			l.role = "build" if s.phase == "build" else "crew"
			l.path = p
			l.timer = 0.0
			s.crew.append(l)
			idle.sol.erase(l); idle.eng.erase(l); idle.civ.erase(l)

func _tick_signs(delta: float) -> void:
	for s in signs.duplicate():
		var d: Dictionary = SIGNS[s.type]
		# bugs trample zones
		if s.hp <= 0 and s.type != "nogo" and s.type != "excavate" and s.type != "patrol" and s.type != "base":
			toast("%s destroyed! Sign returned." % d.name)
			puff(Vector2(s.rect.get_center() * T), Color(1, 0.4, 0.2), 24, 20.0)
			remove_sign(s, true)
			continue
		var present := []
		for l in s.crew:
			if is_instance_valid(l) and l.path.is_empty():
				present.append(l)
		if not s.get("enabled", true):
			continue
		if s.phase == "staffing":
			var boss = _free_ranked("sergeant" if s.type == "training" else "master")
			if boss != null:
				schools_ever[s.type] = true
				_seat_boss(s, boss)
				toast("%s takes over the %s." % ["A sergeant" if s.type == "training" else "A master engineer", SIGNS[s.type].name.to_lower()])
			continue
		if s.phase == "build":
			for l in present:
				if l.pose != "hammer":
					l.set_pose("hammer", 6.0)
					l.face = 1 if l.position.x < s.rect.get_center().x * T else -1
			if present.size() >= d.build.n:
				s.progress += delta / d.build.time
				if fmod(s.progress * 20.0, 1.0) < delta * 20.0 / d.build.time:
					var hp: Vector2 = present[rng.randi() % present.size()].position + Vector2(rng.randf_range(-6, 6), -10)
					puff(hp, Color(0.9, 0.85, 0.6), 3, 4.0)
				if s.has("site") and is_instance_valid(s.site):
					s.site.modulate = Color(1, 1, 1, 0.8 + 0.2 * s.progress)
					if s.type == "mg":
						s.site.texture = tex("prop_bags_%d" % min(2, int(s.progress * 3)))
				if s.progress >= 1.0:
					_activate(s)
			continue
		if s.type == "workshop" and present.size() >= d.crew.n and not s.get("unlocked", false):
			s["unlocked"] = true
			for k in ["seismic", "pump"]:
				unlocked[k] = true
			gain("eng", 2, "Workshop running")
			toast("Workshop running: SEISMIC and GAS PUMP unlocked.")
		match s.type:
			"excavate":
				_tick_dig(s, delta, present, BAL.dig_time)
				s.work = _dig_stand(s)
				if s.dig_cells.is_empty():
					toast("Excavation finished. Sign returned.")
					remove_sign(s, true)
			"shaft":
				if not s.dig_cells.is_empty():
					_tick_dig(s, delta, present, BAL.dig_time * BAL.eng_dig_mult)
					if s.dig_cells.is_empty():
						toast("Borehole done. Fire in the hole!")
				else:
					s.bomb_t -= delta
					if s.bomb_t <= 0.0 and present.size() > 0:
						s.bomb_t = BAL.bomb_period
						_firebomb(s, present[0])
						s.bombs -= 1
						if s.bombs <= 0:
							toast("Strike complete. Engineers return, sign back in hand.")
							remove_sign(s, true)
							continue
					for l in present:
						_lem_shoot(l, delta, BAL.sol_range * 0.8, BAL.sol_fire * 1.6)
			"training", "engschool", "idiot":
				var inside := []
				for l in s.crew:
					if is_instance_valid(l) and (l.path.is_empty() or s.rect.has_point(cell_of(l))):
						inside.append(l)
				present = inside
				_choreograph(s, delta, present)
				var need: int = d.crew.n
				if s.type in ["training", "engschool"]:
					need = max(1, min(d.crew.n, BAL.school_cap - _roster_alive(s)))
				if present.size() >= need:
					s.cycle += delta * (1.0 - 0.5 * gas_at(s.work.x, s.work.y))
					if s.cycle >= BAL.convert_time:
						s.cycle = 0.0
						var make_boss: bool = s.type in ["training", "engschool"] and _roster_alive(s) >= BAL.school_cap and not s.get("boss_done", false)
						for l in present:
							if l.has_meta("school"):
								var old = l.get_meta("school")
								if old is Dictionary and old.has("roster"):
									old.roster.erase(l)
								l.remove_meta("school")
							l.rank = ""
							l.set_kind(d.out, self)
							_release(l)
							if s.type in ["training", "engschool"]:
								s.roster.append(l)
								l.set_meta("school", s)
							if make_boss:
								l.rank = "sergeant" if s.type == "training" else "master"
								l.hat.texture = tex("hat_sergeant" if l.rank == "sergeant" else "hat_master")
								l.hat.visible = true
								s.boss_done = true
								make_boss = false
								toast("A new %s graduates. Plant another %s and he will run it." % ["sergeant" if l.rank == "sergeant" else "master engineer", SIGNS[s.type].name.to_lower()])
							l.set_pose("cheer", 6.0)
							l.wander_t = 1.5
							puff(l.position + Vector2(0, -8), Color(1, 0.9, 0.4), 8, 6.0)
						if present.size() >= 3:
							toast("Three new %s!" % {"sol": "soldiers", "eng": "engineers", "civ": "civilians"}[d.out])
			"patrol":
				for l in present:
					l.wander_t -= delta
					if l.wander_t <= 0.0:
						l.wander_t = 1.0 + rng.randf() * 2.5
						var tc := _floor_in(s.rect)
						if tc.x >= 0:
							l.path = path_to(cell_of(l), tc, astar)
				for l in s.crew:
					if is_instance_valid(l):
						_lem_shoot(l, delta, BAL.sol_range, BAL.sol_fire)
			"mg":
				for l in present:
					if l.pose != "crouch":
						l.set_pose("crouch", 1.0)
					_lem_shoot(l, delta, BAL.mg_range, BAL.mg_fire)
			"flag":
				if present.size() >= d.crew.n and not s.get("planted", false):
					s.progress += delta / 6.0
					if s.progress >= 1.0:
						s["planted"] = true
						flags += 1
						gain("move", 1, "Flag planted")
						for l in present:
							l.visible = false
						_add_prop(s, "iwo_jima", Vector2(s.spot.x * T + 8, s.spot.y * T + 2))
						_add_prop(s, "prop_flag", Vector2(s.spot.x * T + 8, s.spot.y * T - 8))
						toast("FLAG PLANTED! More lemmings will come. +1 movement sign.")
						_refresh_slots()
			"seismic", "pump", "workshop":
				for l in present:
					if l.pose != "wrench":
						l.set_pose("wrench", 3.0)
				if s.type == "seismic":
					if present.size() >= d.crew.n:
						reveal(s.work, BAL.seismic_radius)
						s["sees"] = true
					else:
						s["sees"] = false
			"institute":
				s.timer += delta
				if s.timer >= 120.0:
					s.timer = 0.0
					gain_point("Institute research")

func _choreograph(s: Dictionary, delta: float, present: Array) -> void:
	var r: Rect2i = s.rect
	var fy := r.end.y - 1
	# operator: on the podium, barking now and then
	var op = s.get("operator")
	if op != null and is_instance_valid(op) and op.path.is_empty():
		op.timer -= delta
		if op.timer <= 0.0:
			op.timer = 2.0 + rng.randf() * 3.0
			if s.type == "training":
				puff(op.position + Vector2(6, -14), Color(1, 1, 1), 2, 3.0)
	var i := 0
	for l in present:
		i += 1
		match s.type:
			"training":
				# run podium -> straw target, stab, run back
				if l.pose == "" or not l.has_meta("spot"):
					l.set_meta("spot", i)
					l.set_pose("stab", 5.0)
					l.timer = 0.0
				l.timer -= delta
				if l.timer <= 0.0 and l.path.is_empty():
					var at_target: bool = l.get_meta("at", false)
					var tx: int = r.position.x + 1 + (i - 1) * 2 if not at_target else r.position.x + 1
					var tc := Vector2i(clamp(tx, r.position.x, r.end.x - 1), fy)
					if not astar.is_point_solid(tc):
						l.path = path_to(cell_of(l), tc, astar)
					l.set_meta("at", not at_target)
					l.timer = 1.2 + rng.randf() * 0.8
					if at_target:
						l.face = 1
			"engschool":
				if l.pose != "wrench":
					l.set_pose("wrench", 3.0)
					var tc := Vector2i(clamp(r.position.x + 1 + i, r.position.x, r.end.x - 1), fy)
					if not astar.is_point_solid(tc):
						l.path = path_to(cell_of(l), tc, astar)
					l.face = 1
				l.timer -= delta
				if l.timer <= 0.0:
					l.timer = 0.6 + rng.randf() * 1.5
					_spark(l.position + Vector2(8, -6))
			"idiot":
				if l.pose != "sit":
					l.set_pose("sit", 1.5)
					var tc := Vector2i(clamp(r.position.x + i, r.position.x, r.end.x - 1), fy)
					if not astar.is_point_solid(tc):
						l.path = path_to(cell_of(l), tc, astar)
					l.face = 1
	if s.type == "idiot" and not s.props.is_empty() and is_instance_valid(s.props[0]):
		s.props[0].modulate = Color(1, 1, 1).lerp(Color(0.7, 0.9, 1.2), 0.5 + 0.5 * sin(game_time * 9.0))

func _spark(p: Vector2) -> void:
	if autotest:
		return
	var f := Sprite2D.new()
	f.texture = tex("fx_spark")
	f.position = p
	fx_layer.add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "position", p + Vector2(rng.randf_range(-6, 6), -8), 0.25)
	tw.parallel().tween_property(f, "modulate:a", 0.0, 0.25)
	tw.tween_callback(f.queue_free)

# ---- token ledger: every sign you own has a reason ----
var ledger := {"move": [], "civic": [], "eng": [], "mil": [], "points": []}
func gain(cat: String, n: int, why: String) -> void:
	hand[cat] = hand.get(cat, 0) + n
	ledger[cat].append([why, n])
	toast("+%d %s sign: %s" % [n, CATS[cat].name, why])
	_float_gain("+%d %s" % [n, CATS[cat].name], cat)
	_refresh_slots()

func gain_point(why: String) -> void:
	points += 1
	ledger.points.append([why, 1])
	toast("+1 sign point: %s" % why)
	_float_gain("+1 POINT", "")
	_refresh_slots()

func _float_gain(text: String, cat: String) -> void:
	if autotest or ui == null:
		return
	var l := _label(ui, Vector2(0, 0), 10)
	l.text = text
	l.modulate = Color(1, 0.95, 0.5)
	if cat != "" and slot_nodes.has(cat):
		l.position = slot_nodes[cat].global_position + Vector2(40, -14)
	else:
		l.position = Vector2(300, 22)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y - 26.0, 1.4)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 1.4)
	tw.tween_callback(l.queue_free)

func ledger_text(cat: String) -> String:
	var parts := []
	for e in ledger[cat]:
		parts.append("%s %+d" % [e[0], e[1]])
	return ", ".join(parts)

func set_enabled(s: Dictionary, on: bool) -> void:
	s.enabled = on
	for l in s.crew.duplicate():
		_release(l)
	var op = s.get("operator")
	if op != null and is_instance_valid(op):
		op.set_pose("boss" if on else "", 1.5)
	for p in s.props:
		if is_instance_valid(p):
			p.modulate = Color(1, 1, 1) if on else Color(0.5, 0.5, 0.5)
	if is_instance_valid(s.board):
		s.board.modulate = Color(1, 1, 1) if on else Color(0.55, 0.55, 0.55)
	toast("%s %s." % [SIGNS[s.type].name, "resumed" if on else "paused"])

func _tick_dig(s: Dictionary, delta: float, present: Array, base_time: float) -> void:
	for l in s.crew:
		if not is_instance_valid(l):
			continue
		if l.role == "dig":
			var c: Vector2i = l.get_meta("dig")
			if not l.path.is_empty():
				continue
			if l.pose != "dig":
				l.set_pose("dig", 6.0)
				l.face = 1 if c.x >= cell_of(l).x else -1
			l.timer -= delta
			if l.timer <= 0.0:
				var wall := cell(c.x, c.y)
				if is_diggable(c.x, c.y):
					set_cell(c, BORE if s.type == "shaft" else DUG)
					puff(cell_pos(c) - Vector2(0, 8), Color(0.45, 0.3, 0.2), 8, 8.0)
					_play("dig")
					if s.type == "excavate" and c in s.get("shaft", []):
						var lad := Sprite2D.new()
						lad.texture = tex("prop_ladder")
						lad.position = Vector2(c.x * T + 8, c.y * T + 8)
						prop_layer.add_child(lad)
				s.dig_cells.erase(c)
				l.role = "crew"
				l.set_pose("")
			continue
		# idle crew member at/near the sign: find next diggable cell adjacent to open ground
		if not l.path.is_empty():
			continue
		var best := Vector2i(-1, -1)
		var best_d := 1e9
		var lc := cell_of(l)
		for c in s.dig_cells:
			if l.get_meta("dig", Vector2i(-9, -9)) == c:
				continue
			var taken := false
			for o in s.crew:
				if o != l and is_instance_valid(o) and o.role == "dig" and o.get_meta("dig", Vector2i(-9, -9)) == c:
					taken = true
			if taken:
				continue
			var n := _open_neighbor(c)
			if n.x < 0 and s.type != "shaft":
				continue
			var dd: float = Vector2(c - lc).length() + c.y * 0.01   # nearest first
			if s.type == "excavate" and c in s.get("shaft", []):
				dd = -1000.0 + c.y
			if s.type == "shaft":
				dd = c.y * 10.0 + abs(c.x - s.work.x)                   # shafts dig top-down
			if dd < best_d:
				best_d = dd
				best = c
		if best.x < 0:
			if not s.dig_cells.is_empty():
				continue
			continue
		var stand := Vector2i(-1, -1)
		var p := []
		if s.type == "shaft":
			stand = s.work
			p = path_to(lc, stand, astar) if lc != stand else []
			if lc != stand and p.is_empty():
				continue
		for off in ([] if s.type == "shaft" else [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]):
			var n: Vector2i = best + off
			if n.x < 0 or n.x >= TW or n.y < 0 or n.y >= TH or astar.is_point_solid(n):
				continue
			if n == lc:
				stand = n
				p = []
				break
			var pp := path_to(lc, n, astar)
			if not pp.is_empty():
				stand = n
				p = pp
				break
		if stand.x < 0:
			continue
		l.path = p
		l.role = "dig"
		l.set_meta("dig", best)
		l.timer = base_time * (BAL.rock_mult if cell(best.x, best.y) == ROCK else 1.0)
	# prune dig cells that got dug by someone else (bugs, other signs)
	for c in s.dig_cells.duplicate():
		if not is_diggable(c.x, c.y):
			s.dig_cells.erase(c)

# ---------------- LEMMINGS ----------------
func _tick_lems(delta: float) -> void:
	for l in lems.duplicate():
		if not is_instance_valid(l) or l.carried:
			continue
		var moving := _move_along(l, delta, l.speed * (1.0 - 0.25 * gas_at(cell_of(l).x, cell_of(l).y)))
		l.anim(delta, moving)
		if l.job == null and l.kind == "sol":
			var threat = _nearest_bug(l.position, 11 * T)
			if threat != null:
				if l.position.distance_to(threat.position) <= BAL.sol_range * T:
					l.path = []
					_lem_shoot(l, delta, BAL.sol_range, BAL.sol_fire)
				else:
					l.wander_t -= delta
					if l.wander_t <= 0.0:
						l.wander_t = 0.8
						var p := path_to(cell_of(l), cell_of(threat), astar)
						if p.size() > 6:
							p = p.slice(0, 6)
						l.path = p
				continue
		if l.job == null:
			# idle: wander in the nearest base area, or where you stand
			l.wander_t -= delta
			if l.pose == "cheer" and l.wander_t <= 0.0:
				l.set_pose("")
			if l.wander_t <= 0.0 and l.path.is_empty():
				l.wander_t = 1.5 + rng.randf() * 3.0
				var tc := _floor_in(_home_rect(l))
				if tc.x >= 0:
					var p := path_to(cell_of(l), tc, astar)
					if p.size() < 40:
						l.path = p
		elif l.role == "operator" or l.role == "crew" or l.role == "build":
			if l.path.is_empty() and l.job.type != "patrol" and l.job.type != "excavate" and l.job.type != "shaft":
				l.face = 1 if (int(l.position.x / T) % 2 == 0) else -1
		if l.kind == "civ" and l.scream_t <= 0.0:
			for b in bugs:
				if b.position.distance_squared_to(l.position) < (4 * T) * (4 * T):
					l.scream_t = 1.2
					l.spr.texture = tex("lem_civ_scream")
					break

func is_floor(c: Vector2i) -> bool:
	return is_open(c.x, c.y) and not astar.is_point_solid(c) and not is_open(c.x, c.y + 1)

func _floor_in(r: Rect2i) -> Vector2i:
	for attempt in 8:
		var c := Vector2i(r.position.x + rng.randi_range(0, r.size.x - 1), r.position.y + rng.randi_range(0, r.size.y - 1))
		if is_floor(c):
			return c
	return Vector2i(-1, -1)

func _home_rect(l: Lem) -> Rect2i:
	var best: Rect2i = Rect2i(22, SURF_Y, 20, 3)
	var bd := 1e18
	for s in signs:
		if s.type == "base":
			var d := l.position.distance_squared_to(Vector2(s.rect.get_center() * T))
			if d < bd:
				bd = d
				best = s.rect
	return best

func _lem_shoot(l: Lem, delta: float, rng_cells: float, fire: float) -> void:
	if not is_instance_valid(l):
		return
	var g := gas_at(cell_of(l).x, cell_of(l).y)
	l.timer -= delta
	if l.timer > 0.0:
		return
	var r2 := (rng_cells * T) * (rng_cells * T)
	var best = null
	var bd := r2
	for b in bugs:
		var d: float = b.position.distance_squared_to(l.position)
		if d < bd:
			bd = d
			best = b
	var qd: float = queen.pos.distance_squared_to(l.position)
	if best == null and qd < r2:
		l.timer = fire / (1.0 - BAL.gas_fire_penalty * g)
		_tracer(l.position + Vector2(0, -8), queen.pos - Vector2(0, 16))
		_hit_queen(1)
		return
	if best == null:
		return
	l.timer = fire / (1.0 - BAL.gas_fire_penalty * g)
	l.face = 1 if best.position.x > l.position.x else -1
	_tracer(l.position + Vector2(0, -8), best.position - Vector2(0, 6))
	_play("gun")
	_hit_bug(best, 1)

func _tracer(a: Vector2, b: Vector2) -> void:
	if autotest:
		return
	var s := Sprite2D.new()
	s.texture = tex("fx_tracer")
	s.position = a
	s.rotation = (b - a).angle()
	fx_layer.add_child(s)
	var tw := create_tween()
	tw.tween_property(s, "position", b, 0.12)
	tw.tween_callback(s.queue_free)

func _firebomb(s: Dictionary, l: Lem) -> void:
	# target: most infested / buggy cell within reach below the bottom of the bore
	var c: Vector2i = Vector2i(s.rect.position.x, s.rect.end.y - 1)
	var best: Vector2i = c + Vector2i(0, 2)
	var bs := -1.0
	for dy in range(0, 9):
		for dx in range(-6, 7):
			var n: Vector2i = c + Vector2i(dx, dy)
			if n.x < 0 or n.x >= TW or n.y >= TH:
				continue
			var score := infest[idx(n.x, n.y)]
			for b in bugs:
				if cell_of(b).distance_to(n) < 2.5:
					score += 1.0
			if score > bs:
				bs = score
				best = n
	if bs <= 0.0:
		return
	var p := cell_pos(best)
	_tracer(l.position + Vector2(0, -8), p)
	var f := Sprite2D.new()
	f.texture = tex("fx_fire")
	f.position = p - Vector2(0, 8)
	fx_layer.add_child(f)
	var tw := create_tween()
	tw.tween_property(f, "scale", Vector2(2.2, 2.2), 0.35)
	tw.parallel().tween_property(f, "modulate:a", 0.0, 0.35)
	tw.tween_callback(f.queue_free)
	shake(2.0)
	_play("meteor")
	for b in bugs.duplicate():
		if b.position.distance_to(p) < BAL.bomb_radius * T:
			_hit_bug(b, BAL.bomb_dmg)
	if queen.pos.distance_to(p) < BAL.bomb_radius * T * 1.5:
		_hit_queen(BAL.bomb_dmg)
	for n in nests:
		if Vector2(n.cell).distance_to(Vector2(best)) < BAL.bomb_radius * 1.5:
			n.r = max(1.0, n.r - 2.5)
	_recompute_infest()
	_update_overlays()

# ---------------- BUGS ----------------
func _tick_bugs(delta: float) -> void:
	# nests breed
	var minutes := game_time / 60.0
	var cap := int(BAL.bug_cap_base + minutes * BAL.bug_cap_per_min)
	var period: float = max(BAL.nest_spawn_min, BAL.nest_spawn_start - game_time / BAL.nest_spawn_ramp)
	var group := 1 + int(minutes / BAL.raid_group_minutes)
	for n in nests:
		n.t -= delta
		if n.t <= 0.0:
			n.t = period * (0.7 + rng.randf() * 0.6)
			for gi in group:
				if bugs.size() < cap:
					_spawn_bug(n.cell)
	# the infestation spreads: a new nest sprouts inside the infested zone now and then
	nest_clock += delta
	if nest_clock >= BAL.nest_spread_period * pow(0.93, nests.size() - 6) and nests.size() < BAL.nest_max:
		nest_clock = 0.0
		_sprout_nest()
	# raiders
	for b in bugs.duplicate():
		if not is_instance_valid(b):
			continue
		var bc := cell_of(b)
		var g := gas_at(bc.x, bc.y)
		var spd: float = BAL.bug_speed * (1.0 + BAL.gas_bug_bonus * g)
		b.anim_t += delta * 10.0
		b.spr.texture = b.frames[int(b.anim_t) % 2]
		if b.flash_t > 0.0:
			b.flash_t -= delta
			if b.flash_t <= 0.0:
				b.spr.modulate = Color(1, 1, 1)
		if b.state == "hunt":
			b.retarget_t -= delta
			if (b.target == null or not is_instance_valid(b.target) or b.target.carried) or b.retarget_t <= 0.0:
				b.retarget_t = 3.0 + rng.randf() * 2.0
				b.target = _prey(b.position)
				b.path = []
				if b.target != null:
					b.path = path_to(bc, cell_of(b.target), bstar)
					if b.path.size() > 1:
						b.path.pop_front()
					if b.path.size() > 14:
						b.path = b.path.slice(0, 14)   # re-plan as the prey moves
						b.retarget_t = 8.0
				if b.path.is_empty() and b.target == null:
					# prowl toward the surface base slowly
					var tc := Vector2i(bc.x + rng.randi_range(-6, 6), max(SURF_Y + 1, bc.y - rng.randi_range(0, 6)))
					tc.x = clamp(tc.x, 1, TW - 2)
					b.path = path_to(bc, tc, bstar)
			if b.target != null and is_instance_valid(b.target) and not b.target.carried:
				if b.position.distance_to(b.target.position) < 7.0:
					b.grab_t += delta
					var need: float = 0.05 if b.target.kind == "civ" else (BAL.grab_time_sol if b.target.kind == "sol" else BAL.grab_time_eng)
					if b.grab_t >= need:
						_grab(b, b.target)
					continue
			_bug_move(b, delta, spd)
		elif b.state == "carry":
			if b.path.is_empty():
				b.path = path_to(bc, queen.cell, bstar)
				if b.path.is_empty():
					b.path = path_to(bc, b.home, bstar)
			if b.carrying != null and is_instance_valid(b.carrying):
				b.carrying.position = b.position + Vector2(0, -10)
			_bug_move(b, delta, spd * 0.85)
			if bc.distance_to(queen.cell) < 2.5 or b.path.is_empty() and bc.distance_to(queen.cell) < 4:
				_feed(b)
		# trample zones
		for s in signs:
			if s.rect.has_point(bc) and s.type != "nogo" and s.type != "excavate":
				s.hp -= delta * BAL.bug_zone_dmg
	_tick_queen(delta)

var nest_clock := 0.0
func _sprout_nest() -> void:
	# pick the highest infested cell that is still dirt and in gas: the hive climbs toward you
	var best := Vector2i(-1, -1)
	var bs := -1.0
	for attempt in 60:
		var x := rng.randi_range(2, TW - 3)
		var y := rng.randi_range(SURF_Y + 6, TH - 3)
		var inf := infest[idx(x, y)]
		if inf < 0.2 or gas_at(x, y) < 0.25 or is_open(x, y):
			continue
		var near := false
		for n in nests:
			if Vector2(n.cell).distance_to(Vector2(x, y)) < 5.0:
				near = true
		if near:
			continue
		var score := inf * 0.5 + (TH - y) / float(TH)
		if score > bs:
			bs = score
			best = Vector2i(x, y)
	if best.x < 0:
		return
	_blob(best, 3)
	for dy in range(-3, 4):
		for dx in range(-4, 5):
			var c := best + Vector2i(dx, dy)
			if c.x > 0 and c.x < TW - 1 and c.y > SURF_Y and c.y < TH - 1:
				_sync_cell(c)
	_repaint_around(best)
	var sp := Sprite2D.new()
	sp.texture = tex("bug_nest")
	sp.position = Vector2(best.x * T + T / 2.0, best.y * T + T - 10)
	prop_layer.add_child(sp)
	nests.append({"cell": best, "r": 2.0, "t": 10.0, "node": sp})
	_refresh_dig_cells_all()
	shake(2.0)
	toast("The walls shudder. The hive is spreading.")

func _bug_move(b: Bug, delta: float, spd: float) -> void:
	if b.path.is_empty():
		return
	var next: Vector2 = b.path[0]
	var nc := Vector2i(int(next.x / T), int((next.y - 1.0) / T))
	if not is_open(nc.x, nc.y):
		# dig through
		b.dig_t += delta
		var need := 1.4 if cell(nc.x, nc.y) == DIRT else 3.0
		if b.dig_t >= need:
			b.dig_t = 0.0
			set_cell(nc, BUGDUG)
			puff(cell_pos(nc) - Vector2(0, 8), Color(0.5, 0.15, 0.3), 6, 8.0)
			_refresh_dig_cells_all()
		return
	_move_along(b, delta, spd)
	b.spr.flip_h = (next.x - b.position.x) < 0

func _refresh_dig_cells_all() -> void:
	for s in signs:
		if s.type == "excavate":
			_refresh_dig_cells(s)

func _prey(pos: Vector2):
	# bugs go for the easy meat: civilians first, then engineers, soldiers last
	var best = null
	var bs := 1e18
	for l in lems:
		if not is_instance_valid(l) or l.carried or not l.visible:
			continue
		var w := 1.0 if l.kind == "civ" else (1.6 if l.kind == "eng" else 2.4)
		var d: float = l.position.distance_to(pos) * w
		if d < bs:
			bs = d
			best = l
	return best

func _nearest_bug(pos: Vector2, max_d: float):
	var best = null
	var bd := max_d * max_d
	for b in bugs:
		if not b.visible:
			continue
		var d: float = b.position.distance_squared_to(pos)
		if d < bd:
			bd = d
			best = b
	return best

func _nearest_lem(pos: Vector2, max_d: float):
	var best = null
	var bd := max_d * max_d
	for l in lems:
		if not is_instance_valid(l) or l.carried or not l.visible:
			continue
		var d: float = l.position.distance_squared_to(pos)
		if d < bd:
			bd = d
			best = l
	return best

func _grab(b: Bug, l: Lem) -> void:
	b.state = "carry"
	b.carrying = l
	b.target = null
	b.path = []
	b.grab_t = 0.0
	l.carried = true
	l.scream_t = 99.0
	if l.kind == "civ":
		l.spr.texture = tex("lem_civ_scream")
	_release(l)
	l.carried = true
	_play("squeak")
	toast("A lemming has been taken!")

func _feed(b: Bug) -> void:
	if b.carrying != null and is_instance_valid(b.carrying):
		lems.erase(b.carrying)
		b.carrying.queue_free()
		queen.fed += 1
		kidnapped += 1
		puff(queen.pos - Vector2(0, 20), Color(0.8, 0.2, 0.3), 14, 14.0)
		_play("roar")
		if queen.fed >= BAL.queen_meal and not queen.mega:
			_go_mega()
	b.carrying = null
	b.state = "hunt"
	b.path = []
	b.retarget_t = 0.0

func _hit_bug(b: Bug, dmg: int) -> void:
	b.hp -= dmg
	b.spr.modulate = Color(2, 1.5, 1.5)
	b.flash_t = 0.08
	if b.hp <= 0:
		if b.carrying != null and is_instance_valid(b.carrying):
			var l: Lem = b.carrying
			l.carried = false
			l.scream_t = 0.0
			l.position = b.position
			l.spr.texture = l.frames[0]
			toast("Lemming rescued!")
		puff(b.position, Color(0.6, 0.15, 0.25), 12, 10.0)
		bugs_killed += 1
		bugs.erase(b)
		b.queue_free()
		_play("pop")

func _hit_queen(dmg: int) -> void:
	queen.hp -= dmg
	queen.node.modulate = Color(2, 1.4, 1.4)
	queen["flash_t"] = 0.1
	if queen.hp <= 0 and not game_over:
		_end(true)

func _go_mega() -> void:
	queen.mega = true
	queen.hp += 60
	queen.node.texture = tex("bug_megaqueen")
	shake(8.0)
	_play("roar")
	toast("THE QUEEN HAS FED. SHE IS COMING UP.")

func _tick_queen(delta: float) -> void:
	if queen.get("flash_t", 0.0) > 0.0:
		queen.flash_t -= delta
		if queen.flash_t <= 0.0:
			queen.node.modulate = Color(1, 1, 1)
	if not queen.mega:
		return
	queen.spawn_t -= delta
	if queen.spawn_t <= 0.0:
		queen.spawn_t = 6.0
		_spawn_bug(queen.cell)
	if queen.path.is_empty():
		queen.path = path_to(queen.cell, Vector2i(base_cell.x, SURF_Y + 2), bstar)
		if queen.path.size() > 1:
			queen.path.pop_front()
	if queen.path.is_empty():
		return
	var next: Vector2 = queen.path[0]
	var nc := Vector2i(int(next.x / T), int((next.y - 1.0) / T))
	# she digs a 3-wide chimney
	var blocked := false
	for dx in range(-1, 2):
		var c := Vector2i(nc.x + dx, nc.y)
		if c.x > 0 and c.x < TW - 1 and not is_open(c.x, c.y) and cell(c.x, c.y) != SKY:
			blocked = true
			queen.dig_t += delta
			if queen.dig_t >= 0.5:
				queen.dig_t = 0.0
				set_cell(c, BUGDUG)
				puff(cell_pos(c), Color(0.5, 0.15, 0.3), 8, 10.0)
				shake(1.5)
			break
	if blocked:
		return
	var d: Vector2 = next - queen.pos
	var step := 14.0 * delta
	if d.length() <= step:
		queen.pos = next
		queen.path.pop_front()
	else:
		queen.pos += d.normalized() * step
	queen.cell = Vector2i(int(queen.pos.x / T), int((queen.pos.y - 1.0) / T))
	queen.node.position = queen.pos - Vector2(0, 24)
	reveal(queen.cell, 4.0)
	if queen.cell.y <= SURF_Y + 3 and not game_over:
		_end(false)

func _recompute_infest() -> void:
	infest.fill(0.0)
	for n in nests:
		var r: float = n.r
		var ri := int(ceil(r))
		for dy in range(-ri, ri + 1):
			for dx in range(-ri, ri + 1):
				var x: int = n.cell.x + dx
				var y: int = n.cell.y + dy
				if x < 0 or x >= TW or y < 0 or y >= TH:
					continue
				var d := Vector2(dx * 0.8, dy).length()
				if d <= r:
					var v: float = (1.0 - d / r) * clamp(gas_at(x, y) * 2.0, 0.15, 1.0)
					infest[idx(x, y)] = max(infest[idx(x, y)], v)

func _tick_infest(delta: float) -> void:
	for n in nests:
		var g := gas_at(n.cell.x, n.cell.y)
		n.r = min(BAL.infest_max_r, n.r + BAL.infest_grow * delta * (0.3 + g))
	_recompute_infest()

# ---------------- ECONOMY ----------------
func _tick_economy(delta: float) -> void:
	sign_clock += delta
	if sign_clock >= BAL.sign_tick:
		sign_clock = 0.0
		gain_point("Time (every %ds)" % int(BAL.sign_tick))
	income_clock += delta
	var period: float = BAL.income_base / (1.0 + flags * BAL.income_flag_bonus)
	if income_clock >= period:
		income_clock = 0.0
		var l := _spawn_lem("civ", Vector2((22 + rng.randf() * 20) * T, (SURF_Y - 1) * T + T))
		puff(l.position, Color(0.9, 0.9, 1.0), 6, 6.0)

func count(kind: String) -> int:
	var n := 0
	for l in lems:
		if is_instance_valid(l) and l.kind == kind and not l.carried:
			n += 1
	return n

func count_rank(r: String) -> int:
	var n := 0
	for l in lems:
		if is_instance_valid(l) and l.rank == r and not l.carried:
			n += 1
	return n

func buy(cat: String) -> void:
	if points < 1:
		toast("Not enough sign points.")
		return
	points -= 1
	hand[cat] = hand.get(cat, 0) + 1
	toast("+1 %s sign." % CATS[cat].name)
	_play("blip")
	_refresh_slots()

# ---------------- MAIN LOOP ----------------
var shots := false
var shot_t := 0.0
var shot_n := 0
var demo_step := 0
func _process(delta: float) -> void:
	if autotest:
		return
	if shots:
		_tick_demo(delta)
	_tick_cam(delta)
	_tick_ghost()
	if paused or game_over:
		return
	step(min(delta, 0.05))
	_tick_hud()
	_tick_card()

func step(delta: float) -> void:
	game_time += delta
	alloc_clock += delta
	if alloc_clock >= 0.5:
		alloc_clock = 0.0
		_tick_alloc()
	_tick_signs(delta)
	_tick_lems(delta)
	_tick_bugs(delta)
	_tick_economy(delta)
	infest_clock += delta
	if infest_clock >= 2.0:
		infest_clock = 0.0
		_tick_infest(2.0)
	fog_clock += delta
	if fog_clock >= 0.6:
		fog_clock = 0.0
		for l in lems:
			if is_instance_valid(l) and not l.carried:
				reveal(cell_of(l), BAL.fog_radius)
		_update_overlays()
		_tick_vis()
	if lems.is_empty() and not game_over:
		_end(false)
	if toast_t > 0.0:
		toast_t -= delta
		if toast_t <= 0.0:
			toast_lbl.visible = false
	if shake_amt > 0.0:
		shake_amt = max(0.0, shake_amt - delta * 12.0)
		cam.offset = Vector2(rng.randf_range(-shake_amt, shake_amt), rng.randf_range(-shake_amt, shake_amt))

func _tick_demo(delta: float) -> void:
	shot_t += delta
	var plan := [[1.0, "excavate", Vector2i(29, SURF_Y + 3)], [1.5, "training", Vector2i(23, SURF_Y + 1)], [2.0, "engschool", Vector2i(34, SURF_Y + 1)],
		[16.0, "excavate", Vector2i(29, SURF_Y + 8)], [18.0, "patrol", Vector2i(26, SURF_Y + 5)], [30.0, "excavate", Vector2i(23, SURF_Y + 8)],
		[48.0, "shaft", Vector2i(30, SURF_Y + 12)], [52.0, "workshop", Vector2i(24, SURF_Y + 11)]]
	if demo_step < plan.size() and shot_t >= plan[demo_step][0]:
		_place_sign(plan[demo_step][1], plan[demo_step][2])
		demo_step += 1
	if shot_t > 30.0 and shot_t < 50.0:
		cam.position = cam.position.lerp(Vector2(31 * T, (SURF_Y + 9) * T), delta * 0.5)
	if shot_n < 6 and shot_t >= 8.0 + shot_n * 9.0:
		if shot_n == 0:
			_open_radial("civic", Vector2(330, 190))
		else:
			_close_radial()
		if shot_n == 2 and signs.size() > 1:
			_open_card(signs[2])
		if shot_n == 3:
			_close_card()
		await RenderingServer.frame_post_draw
		var im := get_viewport().get_texture().get_image()
		DirAccess.make_dir_recursive_absolute("user://shots")
		im.save_png("user://shots/signs_%02d.png" % shot_n)
		print("shot ", shot_n, " t=", int(shot_t), " ", OS.get_user_data_dir())
		shot_n += 1
		if shot_n >= 6:
			get_tree().quit()

func _tick_vis() -> void:
	# bugs are only drawn where you can see (or a seismic post hears them)
	for b in bugs:
		var c := cell_of(b)
		var seen := not is_hidden(c)
		if not seen:
			for s in signs:
				if s.type == "seismic" and s.get("sees", false) and Vector2(s.work).distance_to(Vector2(c)) < BAL.seismic_radius:
					seen = true
		b.visible = seen
	queen.node.visible = not is_hidden(queen.cell) or queen.mega

# ---------------- CAMERA / INPUT ----------------
var shake_amt := 0.0
func shake(a: float) -> void:
	shake_amt = max(shake_amt, a)

func _tick_cam(delta: float) -> void:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): v.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): v.x += 1
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): v.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): v.y += 1
	cam.position += v * 260.0 * delta / cam.zoom.x

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			_zoom(1)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			_zoom(-1)
		elif ev.button_index == MOUSE_BUTTON_RIGHT:
			if ev.pressed:
				drag = true
				drag_moved = false
			else:
				drag = false
				if not drag_moved:
					if sel != "":
						_select("")
					else:
						_pickup_at_mouse()
		elif ev.button_index == MOUSE_BUTTON_LEFT and ev.pressed and not game_over:
			if radial.visible:
				_close_radial()
			elif sel == "":
				var hit := _sign_at_mouse()
				if hit.is_empty():
					_close_card()
				else:
					_open_card(hit)
			elif sel != "":
				var c := _mouse_cell() - Vector2i(SIGNS[sel].w / 2, SIGNS[sel].h - 1)
				if sel == "excavate" or sel == "shaft":
					c = _mouse_cell() - Vector2i(SIGNS[sel].w / 2, 0)
				var s := _place_sign(sel, c)
				if not s.is_empty():
					_play("blip")
					if hand.get(cat_of(sel), 0) <= 0:
						_select("")
	elif ev is InputEventMouseMotion and drag:
		drag_moved = true
		cam.position -= ev.relative / cam.zoom.x
	elif ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_ESCAPE:
			_close_radial()
			_close_card()
			_select("")
		elif ev.keycode == KEY_P:
			paused = not paused
			toast("PAUSED" if paused else "Go.")
		elif ev.keycode == KEY_F11:
			var w := get_window()
			w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
		elif ev.keycode == KEY_BACKSPACE:
			get_tree().change_scene_to_file("res://scenes/Menu.tscn")
		else:
			var ch := OS.get_keycode_string(ev.keycode).to_upper()
			for c in CATS:
				if CATS[c].key == ch:
					_open_radial(c, get_viewport().get_mouse_position())
			if radial.visible:
				var i := 0
				for k in CATS[radial_cat].signs:
					i += 1
					if ch == "QWER"[i - 1]:
						_close_radial()
						_select(k)
var drag_moved := false

func _zoom(dir: int) -> void:
	var z: float = clamp(cam.zoom.x * (1.15 if dir > 0 else 1.0 / 1.15), 0.9, 3.2)
	cam.zoom = Vector2(z, z)

func _mouse_cell() -> Vector2i:
	var p := get_global_mouse_position()
	return Vector2i(int(floor(p.x / T)), int(floor(p.y / T)))

func _select(k: String) -> void:
	if k != "" and not unlocked.get(k, false):
		toast("%s is locked. Build a workshop first." % SIGNS[k].name)
		return
	if k != "" and hand.get(cat_of(k), 0) <= 0:
		toast("No %s signs in hand. Press + to buy one with a sign point." % CATS[cat_of(k)].name)
		return
	sel = k
	ghost.visible = k != ""
	for key in slot_nodes:
		slot_nodes[key].get_node("Sel").visible = k != "" and key == cat_of(k)
	if k != "":
		tip_lbl.text = "%s: %s" % [SIGNS[k].name, SIGNS[k].desc]

# ---- radial menu: pick the sign inside a category ----
var radial: Control
var radial_cat := ""
func _open_radial(cat: String, at: Vector2) -> void:
	_select("")
	radial_cat = cat
	for ch in radial.get_children():
		ch.queue_free()
	var items: Array = CATS[cat].signs
	var n := items.size()
	var r := 54.0
	var center := Vector2(clamp(at.x, 80, 560), clamp(at.y, 90, 360 - 44 - 80))
	var hub := ColorRect.new()
	hub.color = Color(0.05, 0.04, 0.05, 0.75)
	hub.size = Vector2(2 * r + 70, 2 * r + 60)
	hub.position = center - hub.size / 2
	hub.mouse_filter = Control.MOUSE_FILTER_STOP
	radial.add_child(hub)
	var title := _label(radial, center + Vector2(-60, -8), 8)
	title.size = Vector2(120, 16)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "%s  x%d" % [CATS[cat].name, hand.get(cat, 0)]
	for i in n:
		var k: String = items[i]
		var ang := -PI / 2 + TAU * i / n
		var pos := center + Vector2(cos(ang), sin(ang)) * r
		var item := Button.new()
		item.flat = true
		item.size = Vector2(60, 44)
		item.position = pos - item.size / 2
		var locked: bool = not unlocked.get(k, false)
		var bg := ColorRect.new()
		bg.color = Color(0.2, 0.17, 0.12, 0.95) if not locked else Color(0.12, 0.1, 0.1, 0.9)
		bg.size = item.size
		bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		item.add_child(bg)
		var ic := TextureRect.new()
		ic.texture = tex("icon_%s" % k)
		ic.position = Vector2(22, 3)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ic.modulate = Color(0.4, 0.4, 0.4) if locked else Color(1, 1, 1)
		item.add_child(ic)
		var nm := _label(item, Vector2(0, 22), 6)
		nm.size = Vector2(60, 10)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nm.text = "LOCKED" if locked else SIGNS[k].name
		var kk := _label(item, Vector2(0, 32), 6)
		kk.size = Vector2(60, 10)
		kk.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kk.text = "QWER"[i]
		kk.modulate = Color(0.7, 0.7, 0.6)
		item.pressed.connect(func():
			_close_radial()
			_select(k))
		item.mouse_entered.connect(func(): tip_lbl.text = "%s: %s" % [SIGNS[k].name, SIGNS[k].desc])
		radial.add_child(item)
	radial.visible = true

func _close_radial() -> void:
	radial.visible = false
	radial_cat = ""

func _sign_at_mouse() -> Dictionary:
	var m := get_global_mouse_position()
	var mc := _mouse_cell()
	for s in signs:
		if is_instance_valid(s.board) and s.board.global_position.distance_to(m) < 14.0:
			return s
	for s in signs:
		if s.type != "nogo" and s.rect.has_point(mc):
			return s
	return {}

func _pickup_at_mouse() -> void:
	var s := _sign_at_mouse()
	if not s.is_empty():
		toast("%s sign picked up." % SIGNS[s.type].name)
		remove_sign(s, true)
		_play("blip")

# ---- sign card ----
var card: Control
var card_sign := {}
var card_title: Label
var card_body: Label
func _build_card(root: Control) -> void:
	card = Control.new()
	card.position = Vector2(640 - 206, 24)
	card.size = Vector2(200, 118)
	card.visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.06, 0.92)
	bg.size = card.size
	card.add_child(bg)
	var edge := ColorRect.new()
	edge.color = Color(0.75, 0.6, 0.3, 0.9)
	edge.size = Vector2(card.size.x, 2)
	card.add_child(edge)
	card_title = _label(card, Vector2(8, 6), 10)
	card_body = _label(card, Vector2(8, 22), 7)
	card_body.size = Vector2(184, 60)
	card_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bx := 8
	for spec in [["REMOVE", func(): _card_remove()], ["MOVE", func(): _card_move()], ["PAUSE", func(): _card_toggle()], ["CLOSE", func(): _close_card()]]:
		var b := Button.new()
		b.text = spec[0]
		b.name = spec[0]
		b.position = Vector2(bx, 92)
		b.size = Vector2(44, 18)
		b.add_theme_font_size_override("font_size", 8)
		b.pressed.connect(spec[1])
		card.add_child(b)
		bx += 47
	root.add_child(card)

func _open_card(s: Dictionary) -> void:
	if not card_sign.is_empty() and card_sign in signs and is_instance_valid(card_sign.outline):
		card_sign.outline.color = Color(1, 1, 1, 0.0)
	card_sign = s
	card.visible = true
	if is_instance_valid(s.outline):
		s.outline.color = Color(1, 0.9, 0.5, 0.12)
	_tick_card()

func _close_card() -> void:
	if not card_sign.is_empty() and card_sign in signs and is_instance_valid(card_sign.outline):
		card_sign.outline.color = Color(1, 1, 1, 0.0)
	card_sign = {}
	card.visible = false

func _card_remove() -> void:
	if card_sign.is_empty() or not card_sign in signs:
		_close_card()
		return
	toast("%s sign removed. Token returned to %s." % [SIGNS[card_sign.type].name, CATS[cat_of(card_sign.type)].name])
	remove_sign(card_sign, true)
	_play("blip")
	_close_card()

func _card_toggle() -> void:
	if card_sign.is_empty() or not card_sign in signs:
		_close_card()
		return
	set_enabled(card_sign, not card_sign.get("enabled", true))

func _card_move() -> void:
	if card_sign.is_empty() or not card_sign in signs:
		_close_card()
		return
	var t: String = card_sign.type
	remove_sign(card_sign, true)
	_close_card()
	_select(t)
	toast("Pick a new spot for the %s sign." % SIGNS[t].name)

func _tick_card() -> void:
	if not card.visible:
		return
	if card_sign.is_empty() or not card_sign in signs:
		_close_card()
		return
	var s := card_sign
	var d: Dictionary = SIGNS[s.type]
	card_title.text = "%s  (%s)%s" % [d.name, CATS[cat_of(s.type)].name.capitalize(), "  PAUSED" if not s.get("enabled", true) else ""]
	card.get_node("PAUSE").text = "RESUME" if not s.get("enabled", true) else "PAUSE"
	card.get_node("PAUSE").visible = s.type != "excavate" and s.type != "nogo"
	var present := 0
	for l in s.crew:
		if is_instance_valid(l) and l.path.is_empty():
			present += 1
	var lines := []
	if s.phase == "build":
		lines.append("Building: %d%%.  %d/%d %s on site." % [int(s.progress * 100), present, d.build.n, _plural(d.build.type)])
	else:
		match s.type:
			"excavate":
				lines.append("%d cells left to dig.  %d/%d diggers." % [s.dig_cells.size(), s.crew.size(), d.crew.n])
			"shaft":
				if s.dig_cells.is_empty():
					lines.append("Bombing: %d bombs left, next in %ds.  %d/3 engineers." % [s.get("bombs", 0), int(max(0.0, s.bomb_t)), present])
				else:
					lines.append("Boring: %d cells to go, then %d firebombs.  %d/3 engineers." % [s.dig_cells.size(), s.get("bombs", 0), s.crew.size()])
			"training", "engschool", "idiot":
				var who: String = {"sol": "soldiers", "eng": "engineers", "civ": "civilians"}[d.out]
				if s.phase == "staffing":
					lines.append("Built. Waiting for a free %s to run it." % ("sergeant" if s.type == "training" else "master engineer"))
				elif s.type == "idiot":
					lines.append("Professor on duty.  %d/3 in class, civilians in %ds." % [present, int(BAL.convert_time - s.cycle)])
				else:
					var alive := _roster_alive(s)
					var boss_txt := "Sergeant" if s.type == "training" else "Master engineer"
					if alive >= BAL.school_cap and s.get("boss_done", false):
						lines.append("%s on duty.  FULL: %d/%d %s alive. Trains replacements only." % [boss_txt, alive, BAL.school_cap, who])
					elif alive >= BAL.school_cap:
						lines.append("%s on duty.  %d/%d trained. Last cadet becomes a %s (%ds)." % [boss_txt, alive, BAL.school_cap, boss_txt.to_lower(), int(BAL.convert_time - s.cycle)])
					else:
						lines.append("%s on duty.  %d/%d trained, %d in class, next in %ds." % [boss_txt, alive, BAL.school_cap, present, int(BAL.convert_time - s.cycle)])
			"patrol":
				lines.append("%d/5 soldiers on patrol." % s.crew.size())
			"mg":
				lines.append("%d/2 soldiers manning the gun." % present)
			"flag":
				lines.append("Flag raised. Lemmings trickle in faster." if s.get("planted", false) else "%d/3 civilians raising the flag (%d%%)." % [present, int(s.progress * 100)])
			"workshop":
				lines.append("Running: seismic + gas pump unlocked." if s.get("unlocked", false) else "%d/2 engineers needed to run it." % present)
			"seismic":
				lines.append("Listening to the walls." if s.get("sees", false) else "%d/2 engineers needed." % present)
			"pump":
				lines.append("Pumping gas out, radius %d.  %d/2 engineers." % [int(BAL.pump_radius), present])
			"institute":
				lines.append("Next sign point in %ds." % int(120.0 - s.timer))
			"nogo":
				lines.append("Lemmings keep 3 tiles away from this sign.")
			"base":
				lines.append("Idle lemmings hang out here.")
	if not s.type in ["nogo", "excavate", "patrol", "base"]:
		lines.append("Health %d/%d.  Destroyed = sign returned." % [int(ceil(s.hp)), BAL.zone_hp])
	lines.append(d.desc)
	card_body.text = "\n".join(lines)

func _plural(kind: String) -> String:
	return {"civ": "civilians", "sol": "soldiers", "eng": "engineers", "any": "lemmings"}.get(kind, kind)

func _tick_ghost() -> void:
	if sel == "":
		return
	var c := _mouse_cell() - Vector2i(SIGNS[sel].w / 2, SIGNS[sel].h - 1)
	if sel == "excavate" or sel == "shaft":
		c = _mouse_cell() - Vector2i(SIGNS[sel].w / 2, 0)
	var r := sign_rect(sel, c)
	ghost.position = Vector2(r.position * T)
	ghost_rect.size = Vector2(r.size * T)
	var ok: bool = placement(sel, c).ok
	ghost_rect.color = Color(0.3, 1.0, 0.4, 0.35) if ok else Color(1.0, 0.3, 0.3, 0.35)

# ---------------- UI ----------------
func _build_ui() -> void:
	ghost = Node2D.new()
	ghost_rect = ColorRect.new()
	ghost_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.add_child(ghost_rect)
	ghost.visible = false
	world.add_child(ghost)
	ui = CanvasLayer.new()
	add_child(ui)
	var root := Control.new()
	root.size = Vector2(640, 360)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)
	var top := ColorRect.new()
	top.color = Color(0.05, 0.04, 0.05, 0.85)
	top.size = Vector2(640, 18)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top)
	top_lbl = _label(root, Vector2(6, 2), 9)
	var bar := ColorRect.new()
	bar.color = Color(0.05, 0.04, 0.05, 0.9)
	bar.position = Vector2(0, 360 - 44)
	bar.size = Vector2(640, 44)
	root.add_child(bar)
	tip_lbl = _label(root, Vector2(6, 360 - 58), 8)
	tip_lbl.text = "Press 1-4 (or click a category) to open the sign wheel. Right-click a planted sign to pick it up."
	var tipbg := ColorRect.new()
	tipbg.color = Color(0.05, 0.04, 0.05, 0.7)
	tipbg.position = Vector2(0, 360 - 60)
	tipbg.size = Vector2(640, 16)
	tipbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tipbg)
	root.move_child(tipbg, tip_lbl.get_index())
	var x := 6
	for k in CAT_ORDER:
		var slot := Control.new()
		slot.position = Vector2(x, 2)
		slot.size = Vector2(120, 40)
		slot.name = k
		var selr := ColorRect.new()
		selr.name = "Sel"
		selr.color = Color(1, 0.9, 0.4, 0.3)
		selr.size = Vector2(120, 40)
		selr.visible = false
		selr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(selr)
		var ic := TextureRect.new()
		ic.name = "Icon"
		ic.texture = tex(CATS[k].icon)
		ic.position = Vector2(4, 4)
		ic.scale = Vector2(2, 2)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(ic)
		var cnt := _label(slot, Vector2(42, 2), 14)
		cnt.name = "Count"
		var nm := _label(slot, Vector2(42, 22), 7)
		nm.name = "Name"
		nm.text = "%s  [%s]" % [CATS[k].name, CATS[k].key]
		var sub := _label(slot, Vector2(42, 31), 5)
		sub.name = "Sub"
		var names := []
		for sk in CATS[k].signs:
			names.append(SIGNS[sk].name.capitalize())
		sub.text = ", ".join(names)
		sub.modulate = Color(0.7, 0.7, 0.6)
		var plus := Button.new()
		plus.name = "Plus"
		plus.text = "+"
		plus.position = Vector2(100, 4)
		plus.size = Vector2(16, 14)
		plus.add_theme_font_size_override("font_size", 9)
		plus.pressed.connect(func(): buy(k))
		plus.mouse_entered.connect(func(): tip_lbl.text = "Spend 1 sign point for another %s sign.  Points: %s" % [CATS[k].name, ledger_text("points")])
		slot.add_child(plus)
		var btn := Button.new()
		btn.flat = true
		btn.size = Vector2(96, 40)
		btn.pressed.connect(func(): _open_radial(k, Vector2(slot.position.x + bar.position.x + 60, bar.position.y - 70)))
		btn.mouse_entered.connect(func(): tip_lbl.text = "%s x%d  (%s).  Click to choose a sign." % [CATS[k].name, hand.get(k, 0), ledger_text(k)])
		slot.add_child(btn)
		slot.move_child(btn, 0)
		bar.add_child(slot)
		slot_nodes[k] = slot
		x += 126
	radial = Control.new()
	radial.visible = false
	radial.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(radial)
	toast_lbl = _label(root, Vector2(0, 40), 11)
	toast_lbl.size = Vector2(640, 20)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.visible = false
	_build_card(root)
	end_lbl = _label(root, Vector2(0, 140), 22)
	end_lbl.size = Vector2(640, 60)
	end_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_lbl.visible = false
	_refresh_slots()
	toast("Press 1 for MOVEMENT, pick EXCAVATE, plant it under the trench. Lemmings do the rest.")
	toast_t = 8.0

func _label(parent: Node, pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 2)
	parent.add_child(l)
	return l

func _refresh_slots() -> void:
	if slot_nodes.is_empty():
		return
	for k in CAT_ORDER:
		var slot: Control = slot_nodes[k]
		var n: int = hand.get(k, 0)
		slot.get_node("Count").text = "x%d" % n
		slot.get_node("Icon").modulate = Color(1, 1, 1) if n > 0 else Color(0.55, 0.55, 0.55)
		slot.get_node("Plus").visible = points >= 1

func _tick_hud() -> void:
	var m := int(game_time / 60)
	var s := int(game_time) % 60
	var nxt := int(BAL.sign_tick - sign_clock)
	top_lbl.text = "LEMMINGS %d   civ %d  sol %d  eng %d  (sgt %d  mst %d)     SIGN POINTS %d (next +1 in %d:%02d)     FLAGS %d     QUEEN FED %d/%d%s     %d:%02d" % [
		lems.size(), count("civ"), count("sol"), count("eng"), count_rank("sergeant"), count_rank("master"), points, nxt / 60, nxt % 60, flags, queen.fed, BAL.queen_meal,
		"  SHE RISES!" if queen.mega else "", m, s]

func toast(t: String) -> void:
	if autotest:
		print("[toast] ", t)
		return
	toast_lbl.text = t
	toast_lbl.visible = true
	toast_t = 3.0

func _end(won: bool) -> void:
	game_over = true
	end_lbl.visible = true
	end_lbl.text = "THE QUEEN IS DEAD. THE LEMMINGS LIVE." if won else ("THE QUEEN HAS RISEN." if queen.mega else "EVERY LAST LEMMING IS GONE.")
	toast("Backspace for menu.")
	if won:
		_play("heart")
	else:
		_play("roar")

# ---------------- FX / AUDIO ----------------
var sfx := {}
func _play(n: String) -> void:
	if autotest:
		return
	if not sfx.has(n):
		var p := AudioStreamPlayer.new()
		p.stream = load("res://assets/audio/%s.wav" % n)
		p.volume_db = -8.0
		add_child(p)
		sfx[n] = p
	if not sfx[n].playing:
		sfx[n].play()

func puff(pos: Vector2, col: Color, amount: int = 10, spread: float = 8.0) -> void:
	if autotest:
		return
	var p := CPUParticles2D.new()
	p.position = pos
	p.amount = amount
	p.lifetime = 0.5
	p.one_shot = true
	p.explosiveness = 1.0
	p.direction = Vector2(0, -1)
	p.spread = 70.0
	p.initial_velocity_min = spread * 2.0
	p.initial_velocity_max = spread * 5.0
	p.gravity = Vector2(0, 120)
	p.scale_amount_min = 1.0
	p.scale_amount_max = 2.0
	p.color = col
	p.emitting = true
	fx_layer.add_child(p)
	p.finished.connect(p.queue_free)

# ---------------- AUTOTEST ----------------
func _run_autotest() -> void:
	print("AUTOTEST: lemmings apocalypse (lems=%d signs=%d)" % [lems.size(), signs.size()])
	if "--mega" in OS.get_cmdline_user_args():
		_go_mega()
		var t1 := 0.0
		var y0: int = queen.cell.y
		while t1 < 400.0 and not game_over:
			step(0.1); t1 += 0.1
			if int(t1 * 10) % 400 == 0:
				print("  t=%d queen=%s hp=%d bugs=%d lems=%d" % [int(t1), str(queen.cell), queen.hp, bugs.size(), lems.size()])
		print("MEGA: queen rose from y=%d to y=%d, game_over=%s" % [y0, queen.cell.y, str(game_over)])
		get_tree().quit(0 if queen.cell.y < y0 - 20 else 1)
		return
	if "--shaft" in OS.get_cmdline_user_args():
		var es := _place_sign("engschool", Vector2i(34, SURF_Y + 1))
		var t0 := 0.0
		while t0 < 40.0:
			step(0.1); t0 += 0.1
		var sh0 := _place_sign("shaft", Vector2i(30, SURF_Y + 2))
		print("shaft placed: ", not sh0.is_empty(), " eng=", count("eng"))
		while t0 < 200.0:
			step(0.1); t0 += 0.1
			if int(t0 * 10) % 200 == 0:
				var info := []
				for l in sh0.crew:
					info.append("%s role=%s path=%d timer=%.1f meta=%s cell=%s" % [l.kind, l.role, l.path.size(), l.timer, str(l.get_meta("dig", Vector2i(-9,-9))), str(cell_of(l))])
				print("  t=%d left=%d work=%s crew=%s" % [int(t0), sh0.dig_cells.size(), str(sh0.work), str(info)])
		print("bugs killed=%d kidnapped=%d" % [bugs_killed, kidnapped])
		get_tree().quit(0)
		return
	var limit := 60.0
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--t="):
			limit = float(a.substr(4))
	# dig down from the trench, train soldiers, patrol, sink a shaft
	var ok := true
	var s1 := _place_sign("excavate", Vector2i(29, SURF_Y + 3))
	var s2 := _place_sign("training", Vector2i(23, SURF_Y + 1))
	var s3 := _place_sign("engschool", Vector2i(34, SURF_Y + 1))
	ok = ok and not s1.is_empty() and not s2.is_empty() and not s3.is_empty()
	var t := 0.0
	var tick := 0
	while t < min(60.0, limit):
		step(0.1); t += 0.1; tick += 1
		if tick % 100 == 0:
			print("  t=%d lems=%d bugs=%d" % [int(t), lems.size(), bugs.size()])
	print("t=60 civ=%d sol=%d eng=%d dug_left=%d signs=%d" % [count("civ"), count("sol"), count("eng"), s1.dig_cells.size() if s1 in signs else -1, signs.size()])
	ok = ok and count("sol") >= 3 and count("eng") >= 3
	var s4 := _place_sign("excavate", Vector2i(29, SURF_Y + 8))
	var s5 := _place_sign("patrol", Vector2i(24, SURF_Y + 5))
	ok = ok and not s4.is_empty() and not s5.is_empty()
	while t < 160.0:
		step(0.1); t += 0.1
	print("t=160 civ=%d sol=%d eng=%d bugs=%d fed=%d points=%d flags=%d" % [count("civ"), count("sol"), count("eng"), bugs.size(), queen.fed, points, flags])
	var sh := _place_sign("shaft", Vector2i(30, SURF_Y + 12))
	ok = ok and not sh.is_empty()
	while t < 420.0:
		step(0.1); t += 0.1
	print("t=420 civ=%d sol=%d eng=%d bugs=%d fed=%d kidnapped=%d shaft_left=%d queen_hp=%d lems=%d" % [count("civ"), count("sol"), count("eng"), bugs.size(), queen.fed, kidnapped, sh.dig_cells.size() if sh in signs else -1, queen.hp, lems.size()])
	if sh in signs:
		for l in sh.crew:
			print("  shaft crew: %s role=%s path=%d meta=%s cell=%s" % [l.kind, l.role, l.path.size(), str(l.get_meta("dig", Vector2i(-9,-9))), str(cell_of(l))])
		print("  shaft left: ", sh.dig_cells, " work=", sh.work)
	ok = ok and (sh not in signs or sh.dig_cells.is_empty())
	print("strike returned: ", sh not in signs, " eng tokens=", hand.eng)
	ok = ok and bugs_killed > 0
	ok = ok and s1 not in signs   # first excavation finished and returned
	print("hand=", hand, " points=", points, " bugs_killed=", bugs_killed, " sgt=", count_rank("sergeant"), " mst=", count_rank("master"))
	ok = ok and count("sol") <= 12 and count_rank("sergeant") == 2
	ok = ok and hand.move == 5 and hand.mil == 1
	for i in min(4, bugs.size()):
		var b: Bug = bugs[i]
		print("  bug %d: cell=%s state=%s path=%d target=%s" % [i, str(cell_of(b)), b.state, b.path.size(), "none" if b.target == null else str(cell_of(b.target))])
	print("AUTOTEST ", "PASS" if ok else "FAIL")
	get_tree().quit(0 if ok else 1)
