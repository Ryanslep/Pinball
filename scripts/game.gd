extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# Tell the autoload where the new scene’s camera & spawn are
	GameManager.register_scene_refs(%Spawn, %Camera2D, %Launcher, %HUD)
	await get_tree().process_frame
	GameManager.spawn_ball()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	pass
