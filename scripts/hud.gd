extends Node

@onready var life_1: AnimatedSprite2D = $Life1
@onready var life_2: AnimatedSprite2D = $Life2
@onready var life_3: AnimatedSprite2D = $Life3
@onready var end_screen: Control = $EndScreen
@onready var restart_btn: Button = $EndScreen/RestartButton
@onready var quit_btn: Button = $EndScreen/QuitButton

		
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	
	GameManager.score_changed.connect(_on_score_changed)
	GameManager.combo_changed.connect(_on_combo_changed)
	GameManager.num_balls_changed.connect(_on_num_balls_changed)
	GameManager.game_over.connect(_on_game_over)

	# Initialize display immediately
	_on_score_changed(GameManager.score)
	_on_combo_changed(GameManager.combo)
	_on_num_balls_changed(GameManager.num_balls)
	
	restart_btn.pressed.connect(_on_restart_pressed)
	quit_btn.pressed.connect(_on_quit_pressed)

func _on_game_over() -> void:
	life_1.play("lose_life")
	end_screen.visible = true
	

func _on_restart_pressed() -> void:
	GameManager.reset_state(3)
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().quit()

func _on_score_changed(new_score: int) -> void:
	$Score.text = "SCORE: " + str(new_score)

func _on_combo_changed(_new_combo: int) -> void:
	var mult : float = GameManager.get_multiplier()
	if mult <= 1.0:
		$Combo.visible = false
	else:
		$Combo.visible = true
		$Combo.text = "COMBO x%.2f" % mult
		$Combo.scale = Vector2.ONE * 1.2
		$Combo.create_tween().tween_property($Combo, "scale", Vector2.ONE, 0.15)
		
func _on_num_balls_changed(n: int) -> void:
	if n == 2:
		life_3.play("lose_life")
	elif n == 1:
		life_2.play("lose_life")
	elif n == 0:
		life_1.play("lose_life")
		
	else:
		return
	
