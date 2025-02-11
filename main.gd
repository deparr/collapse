extends Control

var model: Model

@onready var gen_btn: Button = %GenerateButton
@onready var gen_seed: Button = %NewSeed
@onready var seed_label: Label = %Seed
@onready var image_grid: GridContainer = %OutputGrid
var seed_: int:
	set(v):
		seed_label.text = " %d " % v
		seed_ = v

func new_seed() -> void:
	seed_ = int(Time.get_unix_time_from_system())

func _ready() -> void:
	gen_btn.pressed.connect(_on_gen_button)
	new_seed()
	gen_seed.pressed.connect(new_seed)
	for _i in 9:
		image_grid.add_child(TextureRect.new())


func _on_gen_button() -> void:
	model = OverlapModel2D.new("3Bricks.png", 3, 48, 48, 1, true, true, false, Model.Heuristic.Entropy)
	var success = model.run(seed_, -1)
	if success:
		var img := model.image()
		var tex := ImageTexture.create_from_image(img)
		for out in image_grid.get_children():
			out.texture = tex
	else:
		print("contradiction")
