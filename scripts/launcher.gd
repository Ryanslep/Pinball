# launcher.gd
# Attach to: Plunger (AnimatableBody2D)
# Node tree (recommended):
# Plunger (AnimatableBody2D)
# ├─ CollisionShape2D        # the plunger head collider (thick enough)
# ├─ Sprite2D                # visual (optional)
# └─ Sensor (Area2D)         # optional; only if you want to also apply direct impulse
#    └─ CollisionShape2D

extends AnimatableBody2D      

# --------- Gameplay tuning ---------
@export var action_name: String = "plunger"   # hold to charge, release to fire
@export var direction: Vector2 = Vector2.UP   # launch direction (normalized at runtime)
@export var max_pull_dist: float = 240.0       # px you can pull back (visual + physical travel)
@export var charge_rate: float = 180.0        # px/s while holding

@export var head_gap_px: float = 4.0      # how far to pull back after the hit
@export var head_gap_time: float = 0.10   # how long to hold the gap before restoring
# Make tiny pulls weak:
@export var deadzone_px: float = 10.0         # pulls below this are ignored
@export var power_curve: float = 5          # >1 weakens early pull, try 2.0–3.0

# Snap-forward timing scales with pull (smaller pull -> slower return -> less kick)
@export var min_return_time: float = 0.1     # used for tiny pulls (gentler)
@export var base_return_time: float = 0.06    # used for full pull (snappier)

# Optional extra impulse (only if not relying purely on physical hit)
@export var use_extra_impulse: bool = true
@export var max_impulse: float = 3000.0       # scales 0..max with t; only used if use_extra_impulse = true

# Physics material for the head/body (tame bounce to avoid jitter)
@export var head_bounce: float = 0
@export var head_friction: float = 1

# --------- Node refs (optional) ---------
@onready var head: CollisionShape2D = $CollisionShape2D
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")
@onready var sensor: Area2D = get_node_or_null("Sensor")  # optional; can be null

# --------- Internal state ---------
enum LaunchState { IDLE, CHARGING, FIRING, RECOVERING }
var _pull: float = 0.0
var _tw: Tween
var _rest_global: Vector2
var _last_global: Vector2
var _captured_ball: RigidBody2D = null
var _sensor_enabled: bool = true
var _state: int = LaunchState.IDLE

func _ready() -> void:
	direction = direction.normalized()
	sync_to_physics = true
	_rest_global = global_position
	_last_global = global_position

	var pm := PhysicsMaterial.new()
	pm.bounce = 0.25 if head_bounce < 0.0 else head_bounce
	pm.friction = max(0.0, head_friction)
	physics_material_override = pm

	if sensor:
		sensor.monitoring = false
		_sensor_enabled = false
		if not sensor.body_entered.is_connected(_on_sensor_body_entered):
			sensor.body_entered.connect(_on_sensor_body_entered)


func _physics_process(dt: float) -> void:
	# BEGIN CHARGING
	if Input.is_action_just_pressed(action_name):
		_state = LaunchState.CHARGING
		_set_sensor_enabled(true)  # allow capture only while charging

	if Input.is_action_pressed(action_name):
		_pull = clamp(_pull + charge_rate * dt, 0.0, max_pull_dist)
		_set_pull_position(_pull)

	# FIRE
	elif Input.is_action_just_released(action_name):
		_fire()

	# IDLE
	elif _pull <= 1.0 and _state != LaunchState.FIRING and _state != LaunchState.RECOVERING:
		_state = LaunchState.IDLE
		_pull = 0.0
		_set_pull_position(0.0)
		_set_sensor_enabled(false)  # sensor off when idle

	# Moving-platform safety: feed motion ONLY while firing
	var v: Vector2 = (global_position - _last_global) / max(dt, 0.0001)
	constant_linear_velocity = (v if _state == LaunchState.FIRING else Vector2.ZERO)
	_last_global = global_position

func _set_pull_position(p: float) -> void:
	if _tw and _tw.is_running(): _tw.kill()
	global_position = _rest_global - direction * p

func _fire() -> void:
	if _pull < deadzone_px:
		_pull = 0.0
		_set_pull_position(0.0)
		_unfreeze_captured_ball()
		_state = LaunchState.IDLE
		_set_sensor_enabled(false)
		return

	var t: float = pow(_pull / max_pull_dist, power_curve)
	var time_for_this_pull: float = lerp(min_return_time, base_return_time, clamp(t, 0.0, 1.0))

	_unfreeze_captured_ball()
	_set_sensor_enabled(false)  # prevent re-capture during the shot

	_state = LaunchState.FIRING
	call_deferred("_start_forward_snap", time_for_this_pull)
	_pull = 0.0

	if use_extra_impulse:
		var ball := _get_ball_in_front()
		if ball:
			ball.apply_impulse(direction * (max_impulse * t))

func _start_forward_snap(time_for_this_pull: float) -> void:
	if _tw and _tw.is_running(): _tw.kill()

	_tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	_tw.tween_property(self, "global_position", _rest_global, time_for_this_pull)

	_tw.finished.connect(func():
		constant_linear_velocity = Vector2.ZERO
		_post_hit_separation()
	)

func _post_hit_separation() -> void:
	_state = LaunchState.RECOVERING

	var gap_pos := _rest_global - direction * head_gap_px
	global_position = gap_pos
	if head:
		head.set_deferred("disabled", true)

	var tmr := get_tree().create_timer(head_gap_time)
	tmr.timeout.connect(func():
		global_position = _rest_global
		if head:
			head.set_deferred("disabled", false)
		_state = LaunchState.IDLE
		_set_sensor_enabled(false)  # stay off until the next charge press
	)


func _set_sensor_enabled(enabled: bool) -> void:
	_sensor_enabled = enabled
	if sensor:
		sensor.set_deferred("monitoring", enabled)

func _unfreeze_ball_before_shot() -> void:
	if _captured_ball and is_instance_valid(_captured_ball):
		_captured_ball.set_deferred("freeze", false)
		_captured_ball.can_sleep = false          # don’t fall asleep at the trigger
	# Clear now so we never re-freeze it mid-shot
	_captured_ball = null

func _disable_head_temporarily(duration: float) -> void:
	if head == null:
		return
	head.disabled = true
	var timer := get_tree().create_timer(duration)
	timer.timeout.connect(func(): head.disabled = false)

func _get_ball_in_front() -> RigidBody2D:
	if sensor == null:
		return null
	var best: RigidBody2D = null
	var best_d: float = INF
	var bodies := sensor.get_overlapping_bodies()
	for b in bodies:
		if b is RigidBody2D and b.is_in_group("ball"):
			var d: float = global_position.distance_to(b.global_position)
			if d < best_d:
				best = b
				best_d = d
	return best

func _briefly_disable_head_collision() -> void:
	if head == null:
		return
	head.disabled = true
	var tmr := get_tree().create_timer(0.08)  # 80 ms; adjust to taste
	tmr.timeout.connect(func():
		head.disabled = false
	)

func _on_sensor_body_entered(body: Node2D) -> void:
	if not _sensor_enabled or _state != LaunchState.CHARGING:           # ignore while firing/recovering
		return
	if body is RigidBody2D and body.is_in_group("ball"):
		_captured_ball = body
		_captured_ball.linear_velocity = Vector2.ZERO
		_captured_ball.angular_velocity = 0.0
		_captured_ball.set_deferred("freeze", true)

func _unfreeze_captured_ball() -> void:
	if _captured_ball and is_instance_valid(_captured_ball):
		_captured_ball.set_deferred("freeze", false)
		_captured_ball.can_sleep = false
	_captured_ball = null
