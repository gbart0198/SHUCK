extends Resource
class_name UpgradeData
## One tier of one upgrade line (SPEC §10).

@export var line := "knife"      # knife | gloves | bench | auto | floor
@export var tier := 1
@export var name_key := ""
@export var desc_key := ""
@export var cost := 0
## Pier at which this tier can first be bought. 0 = franchise only.
@export var unlock_pier := 1
@export var value := 0.0
