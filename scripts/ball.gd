extends RigidBody2D

@export var min_speed: float = 250.0
@export var max_speed: float = 1400.0
@export var target_speed: float = 900.0  # “feel” speed the ball tends toward
@export var accel_towards_target: float = 0.0  # set to 80–150 if you want slight auto-boost
@export var nudge_strength: float = 300.0
@export var nudge_cooldown: float = 0.3  # seconds between nudges

var can_nudge: bool = true

func _physics_process(delta: float) -> void:
	handle_nudge()

func handle_nudge() -> void:
	# Input actions from the project settings (add them if not defined)
	if can_nudge:
		var impulse = Vector2.ZERO
		if Input.is_action_just_pressed("nudge_left"):
			impulse = Vector2.LEFT * nudge_strength
		elif Input.is_action_just_pressed("nudge_right"):
			impulse = Vector2.RIGHT * nudge_strength
		elif Input.is_action_just_pressed("nudge_up"):
			impulse = Vector2.UP * nudge_strength  # optional, pushes upward on table

		if impulse != Vector2.ZERO:
				apply_impulse(impulse)
				can_nudge = false
				# Simple cooldown
				get_tree().create_timer(nudge_cooldown).connect("timeout", Callable(self, "_on_nudge_reset"))

func _on_nudge_reset() -> void:
	can_nudge = true

func _ready() -> void:
	# Physics material for lively bounces
	var mat := PhysicsMaterial.new()
	mat.bounce = 0.9          # restitution; 0.85–0.98 feels pinball-ish
	mat.friction = 0.1        # low friction keeps speed
	$CollisionShape2D.set_deferred("material", mat)

	# Avoid tunneling at high speeds
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE

	# Keep engine damping from eating momentum
	linear_damp = 0.0
	angular_damp = 0.1
	gravity_scale = 3.5  # tune per table slope

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Optional: nudge velocity towards a target speed to preserve "pinball feel"
	var v := state.linear_velocity
	var speed := v.length()

	if accel_towards_target > 0.0 and speed > 0.001:
		var dir := v / speed
		var delta_v := (target_speed - speed)
		# Small acceleration towards target speed (helps keep gameplay lively)
		v += dir * clamp(delta_v, -accel_towards_target, accel_towards_target)

	# Clamp extremes so the ball never stalls or becomes uncontrollable
	speed = v.length()
	if speed < min_speed and speed > 0.001:
		v = v.normalized() * min_speed
	elif speed > max_speed:
		v = v.normalized() * max_speed

	state.linear_velocity = v
