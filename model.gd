class_name Model

## 2d bool array
var wave: Array[Array]
## 3d int array
var propagator: Array[Array]
## 3d int array
var compatible: Array[Array]
var observed: Array[int]

var stack: Array[Array]
var stack_size: int
var observed_so_far: int

var width: int
var height: int
var T: int
var N: int

var periodic: bool
var ground: bool

var weights: Array[float]
var weight_log_weights: Array[float]
var distribution: Array[float]

var ones_sum: Array[int]
var weight_sum: float
var weight_log_sum: float
var starting_entropy: float
var weight_sums: Array[float]
var weight_log_sums: Array[float]
var entropies: Array[float]

static var dx: Array[int] = [-1, 0, 1, 0]
static var dy: Array[int] = [0, 1, 0, -1]
static var opposite: Array[int] = [2, 3, 0, 1]

enum Heuristic {
	Entropy,
	MRV,
	Scanline,
}
var heuristic: Heuristic

func _init(width_: int, height_: int, N_: int, periodic_: bool, heuristic_: Heuristic):
	self.width = width_
	self.height = height_
	self.N = N_
	self.periodic = periodic_
	self.heuristic = heuristic_

func setup() -> void:
	wave = []
	wave.resize(width * height)
	compatible = []
	compatible.resize(wave.size())
	for i in range(wave.size()):
		wave[i] = Array([], TYPE_BOOL, "", null)
		wave[i].resize(T)
		compatible[i] = []
		compatible[i].resize(T)
		for t in range(T):
			compatible[i][t] = Array([], TYPE_INT, "", null)
			compatible[i][t].resize(4)
	distribution = []
	distribution.resize(T)
	observed = []
	observed.resize(width * height)

	weight_log_weights = []
	weight_log_weights.resize(T)
	weight_sum = 0.0
	weight_log_sum = 0.0

	for t in range(T):
		weight_log_weights[t] = weights[t] * log(weights[t])
		weight_sum += weights[t]
		weight_log_sum += weight_log_weights[t]
	
	starting_entropy = log(weight_sum) - weight_log_sum / weight_sum

	ones_sum = []
	ones_sum.resize(width * height)
	weight_sums = []
	weight_sums.resize(width * height)
	weight_log_sums = []
	weight_log_sums.resize(width * height)
	entropies = []
	entropies.resize(width * height)

	stack = []
	stack.resize(height * width * T)
	for i in range(stack.size()):
		stack[i] = Array([], TYPE_INT, "", null)
		stack[i].resize(2)
	stack_size = 0;

func run(seed_: int, limit: int) -> bool:
	if not wave:
		self.setup()

	count_wave()
	self.clear()
	count_wave()
	var random = RandomNumberGenerator.new()
	random.seed = seed_

	var l := 0
	while l < limit or limit < 0:
		var node = self.next_unobserved_node(random)
		if node >= 0:
			self.observe(node, random)
			var success := propagate()
			if not success:
				return false
		else:
			for i in wave.size():
				for t in T:
					if wave[i][t]:
						observed[i] = t
						break
			return true
		l += 1
	
	return true

func next_unobserved_node(random: RandomNumberGenerator) -> int:
	if heuristic == Heuristic.Scanline:
		for i in range(observed_so_far, wave.size()):
			if (not periodic and (i % width + N > width or i / width + N > height)):
				continue
			if ones_sum[i] > 1:
				observed_so_far = i + 1
				return i

		return -1

	var min_entropy: float = 1E+4
	var argmin := -1
	for i in wave.size():
		if not periodic and (i % width + N > width or i / width + N > height):
			continue

		var remaining_values := ones_sum[i]
		var entropy := entropies[i] if heuristic == Heuristic.Entropy else float(remaining_values)
		if remaining_values > 1 and entropy <= min_entropy:
			var noise := 1E-6 * random.randf()
			if entropy + noise < min_entropy:
				min_entropy = entropy + noise
				argmin = i
	
	return argmin

func observe(node: int, random: RandomNumberGenerator) -> void:
	var w: Array[bool] = wave[node]
	for t in range(T):
		distribution[t] = weights[t] if w[t] else 0.0
	var r := random_distribution(distribution, random.randf())
	for t in range(T):
		if w[t] != (t == r):
			ban(node, t)

func random_distribution(arr: Array[float], r: float) -> int:
	var sum := 0.0
	for w in arr:
		sum += w
	var threshold := r * sum

	var partial_sum := 0.0
	for i in arr.size():
		partial_sum += arr[i]
		if partial_sum > threshold:
			return i
	
	return 0

func propagate() -> bool:
	while stack_size > 0:
		var pair: Array[int] = Array(stack[stack_size - 1], TYPE_INT, "", null)
		stack_size -= 1
		var i1 := pair[0]
		var t1 := pair[1]

		var x1 := i1 % width
		var y1 := i1 / width

		for d in 4:
			var x2 := x1 + dx[d]
			var y2 := y1 + dy[d]

			if not periodic and (x2 < 0 or y2 < 0 or x2 + N > width or y2 + N > height):
				continue

			if x2 < 0:
				x2 += width
			elif x2 >= width:
				x2 -= width
			if y2 < 0:
				y2 += height
			elif y2 >= height:
				y2 -= height

			var i2 := x2 + y2 * width
			var p: Array[int] = propagator[d][t1]
			var compat := compatible[i2]

			for l in p.size():
				var t2 := p[l]
				var comp: Array[int] = compat[t2]
				comp[d] -= 1
				if comp[d] == 0:
					ban(i2, t2)

	return ones_sum[0] > 0

func ban(node: int, t: int) -> void:
	wave[node][t] = false

	var comp: Array[int] = compatible[node][t]
	for d in 4:
		comp[d] = 0
	stack[stack_size] = [node, t]
	stack_size += 1

	ones_sum[node] -= 1
	weight_sums[node] -= weights[t]
	weight_log_sums[node] -= weight_log_weights[t]

	var sum := weight_sums[node]
	entropies[node] = log(sum) - weight_log_sums[node] / sum

func count_wave():
	var truec := 0
	var falsec := 0
	for x in wave:
		for y in x:
			if y:
				truec += 1
			else:
				falsec += 1

	print("count_wave: true: %d false %d " % [truec, falsec])

func clear() -> void:
	for i in wave.size():
		for t in T:
			wave[i][t] = true
			for d in 4:
				compatible[i][t][d] = propagator[opposite[d]][t].size()

		ones_sum[i] = weights.size()
		weight_sums[i] = weight_sum
		weight_log_sums[i] = weight_log_sum
		entropies[i] = starting_entropy
		observed[i] = -1

	observed_so_far = 0

	if ground:
		for x in width:
			for t in (T-1):
				ban(x + (height - 1) * width, t)
			for y in (height-1):
				ban(x + y * width, T - 1)
		propagate()

func image() -> Image:
	push_error("Model class mush implement image()")
	return null
