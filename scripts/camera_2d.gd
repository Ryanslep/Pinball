extends Camera2D

var _target: Node2D

func set_target(t: Node2D) -> void:
	_target = t
	make_current()
	var had := position_smoothing_enabled
	position_smoothing_enabled = false
	if _target:
		global_position = _target.global_position
	reset_smoothing()
	position_smoothing_enabled = had

func _physics_process(_dt: float) -> void:
	if _target:
		global_position = _target.global_position
