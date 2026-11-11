class_name PlanetName extends RefCounted

static func generate(seed_text: String) -> String:
	var rng = RandomNumberGenerator.new()
	rng.seed = seed_text.hash()
	
	var prefixes = ["Verd", "Kel", "Than", "Yll", "Zor", "Aet", "Bel", "Dra", "Eon", "Gla"]
	var cores = ["axis", "oria", "duon", "on", "is", "ia", "os", "us", "ax", "en"]
	var suffixes = ["Prime", "Minor", "Alpha", "Beta", "Gamma", "VII", "IX", "Prime", "Major"]
	var numeric_suffixes = ["7", "3", "9", "1", "0"]
	
	var name_part = prefixes[rng.randi_range(0, prefixes.size() - 1)] + cores[rng.randi_range(0, cores.size() - 1)]
	
	var roll = rng.randf()
	if roll < 0.3:
		name_part += "-" + numeric_suffixes[rng.randi_range(0, numeric_suffixes.size() - 1)]
	elif roll < 0.6:
		name_part += " " + suffixes[rng.randi_range(0, suffixes.size() - 1)]
	elif roll < 0.8:
		name_part += " " + ["Prime", "Minor"][rng.randi_range(0, 1)]
		
	return name_part
