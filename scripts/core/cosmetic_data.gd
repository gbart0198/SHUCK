extends Resource
class_name CosmeticData
## A cosmetic item (SPEC §12.1).

@export var id := ""
@export var name_key := ""
@export var slot := "hat" # hat | apron | glove | knife | bucket | radio | hook | sign
@export var price := 60
@export var color := Color(0.8, 0.8, 0.8)
@export var badge_only := false
