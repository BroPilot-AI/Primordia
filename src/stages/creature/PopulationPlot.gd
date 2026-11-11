class_name PopulationPlot extends Control
@export var buffer_capacity: int = 120

var data_buffer: Array[Dictionary] = []
var population_count: int = 0

func _ready() -> void:
	pass

func push_generation(min_fit: float, avg_fit: float, max_fit: float) -> void:
	# Sanitize inputs
	var sanitized_min := min_fit
	var sanitized_avg := avg_fit
	var sanitized_max := max_fit
	
	if is_nan(sanitized_min) or is_inf(sanitized_min):
		sanitized_min = 0.0
	if is_nan(sanitized_avg) or is_inf(sanitized_avg):
		sanitized_avg = 0.0
	if is_nan(sanitized_max) or is_inf(sanitized_max):
		sanitized_max = 0.0
	
	data_buffer.append({
		"min": sanitized_min,
		"avg": sanitized_avg,
		"max": sanitized_max
	})
	
	# Cap the buffer size
	if data_buffer.size() > buffer_capacity:
		data_buffer.remove_at(0)
	
	queue_redraw()

func set_population(count: int) -> void:
	population_count = count
	queue_redraw()

func _draw() -> void:
	var graph_rect := Rect2(Vector2.ZERO, Vector2(240, 120))
	draw_rect(graph_rect, Color(0.1, 0.1, 0.1))
	
	# Draw title
	draw_string(get_theme_font("font", "Label"), Vector2(10, 20), "Competitor fitness", HORIZONTAL_ALIGNMENT_LEFT)
	
	# Draw population count
	draw_string(get_theme_font("font", "Label"), Vector2(10, 40), "Population: %d" % population_count, HORIZONTAL_ALIGNMENT_LEFT)
	
	if data_buffer.size() == 0:
		draw_string(get_theme_font("font", "Label"), Vector2(10, 60), "No data", HORIZONTAL_ALIGNMENT_LEFT)
		return
	
	# Find min and max values for scaling
	var min_val: float = INF
	var max_val: float = -INF
	
	for sample: Dictionary in data_buffer:
		min_val = minf(min_val, float(sample.get("min", 0.0)))
		min_val = minf(min_val, float(sample.get("avg", 0.0)))
		min_val = minf(min_val, float(sample.get("max", 0.0)))
		max_val = maxf(max_val, float(sample.get("min", 0.0)))
		max_val = maxf(max_val, float(sample.get("avg", 0.0)))
		max_val = maxf(max_val, float(sample.get("max", 0.0)))
	
	# Handle case where all values are the same
	if min_val == max_val:
		max_val = min_val + 1.0
	
	var range_val: float = max_val - min_val
	
	# Draw lines for each data series
	for i in range(data_buffer.size()):
		var sample: Dictionary = data_buffer[i]
		
		# Calculate normalized positions (0 to 1)
		var x: float = float(i) / (data_buffer.size() - 1) if data_buffer.size() > 1 else 0.0
		x = lerpf(0.0, graph_rect.size.x, x)
		
		# Normalize y values
		var min_y: float = lerpf(graph_rect.size.y, 0.0, (float(sample.get("min", 0.0)) - min_val) / range_val)
		var avg_y: float = lerpf(graph_rect.size.y, 0.0, (float(sample.get("avg", 0.0)) - min_val) / range_val)
		var max_y: float = lerpf(graph_rect.size.y, 0.0, (float(sample.get("max", 0.0)) - min_val) / range_val)
		
		# Draw lines
		if i > 0:
			var prev_sample: Dictionary = data_buffer[i - 1]
			
			var prev_x: float = float(i - 1) / (data_buffer.size() - 1) if data_buffer.size() > 1 else 0.0
			prev_x = lerpf(0.0, graph_rect.size.x, prev_x)
			
			var prev_min_y: float = lerpf(graph_rect.size.y, 0.0, (float(prev_sample.get("min", 0.0)) - min_val) / range_val)
			var prev_avg_y: float = lerpf(graph_rect.size.y, 0.0, (float(prev_sample.get("avg", 0.0)) - min_val) / range_val)
			var prev_max_y: float = lerpf(graph_rect.size.y, 0.0, (float(prev_sample.get("max", 0.0)) - min_val) / range_val)
			
			# Min line (faint)
			draw_line(Vector2(prev_x, prev_min_y), Vector2(x, min_y), Color(0.5, 0.5, 0.5), 1)
			
			# Avg line (medium)
			draw_line(Vector2(prev_x, prev_avg_y), Vector2(x, avg_y), Color(0.8, 0.8, 0.8), 1)
			
			# Max line (bright)
			draw_line(Vector2(prev_x, prev_max_y), Vector2(x, max_y), Color(1.0, 1.0, 1.0), 1)
