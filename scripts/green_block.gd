extends AnimatableBody2D

@export var impulse_strength: float = 600.0

func _on_sensor_body_entered(body: Node2D) -> void:
	if body:
		var dir := (body.global_position - global_position).normalized()
		body.apply_impulse(dir * impulse_strength)
