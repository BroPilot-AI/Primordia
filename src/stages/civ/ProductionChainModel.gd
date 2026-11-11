class_name ProductionChainModel

const RECIPES: Dictionary = {
	"planks": {"inputs": {"wood": 2},                "output": 1, "time": 4.0},
	"ingots": {"inputs": {"ore": 2},                 "output": 1, "time": 6.0},
	"bread":  {"inputs": {"grain": 3},               "output": 1, "time": 3.0},
	"tools":  {"inputs": {"planks": 1, "ingots": 2}, "output": 1, "time": 10.0},
}


static func has_recipe(id: String) -> bool:
	return RECIPES.has(id)


static func can_make(id: String, stock: Dictionary) -> bool:
	if not RECIPES.has(id):
		return false
	var recipe: Dictionary = RECIPES[id]
	var inputs: Dictionary = recipe.get("inputs", {})
	for input_id: String in inputs:
		if int(stock.get(input_id, 0)) < int(inputs[input_id]):
			return false
	return true


static func make(id: String, stock: Dictionary) -> Dictionary:
	var fresh: Dictionary = stock.duplicate(true)
	if not can_make(id, stock):
		return fresh
	var recipe: Dictionary = RECIPES[id]
	var inputs: Dictionary = recipe.get("inputs", {})
	for input_id: String in inputs:
		fresh[input_id] = int(fresh.get(input_id, 0)) - int(inputs[input_id])
	fresh[id] = int(fresh.get(id, 0)) + int(recipe.get("output", 1))
	return fresh


static func throughput(id: String, workers: int, delta: float) -> float:
	if not RECIPES.has(id):
		return 0.0
	if workers <= 0 or delta <= 0.0:
		return 0.0
	var recipe: Dictionary = RECIPES[id]
	var time: float = float(recipe.get("time", 1.0))
	if time <= 0.0:
		return 0.0
	var output: int = int(recipe.get("output", 1))
	return (float(workers) * float(output) * delta) / time
