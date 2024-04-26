extends Node2D

@onready var camera_2d = $Camera2D

const CAMERA_SPEED = 300.0

var velocity = Vector2.ZERO

const min_zoom = 0.21
const max_zoom = 3

func _process(delta):
	if Input.is_action_just_pressed("quit"):
		get_tree().quit()
	position += velocity / camera_2d.zoom
	velocity = Vector2.ZERO
	
	if Input.is_action_just_pressed("zoom_in"):
		camera_2d.zoom += Vector2(0.2, 0.2)
		if camera_2d.zoom.x > max_zoom:
			camera_2d.zoom = Vector2(max_zoom, max_zoom)
	elif Input.is_action_just_pressed("zoom_out"):
		camera_2d.zoom -= Vector2(0.2, 0.2)
		if camera_2d.zoom.x < min_zoom:
			camera_2d.zoom = Vector2(min_zoom, min_zoom)

func _input(event):
	if event is InputEventMouseMotion:
		if Input.is_action_pressed("move_camera"):
			velocity = -event.relative
