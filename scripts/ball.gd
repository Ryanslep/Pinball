extends RigidBody2D

@export var min_speed: float = 50.0
@export var max_speed: float = 3000.0
@export var target_speed: float = 1500.0  # “feel” speed the ball tends toward
@export var accel_towards_target: float = 0.0  # set to 80–150 if you want slight auto-boost
@export var nudge_strength: float = 300.0
@export var nudge_cooldown: float = 0.3  # seconds between nudges

var can_nudge: bool = true

func _physics_process(_delta: float) -> void:
	handle_nudge()
	
var last_speed := 0.0


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
	# Avoid tunneling at high speeds
	continuous_cd = RigidBody2D.CCD_MODE_CAST_SHAPE
	if not is_in_group("ball"):
		add_to_group("ball")
	# Keep engine damping from eating momentum
	linear_damp = 0.05
	angular_damp = 0.05
	gravity_scale = 3  # tune per table slope
	contact_monitor = true

	

var last_v: Vector2 = Vector2.ZERO

func _integrate_forces(state: PhysicsDirectBodyState2D) -> void:
	# Optional: nudge velocity towards a target speed to preserve "pinball feel"
	var v := state.linear_velocity
	var speed := v.length()

	# --- Collision restitution logger (per-contact normal) ---
	var contact_count: int = state.get_contact_count()
	if contact_count > 0 and last_v.length() > 0.0:
		for i in contact_count:
			var n: Vector2 = state.get_contact_local_normal(i)
			if n.length() > 0.0:
				var v_n_before: float = last_v.dot(n)   # pre-impact normal component
				var v_n_after: float  = v.dot(n)        # post-impact normal component
				if v_n_before < -0.01:                  # was moving into the surface
					var e: float = absf(v_n_after) / max(absf(v_n_before), 0.0001)
					print("e ≈ ", "%.2f" % e, "  (n=", n, ")")

	# store for next step (do this *after* logging)
	last_v = v
	
	if speed > max_speed:
		v = v.normalized() * max_speed

	state.linear_velocity = v
	
