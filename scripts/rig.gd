extends Node2D
## Zaki: a cut-out character built from the AI body-part art, rigged on Skeleton2D bones.
## Rest pose = every limb hanging straight down; poses are joint angles blended smoothly.

var skeleton: Skeleton2D
var bones := {}        # name -> Bone2D
var holders := {}      # name -> Node2D (carries the part's base rotation)
var sprites := {}      # name -> Sprite2D
var data: Dictionary
var faces := {}        # face name -> {"tex", "pivot"}
var face := ""
var angles := {}
var lens := {}

func setup(d: Dictionary) -> void:
	data = d
	skeleton = Skeleton2D.new()
	add_child(skeleton)
	for b in d.bones:
		var bone := Bone2D.new()
		bone.name = b.name
		bone.set_autocalculate_length_and_angle(false)
		bone.set_length(maxf(8.0, b.len))
		bone.position = Vector2(b.pos[0], b.pos[1])
		if b.parent == "":
			skeleton.add_child(bone)
		else:
			bones[b.parent].add_child(bone)
		bone.rest = bone.transform
		bones[b.name] = bone
		angles[b.name] = 0.0
		lens[b.name] = b.len
		var h := Node2D.new()
		h.rotation = b.rot
		bone.add_child(h)
		holders[b.name] = h
		var sp := Sprite2D.new()
		sp.centered = false
		sp.z_index = b.z
		sp.z_as_relative = true
		if b.tex != "":
			sp.texture = load(b.tex)
			sp.position = -Vector2(b.pivot[0], b.pivot[1])
		h.add_child(sp)
		sprites[b.name] = sp
	for f in d.faces:
		faces[f] = {"tex": load(d.faces[f].tex), "pivot": Vector2(d.faces[f].pivot[0], d.faces[f].pivot[1])}
	# far-side limbs slightly darker for depth
	for n in sprites:
		if n.ends_with("_b"):
			sprites[n].modulate = Color(0.8, 0.8, 0.85)
	set_face("neutral")

func set_face(f: String) -> void:
	if f == face or not faces.has(f):
		return
	face = f
	var sp: Sprite2D = sprites["head"]
	sp.texture = faces[f].tex
	sp.position = -faces[f].pivot

func pose(target: Dictionary, k: float) -> void:
	for n in bones:
		var t: float = target.get(n, 0.0)
		angles[n] = lerp_angle(angles[n], t, k)
		bones[n].rotation = angles[n]

## Lowest point of the feet below the hip, in rig pixels (so the rig can stand on a floor).
func foot_drop() -> float:
	var best := 0.0
	for side in ["f", "b"]:
		var t := Transform2D(angles["torso"], Vector2.ZERO)
		var up: Dictionary = _bone("leg_up_" + side)
		t = t * Transform2D(angles["leg_up_" + side], Vector2(up.pos[0], up.pos[1]))
		var lo: Dictionary = _bone("leg_lo_" + side)
		t = t * Transform2D(angles["leg_lo_" + side], Vector2(lo.pos[0], lo.pos[1]))
		var tip: Vector2 = t * Vector2(0, lens["leg_lo_" + side] - 10.0)
		best = maxf(best, tip.y)
	return best

func _bone(n: String) -> Dictionary:
	for b in data.bones:
		if b.name == n:
			return b
	return {}
