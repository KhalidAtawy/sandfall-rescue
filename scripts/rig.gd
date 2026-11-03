extends Node2D
## A cut-out character built from rendered body parts and rigged on Skeleton2D bones.
## Each part hangs off a Bone2D placed at its joint; poses are set as joint angles
## and blended smoothly, so the game can drive animations from code.

var skeleton: Skeleton2D
var bones := {}        # part name -> Bone2D
var sprites := {}      # part name -> Sprite2D
var data: Dictionary
var prefix := ""
var faces := {}        # face name -> {"tex": Texture2D, "crop": Vector2}
var face := ""
var angles := {}       # current blended angle per bone
var root_offset := Vector2.ZERO

func setup(d: Dictionary, pfx: String, tint := Color.WHITE) -> void:
	data = d
	prefix = pfx
	skeleton = Skeleton2D.new()
	add_child(skeleton)
	var joints: Dictionary = d.joints
	for part in d.order:
		var jn: String = d.joint_of[part]
		var jp := Vector2(joints[jn][0], joints[jn][1])
		var b := Bone2D.new()
		b.name = part
		b.set_autocalculate_length_and_angle(false)
		b.set_length(24.0)
		var parent = d.parents[part]
		if parent == null:
			skeleton.add_child(b)
		else:
			var pj: Array = joints[d.joint_of[parent]]
			b.position = jp - Vector2(pj[0], pj[1])
			bones[parent].add_child(b)
		b.rest = b.transform
		bones[part] = b
		angles[part] = 0.0
		var sp := Sprite2D.new()
		sp.centered = false
		sp.z_index = d.z[part]
		sp.modulate = tint
		var key: String = part
		if part == "head" and d.has("faces"):
			for f in d.faces:
				var k: String = "head_" + f
				faces[f] = {"tex": load("res://assets/gfx/rig/%s%s.png" % [pfx, k]),
					"crop": Vector2(d.parts[k].crop[0], d.parts[k].crop[1]) - jp}
			key = "head_" + d.faces[0]
		sp.texture = load("res://assets/gfx/rig/%s%s.png" % [pfx, key])
		sp.position = Vector2(d.parts[key].crop[0], d.parts[key].crop[1]) - jp
		b.add_child(sp)
		sprites[part] = sp
	# far-side limbs a touch darker for depth
	for part in sprites:
		if part.ends_with("_b"):
			sprites[part].modulate = tint * Color(0.82, 0.82, 0.86)
	if d.has("faces"):
		set_face(d.faces[0])

func set_face(f: String) -> void:
	if f == face or not faces.has(f):
		return
	face = f
	var sp: Sprite2D = sprites["head"]
	sp.texture = faces[f].tex
	sp.position = faces[f].crop

## Blend every bone toward the target angles (radians). Bones not listed return to rest.
func pose(target: Dictionary, k: float) -> void:
	for part in bones:
		var t: float = target.get(part, 0.0)
		angles[part] = lerp_angle(angles[part], t, k)
		bones[part].rotation = angles[part]

## Snap straight to a pose (used when a level starts).
func snap(target: Dictionary) -> void:
	for part in bones:
		angles[part] = target.get(part, 0.0)
		bones[part].rotation = angles[part]

## Height of the joint above the soles, in render pixels (used to stand the rig on a floor).
func hip_height(sole_y: float) -> float:
	var hp: Array = data.joints[data.joint_of[data.order[0]]]
	return sole_y - hp[1]
