## Optional per-stage micro-goals (autoload). Stages call `complete(id, toast)` once each —
## pure toast feedback that teaches systems without gating progress. Resets on stage_changed.
extends Node

var _done: Dictionary = {}
var _stage: int = -1


func _ready() -> void:
	Events.stage_changed.connect(_on_stage_changed)


func _on_stage_changed(stage: int) -> void:
	reset_for_stage(stage)


func reset_for_stage(stage: int) -> void:
	_stage = stage
	_done.clear()


## Fire a one-shot goal toast. Safe to call repeatedly — only the first hit counts.
func complete(id: String, message: String) -> void:
	if id == "" or message == "":
		return
	if bool(_done.get(id, false)):
		return
	_done[id] = true
	Events.notify.emit("◆ Goal: %s" % message)


func is_done(id: String) -> bool:
	return bool(_done.get(id, false))


func completed_count() -> int:
	return _done.size()
