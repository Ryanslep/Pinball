# Game.gd (AutoLoad)
extends Node

enum DecayMode { DROP_TO_ZERO, STEP_DOWN }

@export var BallScene: PackedScene = preload("res://scenes/ball.tscn")
@export var respawn_delay: float = 0.6
@export var shooter_nudge_px: float = 2.0  # tiny gap so we don't spawn touching
@export var combo_timeout: float = 2.0              # seconds without a hit before decay happens
@export var decay_mode: DecayMode = DecayMode.STEP_DOWN
@export var step_amount: int = 1                    # used when STEP_DOWN
@export var min_combo: int = 0                      # floor while stepping down
# (Optional) multiplier from combo, e.g., 1.0 + 0.1 per combo
@export var combo_multiplier_per_step: float = 0.10


signal num_balls_changed(num_balls: int)
signal score_changed(new_score: int)
signal combo_changed(new_combo: int)
signal game_over

var _is_game_over: bool = false

var score: int = 0:
	set(value):
		score = value
		score_changed.emit(score)
		
var combo: int = 0:
	set(value):
		combo = max(value, 0)
		combo_changed.emit(combo)
		
var num_balls:= 3:
	set(value):
		num_balls = value
		num_balls_changed.emit(num_balls)
		
var _combo_timer: Timer
var _spawn: Node2D
var _cam: Camera2D
var _timer: Timer
var _launcher: AnimatableBody2D
var _hud: Node

func _ready() -> void:
	_combo_timer = Timer.new()
	_combo_timer.one_shot = true
	add_child(_combo_timer)
	_combo_timer.timeout.connect(_on_combo_timeout)
	
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_respawn_timeout)

	_cache_scene_refs()
	

func reset_state(new_lives: int = 3) -> void:
	_is_game_over = false
	num_balls = new_lives
	score = 0
	combo = 0

func add_score(points: int) -> void:
	var mult:= get_multiplier()
	score += int(round(points * mult))

func register_hit(base_points: int = 100) -> void:
	combo += 1
	restart_combo_timer()
	add_score(base_points)

func get_multiplier() -> float:
	return 1.0 + float(combo) * combo_multiplier_per_step

func _on_combo_timeout() -> void:
	match decay_mode:
		DecayMode.DROP_TO_ZERO:
			combo = 0
		DecayMode.STEP_DOWN:
			combo -= step_amount
			if combo > min_combo:
				# keep stepping down every combo_timeout seconds until min_combo
				_combo_timer.start()

func restart_combo_timer() -> void:
	_combo_timer.stop()
	_combo_timer.wait_time = combo_timeout
	_combo_timer.start()

func reset_combo() -> void:
	combo = 0
	_combo_timer.stop()


func register_scene_refs(spawn: Node2D, cam: Camera2D, launcher: AnimatableBody2D, hud: Node) -> void:
	_spawn = spawn
	_cam = cam
	_launcher = launcher
	_hud = hud

func snap_camera_now() -> void:
	await get_tree().process_frame   # ensure nodes are ready this frame
	_snap_camera_to(_cam)            # you can reuse the helper from A, but pass the camera or the ball


func _cache_scene_refs() -> void:
	var s := get_tree().current_scene
	if s == null:
		return
	# Prefer Unique Name (%Spawn / %Camera2D). Fallback to name search.
	_spawn = s.get_node_or_null("%Spawn") as Node2D
	if _spawn == null:
		_spawn = s.find_child("Spawn", true, false) as Node2D

	_cam = s.get_node_or_null("%Camera2D") as Camera2D
	if _cam == null:
		_cam = get_viewport().get_camera_2d()
	
	_hud = s.get_node_or_null("%HUD") as Node2D
	if _hud == null:
		_hud = s.find_child("HUD", true, false) as Node2D

func handle_ball_lost(ball: Node) -> void:
	if is_instance_valid(ball):
		ball.queue_free()
	
	num_balls -= 1
	
	if num_balls <= 0:
		_is_game_over = true
		_timer.stop()
		game_over.emit()
		combo = 0
		return
	
	_timer.stop()
	_timer.wait_time = respawn_delay
	_timer.start()
	reset_combo()
	
	

func _on_respawn_timeout() -> void:
	Engine.time_scale = 1.0
	# If the scene changed (e.g., you reloaded), refresh references now.
	_cache_scene_refs()
	spawn_ball()

func spawn_ball() -> RigidBody2D:
	if BallScene == null:
		push_error("GameManager: BallScene is null.")
		return null

	# ensure refs are fresh (e.g., after reload)
	_cache_scene_refs()
	var ball := BallScene.instantiate() as RigidBody2D
	ball.global_position = _spawn.global_position
	
	get_tree().current_scene.add_child(ball)

	if _cam and _cam.has_method("set_target"):
		_cam.set_target(ball)
	else:
		_snap_camera_to(ball)   # fallback to Option A’s snap
	return ball


func _snap_camera_to(target: Node2D) -> void:
	_cache_scene_refs()
	if _cam == null or target == null:
		return
	_cam.make_current()
	var had := _cam.position_smoothing_enabled
	_cam.position_smoothing_enabled = false   # prevent easing lag this frame
	_cam.global_position = target.global_position
	_cam.reset_smoothing()
	_cam.position_smoothing_enabled = had
