class_name NeuralBrain
extends RefCounted

## Pure-logic one-hidden-layer neural net for Creature-stage competitor AI.
##
## Intended I/O contract:
## inputs = normalized sensory vector
## [dist_to_food_x, dist_to_food_z, dist_to_predator_x, dist_to_predator_z, hunger]
## outputs = [move_x, move_z] in [-1, 1]
##
## Sizes stay parameterized so tests and later balancing can vary the topology.

var input_size: int = 0
var hidden_size: int = 0
var output_size: int = 0

var _input_hidden_weights: PackedFloat32Array = PackedFloat32Array()
var _hidden_biases: PackedFloat32Array = PackedFloat32Array()
var _hidden_output_weights: PackedFloat32Array = PackedFloat32Array()
var _output_biases: PackedFloat32Array = PackedFloat32Array()


func _init(
	input_size_value: int = 0,
	hidden_size_value: int = 0,
	output_size_value: int = 0,
	input_hidden_weights_value: PackedFloat32Array = PackedFloat32Array(),
	hidden_biases_value: PackedFloat32Array = PackedFloat32Array(),
	hidden_output_weights_value: PackedFloat32Array = PackedFloat32Array(),
	output_biases_value: PackedFloat32Array = PackedFloat32Array()
) -> void:
	input_size = maxi(input_size_value, 0)
	hidden_size = maxi(hidden_size_value, 0)
	output_size = maxi(output_size_value, 0)

	_input_hidden_weights = _normalized_array(input_hidden_weights_value, input_size * hidden_size)
	_hidden_biases = _normalized_array(hidden_biases_value, hidden_size)
	_hidden_output_weights = _normalized_array(hidden_output_weights_value, hidden_size * output_size)
	_output_biases = _normalized_array(output_biases_value, output_size)


static func new_random(
	input_size_value: int,
	hidden_size_value: int,
	output_size_value: int,
	rng: RandomNumberGenerator
) -> NeuralBrain:
	var safe_input_size: int = maxi(input_size_value, 0)
	var safe_hidden_size: int = maxi(hidden_size_value, 0)
	var safe_output_size: int = maxi(output_size_value, 0)

	return new(
		safe_input_size,
		safe_hidden_size,
		safe_output_size,
		_random_array(safe_input_size * safe_hidden_size, rng),
		_random_array(safe_hidden_size, rng),
		_random_array(safe_hidden_size * safe_output_size, rng),
		_random_array(safe_output_size, rng)
	)


func think(inputs: PackedFloat32Array) -> PackedFloat32Array:
	var safe_inputs: PackedFloat32Array = _normalized_inputs(inputs)
	var hidden_values: PackedFloat32Array = PackedFloat32Array()
	hidden_values.resize(hidden_size)

	for hidden_index: int in hidden_size:
		var hidden_sum: float = _hidden_biases[hidden_index]
		for input_index: int in input_size:
			var weight_index: int = hidden_index * input_size + input_index
			hidden_sum += safe_inputs[input_index] * _input_hidden_weights[weight_index]
		hidden_values[hidden_index] = tanh(_sanitize_float(hidden_sum))

	var outputs: PackedFloat32Array = PackedFloat32Array()
	outputs.resize(output_size)
	for output_index: int in output_size:
		var output_sum: float = _output_biases[output_index]
		for hidden_index: int in hidden_size:
			var weight_index: int = output_index * hidden_size + hidden_index
			output_sum += hidden_values[hidden_index] * _hidden_output_weights[weight_index]
		outputs[output_index] = clampf(tanh(_sanitize_float(output_sum)), -1.0, 1.0)

	return outputs


func mutate(rate: float, strength: float, rng: RandomNumberGenerator) -> NeuralBrain:
	var safe_rate: float = clampf(_sanitize_float(rate), 0.0, 1.0)
	var safe_strength: float = absf(_sanitize_float(strength))

	return new(
		input_size,
		hidden_size,
		output_size,
		_mutated_array(_input_hidden_weights, safe_rate, safe_strength, rng),
		_mutated_array(_hidden_biases, safe_rate, safe_strength, rng),
		_mutated_array(_hidden_output_weights, safe_rate, safe_strength, rng),
		_mutated_array(_output_biases, safe_rate, safe_strength, rng)
	)


func to_dict() -> Dictionary:
	return {
		"input_size": input_size,
		"hidden_size": hidden_size,
		"output_size": output_size,
		"input_hidden_weights": _copy_array(_input_hidden_weights),
		"hidden_biases": _copy_array(_hidden_biases),
		"hidden_output_weights": _copy_array(_hidden_output_weights),
		"output_biases": _copy_array(_output_biases),
	}


static func from_dict(d: Dictionary) -> NeuralBrain:
	var loaded_input_size: int = maxi(int(d.get("input_size", 0)), 0)
	var loaded_hidden_size: int = maxi(int(d.get("hidden_size", 0)), 0)
	var loaded_output_size: int = maxi(int(d.get("output_size", 0)), 0)

	return new(
		loaded_input_size,
		loaded_hidden_size,
		loaded_output_size,
		_array_from_variant(d.get("input_hidden_weights", PackedFloat32Array()), loaded_input_size * loaded_hidden_size),
		_array_from_variant(d.get("hidden_biases", PackedFloat32Array()), loaded_hidden_size),
		_array_from_variant(d.get("hidden_output_weights", PackedFloat32Array()), loaded_hidden_size * loaded_output_size),
		_array_from_variant(d.get("output_biases", PackedFloat32Array()), loaded_output_size)
	)


static func _random_array(size: int, rng: RandomNumberGenerator) -> PackedFloat32Array:
	var values: PackedFloat32Array = PackedFloat32Array()
	values.resize(maxi(size, 0))
	for index: int in values.size():
		values[index] = rng.randf_range(-1.0, 1.0)
	return values


static func _mutated_array(
	values: PackedFloat32Array,
	rate: float,
	strength: float,
	rng: RandomNumberGenerator
) -> PackedFloat32Array:
	var result: PackedFloat32Array = _copy_array(values)
	if rate <= 0.0 or strength == 0.0:
		return result

	for index: int in result.size():
		if rng.randf() <= rate:
			var sign: float = 1.0 if rng.randf() >= 0.5 else -1.0
			result[index] = _sanitize_float(result[index] + sign * strength)

	return result


static func _array_from_variant(value: Variant, expected_size: int) -> PackedFloat32Array:
	if value is PackedFloat32Array:
		return _normalized_array(value as PackedFloat32Array, expected_size)
	if value is Array:
		var source: Array = value as Array
		var result: PackedFloat32Array = PackedFloat32Array()
		result.resize(maxi(expected_size, 0))
		var copy_count: int = mini(source.size(), result.size())
		for index: int in copy_count:
			result[index] = _sanitize_float(float(source[index]))
		return result
	return _normalized_array(PackedFloat32Array(), expected_size)


static func _normalized_array(values: PackedFloat32Array, expected_size: int) -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(maxi(expected_size, 0))
	var copy_count: int = mini(values.size(), result.size())
	for index: int in copy_count:
		result[index] = _sanitize_float(values[index])
	return result


func _normalized_inputs(inputs: PackedFloat32Array) -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(input_size)
	var copy_count: int = mini(inputs.size(), input_size)
	for index: int in copy_count:
		result[index] = clampf(_sanitize_float(inputs[index]), -1.0, 1.0)
	return result


static func _copy_array(values: PackedFloat32Array) -> PackedFloat32Array:
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(values.size())
	for index: int in values.size():
		result[index] = values[index]
	return result


static func _sanitize_float(value: float) -> float:
	if is_nan(value) or is_inf(value):
		return 0.0
	return value
