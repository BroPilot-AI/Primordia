## The "NFT-style" genome expression in 3D — decorates a species avatar with low-poly parts
## driven by the genome axes, so what you ate/did in the microbe stage visibly shapes your creature
## and carries onto your people/units. Parts come from TRELLIS-generated GLBs in
## res://assets/models/generated/creature_features/ (neutral grey on disk; tinted + made
## semi-translucent at runtime by the engine). If a part's GLB is missing we fall back to a
## faceted low-poly primitive (radial_segments 4-6) so the system never breaks and still reads as
## cohesive flat-shaded art alongside the Kenney/Quaternius kits.
##
## Genome axes → parts (counts/placement scale with the axis values and `intensity`):
##   carnivory → FANG row at the mouth + a forward CLAW (+ TUSKS at high carnivory & size)
##   defense   → curved brow HORNS + dorsal BACK_SPIKE ridge (+ ARMOR_PLATE scatter, TAIL_BARB)
##   senses    → EYE_STALKS at the head
##   locomotion→ side FINS + back FRILL (translucent, aquatic-leaning)
##   size      → overall bulk
##
## Usage: GenomeFeatures3D.apply(model_node, genome, species, intensity). Lower `intensity` for
## background units (tribe band, civ soldiers). Placement uses the avatar AABB + a per-species
## anchor table. Tint is applied as a runtime material override so swapping GLBs needs no re-bake.
class_name GenomeFeatures3D

# --- Anchor table: fractions inside the avatar AABB (0..1) for the head-top, mouth, back ridge,
# mid-body (for fins/armor), and tail tip. brow=true means the head silhouette has a forehead
# (humanoid) so brow horns read; false routes them slightly different (snouted bodies).
#
# Per-species overrides: brow_y / brow_x / brow_z (forehead horn root — only honored when
# brow=true), fang_spacing (fang row X extent as fraction of the clamped body half-width), stalk_x
# (eye-stalk base X as fraction of body half-width), back_z (dorsal-spike Z as fraction of body depth,
# default lerps back→center
# like the original; human uses a fixed back-of-body Z so the row sits along the spine).
#
# Human (Kenney character-male-a) was retuned 2026-06-07 (FIX-GENOME-FEATURES-HUMAN). Measured
# local AABB pos=(-0.38,0,-0.17) size=(0.77,0.67,0.34) → body-mesh
# y=0.00-0.37 (frac 0.00-0.55), head-mesh y=0.34-0.67 (frac 0.51-1.00). Old fractions (head_y
# 0.96 / mouth_y 0.72 / back_y 0.74) landed at the crown, chin, and neck — wrong landmarks for a
# humanoid silhouette. New fractions target the forehead (0.85), lower-face mouth (0.68), shoulder
# spine-top (0.50), ribcage (0.28), pelvis (0.12).
# Tuned for TRELLIS + Mixamo species_rigged meshes (and AABB fallback when bones missing).
# Humanoid rows keep parts small/iconic; snouted rows keep creature bulk.
const ANCHORS := {
	"human":       {head_y = 0.93, mouth_y = 0.78, mouth_z = 0.62, back_y = 0.58, body_y = 0.40, tail_y = 0.14, tail_z = 0.08, brow = true,  x_half = 0.22, z_half = 0.20, brow_y = 0.88, brow_x = 0.28, brow_z = 0.22, fang_spacing = 0.18, fang_count_mult = 0.55, tusk_size_mult = 0.55, horn_size_mult = 0.48, stalk_x = 0.20, stalk_size_mult = 0.65, back_z = -0.55, spike_size_mult = 0.70, spike_row_len = 0.14, plate_size_mult = 0.70, barb_size_mult = 0.65, fin_x = 0.42},
	"tall_grey":   {head_y = 0.95, mouth_y = 0.76, mouth_z = 0.58, back_y = 0.60, body_y = 0.42, tail_y = 0.10, tail_z = 0.08, brow = true,  x_half = 0.20, z_half = 0.18, brow_y = 0.90, brow_x = 0.22, brow_z = 0.20, fang_spacing = 0.16, fang_count_mult = 0.60, horn_size_mult = 0.48, stalk_x = 0.18, stalk_size_mult = 0.70, back_z = -0.48, spike_size_mult = 0.72, spike_row_len = 0.12, plate_size_mult = 0.75, barb_size_mult = 0.70, fin_x = 0.48},
	"short_alien": {head_y = 0.90, mouth_y = 0.70, mouth_z = 0.64, back_y = 0.56, body_y = 0.40, tail_y = 0.12, tail_z = 0.08, brow = true,  x_half = 0.26, z_half = 0.22, brow_y = 0.84, brow_x = 0.30, brow_z = 0.24, fang_spacing = 0.20, fang_count_mult = 0.70, horn_size_mult = 0.55, stalk_x = 0.22, stalk_size_mult = 0.68, back_z = -0.45, spike_size_mult = 0.72, spike_row_len = 0.14, plate_size_mult = 0.78, barb_size_mult = 0.75, fin_x = 0.52},
	"reptilian":   {head_y = 0.88, mouth_y = 0.62, mouth_z = 0.88, back_y = 0.62, body_y = 0.44, tail_y = 0.14, tail_z = 0.04, brow = false, x_half = 0.30, z_half = 0.26, fang_spacing = 0.28, fang_count_mult = 0.90, horn_size_mult = 0.72, stalk_x = 0.26, stalk_size_mult = 0.74, back_z = -0.36, spike_size_mult = 0.82, spike_row_len = 0.18, plate_size_mult = 0.88, barb_size_mult = 0.88, fin_x = 0.58},
	"hydra":       {head_y = 0.80, mouth_y = 0.54, mouth_z = 0.82, back_y = 0.66, body_y = 0.48, tail_y = 0.18, tail_z = 0.06, brow = false, x_half = 0.40, z_half = 0.34, fang_spacing = 0.24, fang_count_mult = 0.75, horn_size_mult = 0.62, stalk_x = 0.22, stalk_size_mult = 0.70, back_z = -0.32, spike_size_mult = 0.68, spike_row_len = 0.18, plate_size_mult = 0.72, barb_size_mult = 0.68, fin_x = 0.56},
}
const DEFAULT_ANCHOR := {head_y = 0.9, mouth_y = 0.72, mouth_z = 0.65, back_y = 0.58, body_y = 0.42, tail_y = 0.12, tail_z = 0.06, brow = true, x_half = 0.28, z_half = 0.24}

## Mixamo / common bone aliases for landmark snapping (priority order).
const _BONE_HEAD := ["mixamorig:Head", "mixamorig_Head", "Head", "head", "HeadTop_End", "mixamorig:HeadTop_End"]
const _BONE_NECK := ["mixamorig:Neck", "mixamorig_Neck", "Neck", "neck"]
const _BONE_SPINE := ["mixamorig:Spine2", "mixamorig_Spine2", "Spine2", "spine.002", "mixamorig:Spine1", "Spine1", "Spine", "spine"]
const _BONE_HIPS := ["mixamorig:Hips", "mixamorig_Hips", "Hips", "hips", "Pelvis", "pelvis"]

# Generated-part GLB root + per-part filenames (stem keys match the on-disk filenames).
const _GLB_ROOT: String = "res://assets/models/generated/creature_features/%s.glb"
const _PART_FANG: String = "fang"
const _PART_HORN: String = "horn"
const _PART_BACK_SPIKE: String = "back_spike"
const _PART_CLAW: String = "claw"
const _PART_TUSK: String = "tusk"
const _PART_FIN: String = "fin"
const _PART_FRILL: String = "frill"
const _PART_EYE_STALK: String = "eye_stalk"
const _PART_ARMOR_PLATE: String = "armor_plate"
const _PART_TAIL_BARB: String = "tail_barb"

# Runtime material override: parts are neutral grey on disk; the engine paints them in the species
# tint at the requested alpha so they read as organic. Three material families:
#   BONE   — fangs/horns/tusks/claws/back_spikes/armor_plates/tail_barbs: nearly opaque, just
#            enough translucency to feel organic (ghostly/see-through was the v1 problem).
#   EYE    — eye stalk: fully opaque fleshy stalk + the existing emissive eye bulb.
#   MEM    — fins/frills: genuinely translucent webbing (clearly see-through at edges).
const _ALPHA_BONE: float = 1.0   # OPAQUE — 0.92 read as ghostly washed-out "white nothings" in play
const _ALPHA_EYE_STALK: float = 1.0
const _ALPHA_AQUATIC: float = 0.52
# The TRELLIS-generated part GLBs render pale/inconsistent (washed-out bases, leafy shapes, the
# "white nothings" problem) and the runtime tint doesn't land uniformly on them. The hand-built
# faceted primitives (_horn/_spike/_fang/…) are clean, uniformly tinted, and read as cohesive
# flat-shaded art. Keep them as the source of truth until the generated parts are regenerated clean.
const _USE_GENERATED_GLBS: bool = false
# Runtime part-gluing is ON for the Creature-stage genome read. The AABB guard below prevents the
# old Quaternius 100x-armature scale trap, while the per-species anchor spans keep primitive parts
# on the actual head/spine instead of the widest arm/tentacle bounds.
const _RUNTIME_PARTS: bool = true


static func apply(root: Node3D, genome, species: String = "", intensity: float = 1.0) -> void:
	if root == null or genome == null:
		return
	var a: Dictionary = ANCHORS.get(species, DEFAULT_ANCHOR)
	# Humanoid species still use the same genome axes, but with per-species count/size multipliers
	# so features read as small iconic attachments instead of a clustered costume.
	var humanoid: bool = bool(a.get("brow", false))
	var box: AABB = _local_aabb(root)
	# Sanitize the Quaternius 100x-armature rig-scale trap (the documented cause of the morph hang):
	# an implausible height means _local_aabb caught the un-normalized armature, so the procedural
	# parts would balloon ~100x and freeze. Fall back to a unit box → parts stay sane. This is what
	# lets _RUNTIME_PARTS be re-enabled safely on the rigged models. [[reference_rigged_glb_scale]]
	if box.size == Vector3.ZERO or box.size.y > 4.0 or box.size.y < 0.05:
		box = AABB(Vector3(-0.5, 0, -0.5), Vector3(1, 1, 1))
	# Prefer Skeleton3D bone landmarks when present (Mixamo / TRELLIS-rigged species) so parts
	# sit on forehead/mouth/spine instead of floating at bad mesh AABBs.
	var lm: Dictionary = _bone_landmarks(root, box, a)
	var u: float = float(lm["u"])
	var halfx: float = float(lm["halfx"])
	var halfz: float = float(lm["halfz"])
	var cx: float = float(lm["cx"])
	var cz: float = float(lm["cz"])
	var y0: float = float(lm["y0"])
	var head_y: float = float(lm["head_y"])
	var mouth_y: float = float(lm["mouth_y"])
	var mouth_z: float = float(lm["mouth_z"])
	var back_y: float = float(lm["back_y"])
	var body_y: float = float(lm["body_y"])
	var tail_y: float = float(lm["tail_y"])
	var tail_z: float = float(lm["tail_z"])
	var brow_y: float = float(lm["brow_y"])
	var brow_x: float = float(a.get("brow_x", 0.40))
	var brow_z_off: float = float(a.get("brow_z", 0.32))
	var fang_spacing: float = float(a.get("fang_spacing", 0.32))
	var fang_count_mult: float = float(a.get("fang_count_mult", 1.0))
	var stalk_x_off: float = float(a.get("stalk_x", 0.42))
	var stalk_size_mult: float = float(a.get("stalk_size_mult", 1.0))
	var back_z_off: float = float(a.get("back_z", -999.0))  # sentinel → keep the original back→center lerp
	var has_fixed_back_z: bool = back_z_off > -900.0
	var spike_size_mult: float = float(a.get("spike_size_mult", 1.0))
	var spike_row_len: float = float(a.get("spike_row_len", 0.10))
	var plate_size_mult: float = float(a.get("plate_size_mult", 1.0))
	var barb_size_mult: float = float(a.get("barb_size_mult", 1.0))
	var fin_x_off: float = float(a.get("fin_x", 0.62))
	var horn_size_mult: float = float(a.get("horn_size_mult", 1.0))
	var tusk_size_mult: float = float(a.get("tusk_size_mult", 1.0))
	# When bone landmarks exist, snap mouth Z slightly forward of head and back Z behind spine.
	if bool(lm.get("from_bones", false)):
		mouth_z = float(lm["mouth_z"])
		has_fixed_back_z = true
		back_z_off = float(lm["back_z_norm"])
	var tint: Color = genome.color if genome.color != null else Color(0.72, 0.74, 0.68)
	# Bone/ivory base → strong species tint. The "hint of bone" comes from a DARK muted base
	# (0.65/0.65/0.60) not a bright ivory — a bright base at lerp 0.72 still reads pale sage because
	# the base color overwhelms the tint. v1 lerp was 0.25 with bright base → near-white "mustache".
	var bone: Color = Color(0.65, 0.65, 0.60).lerp(tint, 0.72)
	var ivory: Color = Color(0.72, 0.72, 0.66).lerp(tint, 0.72)

	# diet → COLOR: subtly shift the body's natural palette toward the genome pigment (what you ate
	# follows you onto every later form), keeping the model's own variation.
	_tint_body(root, tint, 0.28)

	# size → bulk
	root.scale *= Vector3.ONE * (0.9 + clampf(genome.size, 0.0, 1.0) * 0.35)

	# Runtime feature parts can still be disabled for emergency perf/debug builds; the default path
	# uses them so the creature silhouette carries the evolved genome axes.
	if not _RUNTIME_PARTS:
		return

	# ---- defense → horns + back spikes + armor plates + tail barb -------------------------------
	if genome.defense > 0.30:
		var hd: float = clampf(genome.defense, 0.0, 1.0)
		# Horns (pair, swept back from the brow). Kept short: a brow accent, not rabbit ears.
		# FIX-GENOME-FEATURES-HUMAN: humanoid species (brow=true + a.brow_y set) route the horn root
		# to the FOREAD via brow_y/brow_x/brow_z; snouted species fall through to the original
		# head_y-anchored placement.
		var horn_len: float = (0.08 + hd * 0.10) * u * horn_size_mult
		var use_brow_anchor: bool = bool(a.get("brow", false)) and a.has("brow_y")
		for s in [-1.0, 1.0]:
			var horn: Node3D = _try_glb_part(_PART_HORN, horn_len, bone, _ALPHA_BONE)
			if horn == null:
				horn = _spike(horn_len, horn_len * 0.20, bone)   # straight faceted horn — no curl-direction ambiguity
			if use_brow_anchor:
				horn.position = Vector3(cx + s * halfx * brow_x, brow_y, cz + halfz * brow_z_off)
			else:
				horn.position = Vector3(cx + s * halfx * 0.40, head_y - 0.04 * u, cz + halfz * 0.32)
			horn.rotation_degrees = Vector3(28.0, s * 16.0, 0.0)   # up + back (positive X = back) + symmetric yaw splay
			root.add_child(horn)
		# Dorsal spike ridge. Moderate trim — kept tall enough to read as a dorsal threat display.
		# FIX-GENOME-FEATURES-HUMAN: species with back_z set use a fixed back-of-body Z (spine line)
		# so the row sits along the spine; the default lerp from back→center stays for the long-bodied
		# Quaternius species where the spike row tapers along the body length. spike_size_mult lets
		# per-species overrides (e.g. human) boost the ridge to read against a narrower silhouette.
		var spikes: int = int(round(maxf(0.0, hd - 0.25) * 5.0 * intensity))
		for i in spikes:
			var t: float = 0.5 if spikes == 1 else float(i) / float(spikes - 1)
			var spike_h: float = (0.045 + hd * 0.065) * u * spike_size_mult
			var sp: Node3D = _try_glb_part(_PART_BACK_SPIKE, spike_h, bone, _ALPHA_BONE)
			if sp == null:
				sp = _spike(spike_h, spike_h * 0.24, bone)
			var sp_z: float = cz + halfz * back_z_off if has_fixed_back_z else lerpf(cz - halfz * 0.5, cz, t)
			sp.position = Vector3(cx, back_y - box.size.y * spike_row_len * t, sp_z)
			sp.rotation_degrees = Vector3(-22.0, 0, 0)
			root.add_child(sp)
		# Armor plates: scatter along body flanks; lateral pairs alternate sides. Reduced + flatter
		# so plates hug the silhouette instead of standing off the body like bricks.
		if hd > 0.55 and not humanoid:
			var plates: int = int(round((hd - 0.5) * 6.0 * intensity))
			for i in plates:
				var pt: float = float(i) / maxf(1.0, float(plates))
				var side: float = -1.0 if (i % 2) == 0 else 1.0
				var plate_size: float = (0.055 + hd * 0.055) * u * plate_size_mult
				var plate: Node3D = _try_glb_part(_PART_ARMOR_PLATE, plate_size, bone, _ALPHA_BONE)
				if plate == null:
					plate = _armor_plate_fallback(plate_size, bone)
				plate.position = Vector3(
					cx + side * halfx * 0.56,
					body_y + box.size.y * 0.10 * (pt - 0.5),
					lerpf(cz - halfz * 0.35, cz + halfz * 0.20, pt)
				)
				plate.rotation_degrees = Vector3(0.0, side * 90.0, side * 10.0)
				root.add_child(plate)
		# Tail barb: single piece at the tail tip, swept up-back. Moderate trim to keep it
		# proportionate to the body length rather than a flag-pole.
		if hd > 0.65 and not humanoid:
			var barb_h: float = (0.055 + hd * 0.06) * u * barb_size_mult
			var barb: Node3D = _try_glb_part(_PART_TAIL_BARB, barb_h, bone, _ALPHA_BONE)
			if barb == null:
				barb = _spike(barb_h, barb_h * 0.24, bone)
			barb.position = Vector3(cx, tail_y, tail_z)
			barb.rotation_degrees = Vector3(-110.0, 0.0, 0.0)
			root.add_child(barb)

	# ---- carnivory → fangs + claw + tusks ------------------------------------------------------
	if genome.carnivory > 0.45:   # low carnivory stays clean; medium/high carnivores visibly grow teeth
		var cn: float = clampf(genome.carnivory, 0.0, 1.0)
		# Fang row across the mouth. Moderate trim — fangs should be menacing but not a comb.
		# Spacing uses the clamped head/body width so adjacent teeth read as distinct rather than
		# a single fused fang-plate. FIX-GENOME-FEATURES-HUMAN: per-species fang_spacing + fang_count
		# overrides — the default 0.32 spans ±52% of the head (too wide for a human mouth) and the
		# default 4-fang count reads as a comb on the narrower human face.
		var fangs: int = int(round((1.0 + maxf(0.0, cn - 0.45) * 5.0 * intensity) * fang_count_mult))
		for i in fangs:
			var ft: float = 0.5 if fangs == 1 else float(i) / float(fangs - 1)
			var fx: float = lerpf(-halfx * fang_spacing, halfx * fang_spacing, ft)
			var fang_h: float = (0.032 + cn * 0.045) * u
			var fang: Node3D = _try_glb_part(_PART_FANG, fang_h, ivory, _ALPHA_BONE)
			if fang == null:
				fang = _fang(fang_h, ivory)
			fang.position = Vector3(cx + fx, mouth_y - fang_h * 0.20, mouth_z)
			fang.rotation_degrees = Vector3(180.0, 0.0, 0.0)
			root.add_child(fang)
		# Forward claw — single piece, swept forward from the chest. Moderate trim.
		# FIX-GENOME-FEATURES-HUMAN: was y0 + 0.04*u (feet level — wrong for all species, the
		# comment says "from the chest"). Move to body_y (mid-torso) so the claw reads as chest-
		# mounted for every species, including the Kenney human.
		if not humanoid:   # a chest-mounted claw reads odd on an upright human — creatures only
			var claw_h: float = (0.045 + cn * 0.045) * u
			var claw: Node3D = _try_glb_part(_PART_CLAW, claw_h, bone, _ALPHA_BONE)
			if claw == null:
				claw = _spike(claw_h, claw_h * 0.25, bone)
			claw.position = Vector3(cx, body_y, mouth_z)
			claw.rotation_degrees = Vector3(140.0, 0.0, 0.0)
			root.add_child(claw)
		# Tusks: pair, only for big carnivores (high carnivory AND high size). ~30% trim — was
		# tusk-poles, now reads as mouth-framing.
		if cn > 0.70 and genome.size > 0.50 and not humanoid:
			var tusk_h: float = (0.055 + cn * 0.055) * u * (0.85 + genome.size * 0.35) * tusk_size_mult
			for s in [-1.0, 1.0]:
				var tusk: Node3D = _try_glb_part(_PART_TUSK, tusk_h, ivory, _ALPHA_BONE)
				if tusk == null:
					tusk = _fang(tusk_h, ivory)
					tusk.scale = Vector3(1.5, 1.0, 1.5)
				tusk.position = Vector3(cx + s * halfx * 0.22, mouth_y - 0.04 * u, mouth_z)
				tusk.rotation_degrees = Vector3(160.0, 0.0, s * 14.0)
				root.add_child(tusk)

	# ---- senses → eye-stalks ------------------------------------------------------------------
	# Stalk is OPAQUE fleshy skin (was v1's translucent look — read as alien cobwebs). Eye bulb
	# stays as the existing emissive _eye(). Stalk length trimmed ~30% so it sits periscope-short
	# above the head rather than telescoping up like a tower.
	if genome.senses > 0.50:   # antenna/eye-stalks appear on strong sensory genomes across all species
		var sn: float = clampf(genome.senses, 0.0, 1.0)
		var stalk_len: float = (0.055 + sn * 0.065) * u * stalk_size_mult
		for s in [-1.0, 1.0]:
			var es: Node3D = _try_glb_part(_PART_EYE_STALK, stalk_len, tint.lightened(0.25), _ALPHA_EYE_STALK)
			if es != null:
				es.position = Vector3(cx + s * halfx * stalk_x_off, head_y + stalk_len * 0.45, cz)
				es.rotation_degrees = Vector3(-10.0, 0.0, s * 26.0)
				root.add_child(es)
			else:
				# Fallback: the original primitive stalk + glowing eye combo.
				# FIX-GENOME-FEATURES-HUMAN: per-species stalk_x override (default 0.34 keeps the
				# original Quaternius placement; the human uses 0.22 so stalks sit on top of the
				# narrower head instead of at the temples).
				var stalk := _stalk(stalk_len, stalk_len * 0.16, tint.lightened(0.25))
				stalk.position = Vector3(cx + s * halfx * stalk_x_off, head_y + stalk_len * 0.45, cz)
				stalk.rotation_degrees = Vector3(-10.0, 0.0, s * 26.0)
				root.add_child(stalk)
				var eye := _eye((0.022 + sn * 0.030) * u, Color(0.2, 0.95, 0.85))
				eye.position = Vector3(cx + s * halfx * (stalk_x_off + 0.08), head_y + stalk_len * 0.95, cz)
				root.add_child(eye)

	# ---- locomotion → side fins + back frill (translucent, aquatic-leaning) -------------------
	# These stay in the genuinely-translucent family (membrane). Sized to read as fins/frill, not
	# sails — slight trim from v1 so they don't outgrow the body silhouette.
	if genome.locomotion > 0.75 and not humanoid:   # fins/frill only on strong swimmers (was adding to the clutter)
		var lo: float = clampf(genome.locomotion, 0.0, 1.0)
		var fin_size: float = (0.16 + lo * 0.14) * u
		for s in [-1.0, 1.0]:
			var fin: Node3D = _try_glb_part(_PART_FIN, fin_size, tint.lightened(0.10), _ALPHA_AQUATIC)
			if fin == null:
				fin = _fin_fallback(fin_size, tint.lightened(0.10), _ALPHA_AQUATIC)
			fin.position = Vector3(cx + s * halfx * fin_x_off, body_y, cz)
			fin.rotation_degrees = Vector3(0.0, s * 12.0, s * 35.0)
			root.add_child(fin)
		if lo > 0.60:
			var frill_size: float = (0.16 + lo * 0.12) * u
			var frill: Node3D = _try_glb_part(_PART_FRILL, frill_size, tint.lightened(0.18), _ALPHA_AQUATIC)
			if frill == null:
				frill = _frill_fallback(frill_size, tint.lightened(0.18), _ALPHA_AQUATIC)
			frill.position = Vector3(cx, head_y - frill_size * 0.30, cz - halfz * 0.30)
			frill.rotation_degrees = Vector3(-25.0, 0.0, 0.0)
			root.add_child(frill)


# === GLB part loader / fitter / tinter =======================================================
# Load a generated part GLB, scale-fit its Y extent to `target_y` (matches the primitive size the
# part replaces), recenter at its mesh-centroid so anchor placement parity holds, and override the
# materials with the species tint at the requested alpha. Returns null on miss → caller falls back.
static func _try_glb_part(stem: String, target_y: float, col: Color, alpha: float) -> Node3D:
	if not _USE_GENERATED_GLBS:
		return null   # force the clean procedural fallback (generated GLBs render pale/inconsistent)
	var path: String = _GLB_ROOT % stem
	if not ResourceLoader.exists(path):
		return null
	var packed: Resource = load(path)
	if packed == null or not (packed is PackedScene):
		return null
	var inst: Node3D = (packed as PackedScene).instantiate() as Node3D
	if inst == null:
		return null
	_fit_part_y(inst, target_y)
	_tint_part(inst, col, alpha)
	return inst


# Uniform scale so the part's full-chain AABB.size.y matches `target_y`; recenter X/Y/Z so the
# part's mesh centroid sits at the local origin (primitives have origin at center, so anchor maths
# stay valid). Mirrors CampProps._root_aabb / _fit_and_seat ([[rigged_glb_scale]]) — accumulates the
# full mesh→root transform chain, otherwise an intermediate node scale balloons the fit.
static func _fit_part_y(root: Node3D, target_y: float) -> void:
	var box: AABB = _part_aabb(root)
	if box.size.y <= 0.001:
		return
	var f: float = target_y / box.size.y
	root.scale = Vector3.ONE * f
	var cx: float = box.position.x + box.size.x * 0.5
	var cy: float = box.position.y + box.size.y * 0.5
	var cz: float = box.position.z + box.size.z * 0.5
	root.position = Vector3(-cx * f, -cy * f, -cz * f)


# Replace every surface material on every MeshInstance3D under `root` with a tinted, alpha-blended
# StandardMaterial3D — parts are neutral grey on disk, the engine fully paints them at runtime.
# Subtle Fresnel rim gives the bone parts a wet/ivory edge highlight and the membrane parts a
# translucent-webbing read at the silhouette; one param set, no shader cost.
static func _tint_part(root: Node3D, col: Color, alpha: float) -> void:
	var opaque: bool = alpha >= 0.999
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(col.r, col.g, col.b, alpha)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED if opaque else BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.roughness = 0.70
		mat.metallic = 0.0
		mat.rim_enabled = true
		mat.rim_tint = 0.7                          # mostly material color (not white wash)
		mat.rim = 0.40 if opaque else 0.55          # bone: thin wet-ivory edge; membrane: visible webbing rim
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, mat)


# === faceted low-poly part builders (fallbacks when a GLB is missing) ========================
static func _spike(height: float, radius: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = radius
	m.height = height
	m.radial_segments = 5      # faceted pyramid, not a smooth cone
	m.rings = 0
	mi.mesh = m
	mi.material_override = _mat(col)
	return mi


# A curving horn = a short chain of tapering faceted segments, each rotated a little further.
static func _horn(length: float, radius: float, col: Color, curve_deg: float) -> Node3D:
	var root := Node3D.new()
	var segs := 4
	var seg_len: float = length / float(segs)
	var pivot := root
	for i in segs:
		var r0: float = radius * (1.0 - float(i) / float(segs) * 0.7)
		var r1: float = radius * (1.0 - float(i + 1) / float(segs) * 0.7)
		var mi := MeshInstance3D.new()
		var m := CylinderMesh.new()
		m.top_radius = r1
		m.bottom_radius = r0
		m.height = seg_len
		m.radial_segments = 5
		m.rings = 0
		mi.mesh = m
		mi.material_override = _mat(col)
		mi.position = Vector3(0, seg_len * 0.5, 0)
		pivot.add_child(mi)
		var next := Node3D.new()
		next.position = Vector3(0, seg_len, 0)
		next.rotation_degrees = Vector3(curve_deg / float(segs), 0, 0)
		mi.add_child(next)
		pivot = next
	return root


static func _fang(height: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := PrismMesh.new()
	m.size = Vector3(height * 0.3, height, height * 0.3)
	mi.mesh = m
	mi.material_override = _mat(col)
	return mi


static func _stalk(height: float, radius: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = radius
	m.bottom_radius = radius * 1.3
	m.height = height
	m.radial_segments = 5
	m.rings = 0
	mi.mesh = m
	mi.material_override = _mat(col)
	return mi


static func _eye(radius: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 8
	m.rings = 4
	mi.mesh = m
	mi.material_override = _mat(col, true)
	return mi


# Flat carapace plate (broad, thin) — fallback when armor_plate.glb is missing. Was nearly
# cubic in v1 (stood off the body like a brick); now wider-than-tall and very thin so it reads
# as a scute hugging the silhouette.
static func _armor_plate_fallback(size: float, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(size * 1.2, size * 0.45, size * 0.15)
	mi.mesh = m
	mi.material_override = _mat(col)
	return mi


# Thin triangular fin — fallback when fin.glb is missing. Translucent-ready via _mat alpha.
static func _fin_fallback(size: float, col: Color, alpha: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := PrismMesh.new()
	m.size = Vector3(size * 1.2, size, size * 0.06)
	mi.mesh = m
	mi.material_override = _mat_alpha(col, alpha)
	return mi


# Fan-shaped frill — fallback when frill.glb is missing. Wider than a fin, similar thinness.
static func _frill_fallback(size: float, col: Color, alpha: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := PrismMesh.new()
	m.size = Vector3(size * 1.6, size, size * 0.05)
	mi.mesh = m
	mi.material_override = _mat_alpha(col, alpha)
	return mi


static func _mat(col: Color, glow: bool = false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.7
	if glow:
		mat.emission_enabled = true
		mat.emission = col
		mat.emission_energy_multiplier = 1.6
	return mat


static func _mat_alpha(col: Color, alpha: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(col.r, col.g, col.b, alpha)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.65
	return mat


## Blend every body surface's albedo toward the diet color by `amount` (keeps texture/variation).
static func _tint_body(root: Node3D, color: Color, amount: float) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or mi.material_override != null:
			continue   # express() already diet-tinted this skin; its override would hide a surface tint
		for s in mi.mesh.get_surface_count():
			var src: Material = mi.get_active_material(s)
			var m: StandardMaterial3D = (src as StandardMaterial3D).duplicate() if src is StandardMaterial3D else StandardMaterial3D.new()
			m.albedo_color = _readable_body_color(m.albedo_color.lerp(color, amount), color)
			m.emission_enabled = true
			m.emission = m.albedo_color
			m.emission_energy_multiplier = 0.10
			mi.set_surface_override_material(s, m)


static func _readable_body_color(col: Color, tint: Color) -> Color:
	var out := col
	var luma: float = out.r * 0.2126 + out.g * 0.7152 + out.b * 0.0722
	if luma < 0.34:
		var lift: float = clampf((0.34 - luma) / 0.34, 0.0, 1.0) * 0.60
		out = out.lerp(tint.lightened(0.35), lift)
	luma = out.r * 0.2126 + out.g * 0.7152 + out.b * 0.0722
	if luma < 0.30:
		var floor_lift: float = clampf((0.30 - luma) / 0.30, 0.0, 1.0) * 0.45
		out = out.lerp(Color(0.72, 0.72, 0.66, out.a), floor_lift)
	out.a = col.a
	return out


## Resolve placement landmarks. Uses Skeleton3D bones when available (Mixamo names), else AABB fractions.
static func _bone_landmarks(root: Node3D, box: AABB, a: Dictionary) -> Dictionary:
	var u: float = maxf(box.size.y, 0.5)
	var raw_halfx: float = box.size.x * 0.5
	var raw_halfz: float = box.size.z * 0.5
	var halfx: float = minf(raw_halfx, u * float(a.get("x_half", 0.32)))
	var halfz: float = minf(raw_halfz, u * float(a.get("z_half", 0.28)))
	var cx: float = box.position.x + box.size.x * 0.5
	var cz: float = box.position.z + box.size.z * 0.5
	var y0: float = box.position.y
	var z0: float = box.position.z
	var head_y: float = y0 + box.size.y * float(a.get("head_y", 0.9))
	var mouth_y: float = y0 + box.size.y * float(a.get("mouth_y", 0.7))
	var mouth_z: float = z0 + box.size.z * float(a.get("mouth_z", 0.7))
	var back_y: float = y0 + box.size.y * float(a.get("back_y", 0.7))
	var body_y: float = y0 + box.size.y * float(a.get("body_y", 0.45))
	var tail_y: float = y0 + box.size.y * float(a.get("tail_y", 0.10))
	var tail_z: float = z0 + box.size.z * float(a.get("tail_z", 0.05))
	var brow_y: float = y0 + box.size.y * float(a.get("brow_y", float(a.get("head_y", 0.9)) - 0.04))
	var from_bones := false
	var back_z_norm: float = float(a.get("back_z", -0.5))
	var skel: Skeleton3D = _find_skeleton(root)
	if skel != null and root.is_inside_tree():
		var head_p: Vector3 = _bone_local(skel, root, _BONE_HEAD)
		var neck_p: Vector3 = _bone_local(skel, root, _BONE_NECK)
		var spine_p: Vector3 = _bone_local(skel, root, _BONE_SPINE)
		var hips_p: Vector3 = _bone_local(skel, root, _BONE_HIPS)
		if not head_p.is_finite() and neck_p.is_finite():
			head_p = neck_p + Vector3(0, u * 0.08, 0)
		if head_p.is_finite():
			from_bones = true
			cx = head_p.x
			cz = head_p.z
			head_y = head_p.y + u * 0.04
			brow_y = head_p.y + u * 0.01
			mouth_y = head_p.y - u * 0.06
			mouth_z = head_p.z + halfz * 0.55
			halfx = minf(halfx, u * float(a.get("x_half", 0.22)))
			halfz = minf(halfz, u * float(a.get("z_half", 0.20)))
		if spine_p.is_finite():
			from_bones = true
			back_y = spine_p.y
			cz = lerpf(cz, spine_p.z, 0.5)
			back_z_norm = -0.55
		if hips_p.is_finite():
			body_y = lerpf(hips_p.y, spine_p.y if spine_p.is_finite() else hips_p.y + u * 0.15, 0.55)
			tail_y = hips_p.y
			tail_z = hips_p.z - halfz * 0.2
		# Height reference from hips→head when both exist.
		if head_p.is_finite() and hips_p.is_finite():
			u = maxf(u, absf(head_p.y - hips_p.y) * 1.15)
	return {
		"u": u, "halfx": halfx, "halfz": halfz, "cx": cx, "cz": cz, "y0": y0,
		"head_y": head_y, "mouth_y": mouth_y, "mouth_z": mouth_z,
		"back_y": back_y, "body_y": body_y, "tail_y": tail_y, "tail_z": tail_z,
		"brow_y": brow_y, "from_bones": from_bones, "back_z_norm": back_z_norm,
	}


static func _find_skeleton(root: Node3D) -> Skeleton3D:
	for n in root.find_children("*", "Skeleton3D", true, false):
		return n as Skeleton3D
	return null


static func _bone_local(skel: Skeleton3D, root: Node3D, names: Array) -> Vector3:
	for n in names:
		var idx: int = skel.find_bone(str(n))
		if idx < 0:
			continue
		# Bone pose in skeleton space → root local.
		var bone_xf: Transform3D = skel.get_bone_global_pose(idx)
		var world: Transform3D = skel.global_transform * bone_xf
		return root.global_transform.affine_inverse() * world.origin
	return Vector3(INF, INF, INF)


# Host-avatar AABB. Walks the FULL transform chain from each MeshInstance3D up to `root` so any
# scale parked on an intermediate node (common in CC0 rigged GLBs — see [[rigged_glb_scale]]) is
# counted; otherwise the fit silently undersizes and anchors cluster wrongly.
static func _local_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var box: AABB = _local_to_root(mi, root) * mi.mesh.get_aabb()
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out


# Same as _local_aabb but also includes `root` itself if it's a MeshInstance3D (TRELLIS GLB scene
# roots often ARE the mesh, no children).
static func _part_aabb(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if root is MeshInstance3D:
		meshes.append(root)
	for n in meshes:
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var box: AABB = _local_to_root(mi, root) * mi.mesh.get_aabb()
		if first:
			out = box
			first = false
		else:
			out = out.merge(box)
	return out if first == false else AABB(Vector3.ZERO, Vector3.ONE)


static func _local_to_root(node: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node3D = node
	while cur != null and cur != root:
		t = cur.transform * t
		cur = cur.get_parent() as Node3D
	return t
