extends Node
## Data singleton: loads every res://data/*.tres once and localises keys.

func _ready() -> void:
	Registry.ensure_loaded()

func t(key: String, fallback := "") -> String:
	var s := TranslationServer.translate(key)
	if s == key or s.is_empty():
		return fallback if fallback != "" else key
	return s

func species(id: String) -> SpeciesData:
	return Registry.get_species(id)

func pier(id: int) -> PierData:
	return Registry.get_pier(id)
