extends StaticBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@export var bump_strength: float = 1000.0
@export var bump_cooldown: float = 0.3 #Seconds between bumps

var can_bump: bool

func _ready() -> void:
	can_bump = true
	

func _on_area_2d_body_entered(body: Node2D) -> void:
	if body and can_bump:
		var dir := (body.global_position - global_position).normalized()
		body.apply_impulse(dir * bump_strength)
		can_bump = false
		# Simple cooldown
		get_tree().create_timer(bump_cooldown).connect("timeout", Callable(self, "_on_bump_reset"))
		animated_sprite_2d.play("Bump")
		GameManager.register_hit(100)

func _on_bump_reset() -> void:
	can_bump = true
