extends RigidBody2D

@export var motor_enabled := true
@export var motor_torque := 2500.0
@export var motor_dir := 1              # 1 = counter-clockwise, -1 = clockwise
@export var max_angular_speed := 4.0    # rad/s
@export var angular_drag := 0.5         # angular damping

func _ready() -> void:
	# Ensure it can rotate and isn’t stuck asleep
	freeze = false
	can_sleep = false
	set_sleeping(false)
	angular_damp = angular_drag
	gravity_scale = 0.0                 # keep it from falling if gravity is on
	
func _physics_process(delta: float) -> void:
	if motor_enabled:
		if is_sleeping():
			set_sleeping(false)

		# Apply continuous torque to spin the windmill
		apply_torque_impulse(motor_dir * motor_torque * delta)

	# Cap rotation speed so it doesn’t go crazy
	if abs(angular_velocity) > max_angular_speed:
		angular_velocity = signf(angular_velocity) * max_angular_speed
