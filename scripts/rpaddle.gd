extends AnimatableBody2D

@export var action_name: String = "flip_right"
@export var down_angle_deg: float = 00.0    # rest
@export var up_angle_deg:   float = 60.0    # flipped (adjust to taste)
@export var flip_time: float = 0.05
@export var return_time: float = 0.12
@export var swing_energy_gain := 3

var tw: Tween
var _last_rot: float = 0.0   # radians

func _ready() -> void:
	sync_to_physics = true
	rotation_degrees = down_angle_deg
	_last_rot = rotation
	# (Optional) a bit of bounce/friction on the paddle surface
	if $CollisionShape2D:
		var mat := PhysicsMaterial.new()
		mat.bounce = 5
		mat.friction = 0.15
		$CollisionShape2D.material = mat

func _physics_process(dt: float) -> void:
	_set_flipper(Input.is_action_pressed(action_name))
	_feed_motion_to_physics(dt)

func _set_flipper(up: bool) -> void:
	var target: float = up_angle_deg if up else down_angle_deg
	if tw and tw.is_running(): tw.kill()
	tw = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tw.tween_property(self, "rotation_degrees", target, (flip_time if up else return_time))

func _feed_motion_to_physics(dt: float) -> void:
	# Compute angular velocity from rotation change this physics step.
	var current_rot: float = rotation
	var omega: float = 0.0
	if dt > 0.0:
		omega = (current_rot - _last_rot) / dt   # radians/sec
	_last_rot = current_rot
	# Tell the physics engine our instantaneous angular velocity.
	constant_angular_velocity = omega * swing_energy_gain
