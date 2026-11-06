extends Resource
class_name InteractionStep
## One gesture in a chained interaction. Every gadget reuses these (SPEC §20).

@export var id := ""
@export var duration := 0.5
@export var skill := ""          # hold_release | ring | drag | place
@export var params: Dictionary = {}
@export var next_step := ""
