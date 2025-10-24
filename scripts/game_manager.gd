# Game.gd (AutoLoad)
extends Node

@export var BallScene: PackedScene = preload("res://scenes/ball.tscn")
@export var respawn_delay: float = 0.6
@export var shooter_nudge_px: float = 2.0  # tiny gap so we don't spawn touching


var _spawn: Node2D
var _cam: Camera2D
var _timer: Timer
var _launcher: AnimatableBody2D

func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	add_child(_timer)
	_timer.timeout.connect(_on_respawn_timeout)

	_cache_scene_refs()


func register_scene_refs(spawn: Node2D, cam: Camera2D, launcher: AnimatableBody2D) -> void:
	_spawn = spawn
	_cam = cam
	_launcher = launcher

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

func handle_ball_lost(ball: Node) -> void:
	if is_instance_valid(ball):
		ball.queue_free()
	_timer.stop()
	_timer.wait_time = respawn_delay
	_timer.start()

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
