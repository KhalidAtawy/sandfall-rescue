extends Node2D
## A chaser (golem, mummy, cobra): one AI image on a triangle mesh, bent by bones with
## linear blend skinning. Each vertex follows up to three bones by its weights.

var d: Dictionary
var poly: Polygon2D
var rest := PackedVector2Array()
var wi := PackedInt32Array()
var ww := PackedFloat32Array()
var joints: Array = []      # Vector2 per bone (rest, texture px)
var parents: Array = []     # parent index per bone (-1 = root)
var names: Array = []
var angles := {}
var size := Vector2.ZERO
var foot := Vector2.ZERO
var front := 0.0

func setup(data: Dictionary) -> void:
	d = data
	size = Vector2(d.size[0], d.size[1])
	foot = Vector2(d.foot[0], d.foot[1])
	front = d.front
	var v: Array = d.verts
	for i in range(0, v.size(), 2):
		rest.append(Vector2(v[i], v[i + 1]))
	wi = PackedInt32Array(d.wi)
	ww = PackedFloat32Array(d.ww)
	var idx := {}
	for i in d.bones.size():
		var b: Dictionary = d.bones[i]
		names.append(b.name)
		idx[b.name] = i
		joints.append(Vector2(b.joint[0], b.joint[1]))
		parents.append(-1 if b.parent == "" else idx[b.parent])
		angles[b.name] = 0.0
	poly = Polygon2D.new()
	poly.texture = load(d.tex)
	poly.polygon = rest
	poly.uv = rest
	var tris: Array = d.tris
	var polys := []
	for i in range(0, tris.size(), 3):
		polys.append(PackedInt32Array([tris[i], tris[i + 1], tris[i + 2]]))
	poly.polygons = polys
	add_child(poly)

func pose(target: Dictionary, k: float) -> void:
	for n in names:
		var t: float = target.get(n, 0.0)
		angles[n] = lerp_angle(angles[n], t, k)
	_skin()

func _skin() -> void:
	var world := []
	var skin := []
	for i in names.size():
		var a: float = angles[names[i]]
		var w: Transform2D
		if parents[i] < 0:
			w = Transform2D(a, joints[i])
		else:
			w = world[parents[i]] * Transform2D(a, joints[i] - joints[parents[i]])
		world.append(w)
		skin.append(w * Transform2D(0.0, joints[i]).affine_inverse())
	var out := PackedVector2Array()
	out.resize(rest.size())
	for vi in rest.size():
		var p: Vector2 = rest[vi]
		var acc := Vector2.ZERO
		for k in 3:
			var wt: float = ww[vi * 3 + k]
			if wt > 0.001:
				var m: Transform2D = skin[wi[vi * 3 + k]]
				acc += (m * p) * wt
		out[vi] = acc
	poly.polygon = out

## Stand the puppet so its feet are at `floor_pt` (world) and its leading edge faces `dir`.
func place(foot_world: Vector2, s: float, dir: int) -> void:
	scale = Vector2(s * dir, s)
	position = foot_world - Vector2(foot.x * s * dir, foot.y * s)

func front_offset(s: float) -> float:
	# distance from the foot point to the leading edge, in world px
	return (front - foot.x) * s

func back_offset(s: float) -> float:
	return foot.x * s
