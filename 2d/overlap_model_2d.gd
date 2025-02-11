class_name OverlapModel2D extends Model

var patterns: Array[PackedByteArray]
var colors: PackedColorArray
var periodic_input: bool

func _init(name: String, N_: int, width_: int, height_: int, symmetry: int, periodic_: bool, periodic_input_: bool, ground_: bool, heuristic_: Heuristic) -> void:
	super(width_, height_, N_, periodic_, heuristic_)
	self.periodic_input = periodic_input_

	var bitmap := Image.load_from_file("samples/%s" % name)
	if not bitmap:
		push_error("bad bitmappath")
		return
	var SX := bitmap.get_size().x
	var SY := bitmap.get_size().y
	var sample := PackedByteArray()
	sample.resize(SX * SY)
	colors = PackedColorArray()

	for i in range(sample.size()):
		var color := bitmap.get_pixel(i % SX, i / SX)
		var k := 0

		var exists := false
		while k < colors.size():
			if colors[k].is_equal_approx(color):
				exists = true
				break
			k += 1

		if not exists:
			colors.append(color)
		sample[i] = k
	
	patterns = Array([], TYPE_PACKED_BYTE_ARRAY, "", null)
	var pattern_idxs: Dictionary[int, int] = {}

	var xmax = SX if periodic_input else SX - N + 1
	var ymax = SY if periodic_input else SY - N + 1
	var weight_list: Array[float] = []
	for y in ymax:
		for x in xmax:
			var ps: Array[PackedByteArray] = []
			ps.resize(8)

			ps[0] = pattern(func(dx_,dy_)->int: return sample[(x + dx_) % SX + (y + dy_) % SY * SX], N)
			ps[1] = reflect(ps[0], N);
			ps[2] = rotate(ps[0], N);
			ps[3] = reflect(ps[2], N);
			ps[4] = rotate(ps[2], N);
			ps[5] = reflect(ps[4], N);
			ps[6] = rotate(ps[4], N);
			ps[7] = reflect(ps[6], N);

			for k in symmetry:
				var p := ps[k]
				var h := self.hash(p, colors.size())
				var index = pattern_idxs.get(h)
				if index:
					weight_list[index] = weight_list[index] + 1.0
				else:
					pattern_idxs.set(h, weight_list.size())
					weight_list.append(1.0)
					patterns.append(p)
				
	weights = weight_list
	T = weights.size()
	ground = ground_

	propagator = []
	propagator.resize(4)
	for d in 4:
		propagator[d] = []
		propagator[d].resize(T)
		for t in T:
			var l: Array[int] = []
			for t2 in T:
				if agrees(patterns[t], patterns[t2], dx[d], dy[d], N):
					l.append(t2)
			propagator[d][t] = l

static func pattern(f: Callable, size: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(size * size)
	for y in size:
		for x in size:
			result[x + y * size] = f.call(x, y)
	return result

static func rotate(p: PackedByteArray, size: int) -> PackedByteArray:
	return pattern(func(x, y)-> int: return p[size - 1 - y + x * size], size)

static func reflect(p: PackedByteArray, size: int) -> PackedByteArray:
	return pattern(func(x, y)-> int: return p[size - 1 - x + y * size], size)

static func agrees(p1: PackedByteArray, p2: PackedByteArray, dx_: int, dy_: int, N_: int) -> bool:
	var xmin := 0 if dx_ < 0 else dx_
	var xmax := dx_ + N_  if dx_ < 0 else N_
	var ymin := 0 if dy_ < 0 else dy_
	var ymax := dy_ + N_  if dy_ < 0 else N_

	for y in range(ymin, ymax):
		for x in range(xmin, xmax):
			if p1[x + N_ * y] != p2[x - dx_ + N_ * (y - dy_)]:
					return false

	return true

static func hash(p: PackedByteArray, C: int) -> int:
	var result := 0
	var power := 1
	for i in range(p.size()):
		result += p[p.size() - 1 - i] * power
		power *= C
	return result

func image() -> Image:
	var data := PackedByteArray()
	data.resize(width * height * 4)
	var offset := 0
	if observed[0] >= 0:
		for y in height:
			var dy_ := 0 if y < height - N + 1 else N - 1
			for x in width:
				var dx_ := 0 if x < width - N + 1 else N - 1
				var idx := patterns[observed[x - dx_ + (y - dy_) * width]][dx_ + dy_ * N]
				var c := colors[idx]
				data.encode_u32(offset, c.to_abgr32())
				offset += 4
	else:
		for i in wave.size():
			var contributors_ := 0
			var r := 0
			var g := 0
			var b := 0
			var x := i % width
			var y := i / width

			for dy_ in N:
				for dx_ in N:
					var sx := x - dx_
					if sx < 0:
						sx += width
					var sy := y - dy_
					if sy < 0:
						sy += height

					var s := sx + sy * width
					if not periodic and (sx + N > width or sy + N + height or sx < 0 or sy < 0):
						continue
					for t in T:
						if wave[s][t]:
							contributors_ += 1
							var argb := colors[patterns[t][dx_ + dy_ * N]]
							r += argb.r8
							g += argb.g8
							b += argb.b8

			# todo sometimes contributors_ is 0 ??
			if contributors_ == 0:
				contributors_ = 1
			var pixel := 0xff000000 | ((r / contributors_) << 16) | ((g / contributors_) << 8) | b / contributors_;
			data.encode_u32(offset, pixel)
			offset += 4

	return Image.create_from_data(width, height, false, Image.FORMAT_RGBA8, data)
