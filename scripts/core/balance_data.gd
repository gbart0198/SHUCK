extends Resource
class_name BalanceData
## Every tunable number in SHUCK. Loaded from res://data/balance.tres (SPEC §23).

@export_group("Wedge — gesture 1")
@export var wedge_duration := 0.6
@export var wedge_none_max := 0.40
@export var wedge_clean_start := 0.55
@export var wedge_clean_end := 0.75
@export var wedge_snag_time_penalty := 0.15
@export var wedge_steady_tolerance_bonus := 0.08
@export var wedge_wobble_penalty := 0.20
@export var wedge_slip_nick_chance := 0.40
@export var wet_hands_meter_speed := 1.15

@export_group("Pop — gesture 2")
@export var pop_duration := 0.5
@export var pop_perfect_max := 0.30
@export var pop_normal_max := 0.60
@export var pop_fightback_time := 1.2

@export_group("Slide — gesture 3")
@export var slide_offline_limit := 40.0
@export var slide_off_shell := 60.0
@export var slide_hover_speed_ref := 800.0
@export var slide_surgical_inside_ratio := 0.80
@export var slide_surgical_speed_ratio := 0.80
@export var slide_steady_tolerance_bonus := 0.08
@export var slide_wander_gain := 6.0
@export var knife_tolerances := PackedFloat32Array([6.0, 9.0, 9.0, 9.0, 15.0, 18.0])
@export var knife_wander_mult := PackedFloat32Array([1.0, 1.0, 1.0, 1.0, 0.7, 0.7])

@export_group("Grade scores")
@export var wedge_bonus_clean := 10
@export var wedge_bonus_imperfect := 5
@export var wedge_bonus_slip := -10
@export var pop_bonus_perfect := 20
@export var pop_bonus_normal := 10
@export var surgical_bonus := 10
@export var nick_penalty := 15
@export var juice_penalty := 25
@export var stab_penalty := 25
@export var knife_t4_score_bonus := 1

@export_group("Tickets")
@export var patience_base := 22.0
@export var patience_per_extra_oyster := 3.0
@export var rail_timeout := 60.0
@export var last_call_seconds := 20.0
@export var last_call_tickets := 3
@export var chaos_at_fraction := 0.60
@export var modifier_chance := 0.30
@export var regular_tip_bonus := 0.50
@export var togo_pay_bonus := 0.10
@export var ticket_max_oysters := 4

@export_group("Tips and pay")
@export var neon_tip_bonus := 0.10
@export var display_pearl_tip_bonus := 0.02
@export var display_pearl_tip_cap := 0.20
@export var aquarium_display_mult := 2.0
@export var rank_tip_bonus := 0.02
@export var combo_max := 2.0
@export var combo_step := 0.10

@export_group("Pearls")
@export var pearl_base_value := 40.0
@export var pearl_size_min := 3.0
@export var pearl_size_max := 14.0
@export var pearl_size_curve := 2.2
@export var pearl_flawed_mult := 0.4
@export var mother_of_pearl_value := 2500
@export var tidewrought_value := 5000
@export var cultch_luck_bonus := 0.01
@export var lamp_pearl_bonus := 0.08
@export var automation_pearl_penalty := 0.5

@export_group("Bench freshness (seconds per tier)")
@export var bench_freshness := PackedFloat32Array([90.0, 120.0, 600.0, 600.0, 600.0, 600.0])
@export var plated_hold := PackedFloat32Array([8.0, 8.0, 8.0, 8.0, 28.0, 28.0])
@export var bench_slots := PackedInt32Array([1, 2, 2, 2, 2, 4])

@export_group("Automation")
@export var auto_belt_interval := 4.0
@export var auto_otto_interval := 12.0
@export var auto_line_duration := 60.0
@export var auto_max_grade := "B"
@export var auto_pay_bonus := 0.15

@export_group("Shift")
@export var xp_per_grade := {"S": 10, "A": 6, "B": 3, "C": 1, "F": 0}
@export var xp_per_shift := 20
@export var ranks := PackedInt32Array([0, 120, 380, 900, 1800, 3200])
@export var rank_names := PackedStringArray(["RANK_DECKHAND", "RANK_SHUCKER", "RANK_FIRST", "RANK_DOCKBOSS", "RANK_PEARLBARON", "RANK_TIDEBREAKER"])
@export var perfect_pops_badge_count := 20
@export var last_call_badge_window := 1.0

@export_group("Co-op")
@export var coop_ticket_scale := PackedFloat32Array([1.0, 2.2, 3.2, 4.0])
@export var coop_income_scale := PackedFloat32Array([1.0, 2.0, 2.9, 3.6])
@export var revive_drag_seconds := 3.0
@export var faint_seconds := 6.0
