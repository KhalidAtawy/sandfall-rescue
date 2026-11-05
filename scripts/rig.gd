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
		bone.set_length(maxf(8.0, float(b.get("len", 0.0))))
		bone.position = Vector2(b.pos[0], b.pos[1])
		if b.parent == "":
			skeleton.add_child(bone)
		else:
			bones[b.parent].add_child(bone)
		bone.rest = bone.transform
		bones[b.name] = bone
		angles[b.name] = 0.0
		lens[b.name] = float(b.get("len", 0.0))
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

## Two-bone IK: bend the arm so the hand lands on `target` (rig pixels, +x toward the door).
## The elbow takes the lower of the two solutions, the natural bend when pushing.
func ik_arm(side: String, target: Vector2, elbow_back := false, min_frac := 0.0) -> void:
	var up := "arm_up_" + side
	var lo := "arm_lo_" + side
	var b: Dictionary = _bone(up)
	var ta: float = angles["torso"]
	var sh := Vector2(b.pos[0], b.pos[1]).rotated(ta)
	var a: float = lens[up]
	var c: float = lens[lo]
	var v := target - sh
	var min_d := min_frac * (a + c)
	if min_frac > 0.0 and v.length() < min_d and absf(v.x) < min_d:
		# too close to reach comfortably: slide the hand down the door
		v = Vector2(v.x, sqrt(min_d * min_d - v.x * v.x))
	var d := clampf(v.length(), absf(a - c) + 1.0, a + c - 1.0)
	var base := v.angle()
	var ca := clampf((a * a + d * d - c * c) / (2.0 * a * d), -1.0, 1.0)
	var ang := acos(ca)
	var e1 := sh + Vector2.from_angle(base + ang) * a
	var e2 := sh + Vector2.from_angle(base - ang) * a
	var e: Vector2 = e1 if e1.y > e2.y else e2
	if elbow_back:
		e = e1 if e1.x < e2.x else e2
	var tip := sh + v.normalized() * d
	var du := e - sh
	var df := tip - e
	var tu := atan2(-du.x, du.y)
	var tf := atan2(-df.x, df.y)
	angles[up] = tu - ta
	angles[lo] = tf - tu
	bones[up].rotation = angles[up]
	bones[lo].rotation = angles[lo]
