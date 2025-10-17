extends StaticBody2D

@export var impulse_strength: float = 800.0

func _on_area_entered(area: Area2D) -> void:
	var body := area.get_parent() as RigidBody2D
	if body:
		var dir := (body.global_position - global_position).normalized()
		body.apply_impulse(dir * impulse_strength)
