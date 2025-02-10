extends Control

var model: Model

@onready var gen_btn: Button = %GenerateButton
@onready var out: TextureRect = %Output
@onready var loading_txt: Label = %LoadingMsg
var seed_: int

signal loading (vis: bool)

func _ready() -> void:
	gen_btn.pressed.connect(_on_gen_button)
	seed_ = int(Time.get_unix_time_from_system())
	loading_txt.visible = false
	loading.connect(func(v): loading_txt.visible = v)

func _on_gen_button() -> void:
	loading.emit(true)
	model = OverlapModel2D.new("SimpleMaze.png", 3, 48, 48, 8, false, true, false, Model.Heuristic.Entropy)
	var success = model.run(seed_, -1)
	loading.emit(false)
	if success:
		print("success@!")
		var img = model.image()
		print(img.get_size())
		out.texture = ImageTexture.create_from_image(img)
	else:
		print("contradiction")
