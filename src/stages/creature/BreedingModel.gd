class_name BreedingModel


static func cross(parent_a: Dictionary, parent_b: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var child: Dictionary = {}

	for gene_key: Variant in parent_a.keys():
		if not parent_b.has(gene_key):
			continue

		var gene_a: Dictionary = parent_a[gene_key] as Dictionary
		var gene_b: Dictionary = parent_b[gene_key] as Dictionary
		var alleles_a: Array[String] = [String(gene_a["dominant"]), String(gene_a["recessive"])]
		var alleles_b: Array[String] = [String(gene_b["dominant"]), String(gene_b["recessive"])]

		child[gene_key] = {
			"dominant": alleles_a[rng.randi_range(0, 1)],
			"recessive": alleles_b[rng.randi_range(0, 1)],
		}

	return child


static func phenotype(gene: Dictionary) -> String:
	var recessive: String = String(gene["recessive"])

	if gene.has("dominant"):
		var dominant: String = String(gene["dominant"])
		if not dominant.is_empty():
			return dominant

	return recessive


static func punnett(a: Dictionary, b: Dictionary) -> Array:
	var alleles_a: Array[String] = [String(a["dominant"]), String(a["recessive"])]
	var alleles_b: Array[String] = [String(b["dominant"]), String(b["recessive"])]
	var outcomes: Array = []

	for allele_a: String in alleles_a:
		for allele_b: String in alleles_b:
			outcomes.append({
				"dominant": allele_a,
				"recessive": allele_b,
			})

	return outcomes
