@tool
extends Node

@export var resolution := 1024
@export var save_path := "res://addons/HeightmapGenerator/output/heightmap.png"
@export var debug_logging := false
var ceiling
var floor


func _ready() -> void:
	if get_child_count() == 0: # prevent duplicating children on project reloads
		ceiling = createPlane("Ceiling", 5)
		floor = createPlane("Floor", -5)


func createPlane(name, height) -> MeshInstance3D:
	# Create and parent the node
	var plane = MeshInstance3D.new()
	add_child(plane)
	# The line below is required to make the node visible in the Scene tree dock
	# and persist changes made by the tool script to the saved scene file.
	plane.owner = get_tree().edited_scene_root		
	plane.name = name
	plane.global_position = Vector3(0, height, 0)

	# Create and assign the plane mesh
	var mesh = PlaneMesh.new()
	mesh.size = Vector2(10, 10)
	plane.mesh = mesh

	# Create and set the material for the mesh
	var material = StandardMaterial3D.new()
	material.albedo_color = Color(0.7, 0.2, 0.2, 0.75)
	material.flags_transparent = true
	mesh.surface_set_material(0, material)

	return plane


func generate_heightmap() -> void:	
	# We're generating a square image, so make sure our raycasting source is square
	assert(ceiling.mesh.size.x == ceiling.mesh.size.y, "Ceiling mesh size.x must equal size.y!")
	assert(ceiling.scale.x == ceiling.scale.z, "Ceiling scale.x must equal scale.z!")

	var bounds = ceiling.get_aabb()
	var celing_y = ceiling.global_position.y

	# Ensure we are taking the ceiling's scale into account if it has changed
	var scale = ceiling.scale.x
	var extents = bounds.size.x * ceiling.scale.x
	var start_pos = (bounds.position * scale) + ceiling.global_position

	var step_size = extents / resolution
	var ray_length = ceiling.global_position.y - floor.global_position.y

	# We will offset the rays by half the step size to center them on the grid cells
	var offset = step_size / 2
	
	if debug_logging:
		print("Scaled bounds begin at: %s" % str(start_pos))
		print("Scaled size is: %s" % str(extents))
		print("Step size: %s" % str(step_size))
		print("Offset: %s" % str(offset))
		print("Ceiling: %s" % str(ceiling.global_position.y))
		print("Floor: %s" % str(floor.global_position.y))
		print("Ray length: %s" % str(ray_length))

	var heightmap = Image.create(resolution, resolution, false, Image.FORMAT_RGBA8)
	var space_state = ceiling.get_world_3d().direct_space_state
	for x in range(resolution):
		var cur_x = start_pos.x + offset + x * step_size
		for z in range(resolution):
			var cur_z = start_pos.z + offset + z * step_size
			var ray_origin = Vector3(cur_x, celing_y, cur_z)
			var ray_direction = Vector3(0, -1, 0)

			var ray = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * ray_length)
			var collision = space_state.intersect_ray(ray)

			if collision:
				# print("Collision at (%s, %s) at height %s" % [x, z, height])
				var height = (celing_y - collision.position.y) / ray_length
				heightmap.set_pixel(x, z, Color(1-height, 1-height, 1-height))
			else:
				heightmap.set_pixel(x, z, Color(0, 0, 0))
	
	# Generate and save texture file
	heightmap.save_png(save_path)
	print("Heightmap generated and saved to: " + save_path)