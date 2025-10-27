extends StaticBody2D
@onready var animation_player: AnimationPlayer = $Sprite2D/AnimationPlayer

@export var launch_strength: float = 1000.0
@export var launch_cooldown: float = 0.3 #Seconds between bumps

var can_launch: bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	can_launch = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass


func _on_area_2d_body_entered(body: Node2D) -> void:
	if body and can_launch:
		var dir := (body.global_position - global_position).normalized()
		body.apply_impulse(dir * launch_strength)
		can_launch = false
		# Simple cooldown
		get_tree().create_timer(launch_cooldown).connect("timeout", Callable(self, "_on_launch_reset"))
		animation_player.play("launch")
		GameManager.register_hit(60)

func _on_launch_reset() -> void:
	can_launch = true
