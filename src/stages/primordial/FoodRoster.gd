class_name FoodRoster extends RefCounted
## Microbe-stage food roster, keyed by lineage biome (Genome.branch_name() → LINEAGES). Per food:
## id, display_name, type (EDIBLE / HAZARD), nutrition (EDIBLE > 0 adds evolution progress;
## HAZARD < 0 SETS IT BACK), nudges (genome axes), tint (color the genome drifts toward).
## 4 foods per biome (3 edible + 1 hazard).

const FOOD_DATA: Dictionary = {
	"freshwater": [
		{
			"id": "green_algae",
			"display_name": "Green Algae",
			"type": "EDIBLE",
			"nutrition": 0.3,
			"nudges": {"size": 0.05, "carnivory": -0.1, "locomotion": -0.02, "defense": 0.0, "senses": 0.02},
			"tint": Color(0.2, 0.8, 0.2)
		},
		{
			"id": "protozoa_larva",
			"display_name": "Protozoa Larva",
			"type": "EDIBLE",
			"nutrition": 0.5,
			"nudges": {"size": -0.02, "carnivory": 0.15, "locomotion": 0.05, "defense": -0.05, "senses": 0.05},
			"tint": Color(0.7, 0.7, 0.3)
		},
		{
			"id": "pond_detritus",
			"display_name": "Pond Detritus",
			"type": "EDIBLE",
			"nutrition": 0.1,
			"nudges": {"size": 0.1, "carnivory": -0.05, "locomotion": -0.05, "defense": 0.05, "senses": -0.05},
			"tint": Color(0.3, 0.2, 0.1)
		},
		{
			"id": "freshwater_toxin",
			"display_name": "Algal Bloom Toxin",
			"type": "HAZARD",
			"nutrition": -0.4,
			"nudges": {"size": -0.1, "carnivory": 0.0, "locomotion": -0.1, "defense": -0.1, "senses": -0.1},
			"tint": Color(0.5, 1.0, 0.5)
		}
	],
	"saltwater": [
		{
			"id": "phytoplankton",
			"display_name": "Phytoplankton",
			"type": "EDIBLE",
			"nutrition": 0.2,
			"nudges": {"size": -0.05, "carnivory": -0.1, "locomotion": 0.05, "defense": 0.0, "senses": 0.05},
			"tint": Color(0.1, 0.9, 0.6)
		},
		{
			"id": "brine_shrimp_egg",
			"display_name": "Brine Shrimp Egg",
			"type": "EDIBLE",
			"nutrition": 0.6,
			"nudges": {"size": 0.08, "carnivory": 0.1, "locomotion": 0.05, "defense": 0.02, "senses": -0.02},
			"tint": Color(0.9, 0.8, 0.7)
		},
		{
			"id": "sea_snail_mucus",
			"display_name": "Snail Mucus",
			"type": "EDIBLE",
			"nutrition": 0.2,
			"nudges": {"size": 0.05, "carnivory": -0.05, "locomotion": -0.1, "defense": 0.15, "senses": -0.05},
			"tint": Color(0.8, 0.8, 0.9)
		},
		{
			"id": "salt_crystal",
			"display_name": "Salt Crystal",
			"type": "HAZARD",
			"nutrition": -0.2,
			"nudges": {"size": 0.1, "carnivory": 0.0, "locomotion": -0.1, "defense": 0.1, "senses": 0.0},
			"tint": Color(1.0, 1.0, 1.0)
		}
	],
	"deep_ocean": [
		{
			"id": "chemosynthetic_bacteria",
			"display_name": "Chemosynthetic Bacteria",
			"type": "EDIBLE",
			"nutrition": 0.4,
			"nudges": {"size": -0.05, "carnivory": -0.1, "locomotion": -0.05, "defense": 0.1, "senses": 0.1},
			"tint": Color(0.2, 0.2, 0.4)
		},
		{
			"id": "marine_snow",
			"display_name": "Marine Snow",
			"type": "EDIBLE",
			"nutrition": 0.15,
			"nudges": {"size": 0.05, "carnivory": -0.05, "locomotion": -0.05, "defense": 0.0, "senses": 0.05},
			"tint": Color(0.9, 0.9, 0.9)
		},
		{
			"id": "zooplankton",
			"display_name": "Zooplankton",
			"type": "EDIBLE",
			"nutrition": 0.45,
			"nudges": {"size": -0.02, "carnivory": 0.08, "locomotion": 0.06, "defense": 0.0, "senses": 0.04},
			"tint": Color(0.6, 0.75, 0.85)
		},
		{
			"id": "hydrothermal_vent_sulfur",
			"display_name": "Vent Sulfur",
			"type": "HAZARD",
			"nutrition": -0.3,
			"nudges": {"size": 0.1, "carnivory": 0.0, "locomotion": -0.1, "defense": 0.1, "senses": -0.1},
			"tint": Color(1.0, 0.5, 0.0)
		}
	],
	"inland": [
		{
			"id": "fungal_spore",
			"display_name": "Fungal Spore",
			"type": "EDIBLE",
			"nutrition": 0.3,
			"nudges": {"size": -0.1, "carnivory": -0.1, "locomotion": -0.05, "defense": 0.1, "senses": 0.05},
			"tint": Color(0.5, 0.4, 0.3)
		},
		{
			"id": "amoeba_fragment",
			"display_name": "Amoeba Fragment",
			"type": "EDIBLE",
			"nutrition": 0.5,
			"nudges": {"size": 0.1, "carnivory": 0.2, "locomotion": -0.1, "defense": 0.0, "senses": 0.05},
			"tint": Color(0.7, 0.7, 0.7)
		},
		{
			"id": "soil_mineral",
			"display_name": "Soil Mineral",
			"type": "EDIBLE",
			"nutrition": 0.1,
			"nudges": {"size": 0.05, "carnivory": -0.05, "locomotion": -0.05, "defense": 0.1, "senses": -0.05},
			"tint": Color(0.4, 0.3, 0.2)
		},
		{
			"id": "earthworm_fluid",
			"display_name": "Earthworm Fluid",
			"type": "HAZARD",
			"nutrition": -0.2,
			"nudges": {"size": -0.05, "carnivory": 0.1, "locomotion": 0.1, "defense": -0.1, "senses": 0.1},
			"tint": Color(0.8, 0.2, 0.2)
		}
	]
}

static func foods_for(biome: String) -> Array:
	return FOOD_DATA.get(biome, [])


# Each biome's apex micro-predator — a SLOW hunter the player must avoid. `id` maps to
# Optional predator_<id>.png override; otherwise SoupHunter draws a biome silhouette. `setback` is how much
# evolution progress a hit costs.
const PREDATORS := {
	"freshwater": {id = "hydra", display_name = "Hydra", tint = Color(0.45, 0.72, 0.55), radius = 34.0, speed = 92.0, setback = 0.12},
	"saltwater": {id = "sea_jelly", display_name = "Sea Jelly", tint = Color(0.82, 0.60, 0.88), radius = 40.0, speed = 80.0, setback = 0.12},
	"deep_ocean": {id = "lurker", display_name = "Anglerfish Lurker", tint = Color(0.16, 0.13, 0.24), radius = 38.0, speed = 86.0, setback = 0.14},
	"inland": {id = "nematode", display_name = "Predatory Nematode", tint = Color(0.86, 0.80, 0.62), radius = 30.0, speed = 104.0, setback = 0.12},
}

static func predator_for(biome: String) -> Dictionary:
	return PREDATORS.get(biome, {})
