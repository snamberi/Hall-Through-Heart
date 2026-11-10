class_name HitSpark
extends Sprite2D
## A flash and a few flying chips where a blow lands.

const SPARK: Texture2D = preload("res://assets/effects/spark.png")


static func spawn(parent: Node, at: Vector2, color: Color = Color(1.0, 0.95, 0.8), big: bool = false) -> void:
	var spark := HitSpark.new()
	spark.texture = SPARK
	spark.hframes = 4
	spark.position = at
	spark.rotation = randf() * TAU
	spark.modulate = color
	spark.scale = Vector2.ONE * (2.4 if big else 1.6)
	spark.z_index = 60
	parent.add_child(spark)

	var chips := CPUParticles2D.new()
	chips.amount = 10 if big else 6
	chips.lifetime = 0.3
	chips.one_shot = true
	chips.explosiveness = 1.0
	chips.spread = 180.0
	chips.gravity = Vector2.ZERO
	chips.initial_velocity_min = 60.0
	chips.initial_velocity_max = 170.0
	chips.damping_min = 300.0
	chips.damping_max = 400.0
	chips.scale_amount_min = 2.0
	chips.scale_amount_max = 3.0
	chips.color = color
	chips.rotation = -spark.rotation
	spark.add_child(chips)
	chips.emitting = true

	var tween := spark.create_tween()
	tween.tween_property(spark, "frame", 3, 0.16)
	tween.tween_property(spark, "self_modulate:a", 0.0, 0.01)
	tween.tween_interval(0.3)
	tween.tween_callback(spark.queue_free)
