extends PathFollow2D
## Glowing pulse that travels along a cable (Path2D), looping.

@export var speed := 0.35        # path lengths per second
@export var start_ratio := 0.0   # where along the cable it starts (0-1)
@export var time_scale := 1.0


func _ready() -> void:
	progress_ratio = fposmod(start_ratio, 1.0)


func _process(delta: float) -> void:
	progress_ratio = fposmod(progress_ratio + speed * delta * time_scale, 1.0)
