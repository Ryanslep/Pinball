extends Area2D

@export var hold_time: float = 0.15   # seconds to “grab” the ball
@export var snap_offset_px: float = 2 # small offset away from the plunger head if needed

func _ready() -> void:
	monitoring = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is RigidBody2D and body.is_in_group("ball"):
		# Do NOT change freeze/mode here; defer it to after the physics step.
		call_deferred("_capture_ball", body)

func _capture_ball(body: RigidBody2D) -> void:
	if not is_instance_valid(body):
		return
	# Safe to change now
	body.linear_velocity = Vector2.ZERO
	body.angular_velocity = 0.0
	#body.set_deferred("freeze", true)  # freeze must be deferred (engine-side state)
	# Optional snap away from the plunger head; also defer to be extra safe
