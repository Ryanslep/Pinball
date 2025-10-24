# KillZone.gd
extends Area2D

var _fired := false
var _reset_timer: Timer

func _ready() -> void:
	monitoring = true
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

	_reset_timer = Timer.new()
	_reset_timer.one_shot = true
	_reset_timer.ignore_time_scale = true
	add_child(_reset_timer)
	_reset_timer.timeout.connect(func(): _fired = false)

func _on_body_entered(body: Node2D) -> void:
	if _fired: return
	if body is RigidBody2D and body.is_in_group("ball"):
		_fired = true
		GameManager.handle_ball_lost(body)   # or GameManager…, use your autoload name
		_reset_timer.start(0.2)               # small debounce window

		GameManager.handle_ball_lost(body)
