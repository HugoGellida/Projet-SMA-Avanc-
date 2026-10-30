extends Control

@onready var title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
@onready var direct_label: Label = $PanelContainer/VBoxContainer/DirectDiscoveriesLabel
@onready var merge_label: Label = $PanelContainer/VBoxContainer/MergeDiscoveriesLabel
@onready var transfer_label: Label = $PanelContainer/VBoxContainer/TransferRateLabel
@onready var movements_label: Label = $PanelContainer/VBoxContainer/TotalMovementsLabel
@onready var steps_label: Label = $PanelContainer/VBoxContainer/SimulationStepsLabel
@onready var communication_label: Label = $PanelContainer/VBoxContainer/CommunicationLabel
@onready var cnp_label: Label = $PanelContainer/VBoxContainer/CNPLabel
@onready var timer_label: Label = $PanelContainer/VBoxContainer/TimerLabel

var timer_running: bool = false
var timer_start_msec: int = 0
var elapsed_msec: int = 0

func _ready() -> void:
	show()


func show_statistics(
	direct_count: int,
	merge_count: int,
	merge_percentage: float,
	total_moves: int,
	simulation_steps: int,
	communication_enabled: bool,
	cnp_enabled: bool
) -> void:

	title_label.text = "Simulation Statistics"

	direct_label.text = "Direct discoveries: %d" % direct_count
	merge_label.text = "Cells learned through merge: %d" % merge_count
	transfer_label.text = "Merge contribution: %.2f%%" % merge_percentage
	movements_label.text = "Total movements: %d" % total_moves
	steps_label.text = "Simulation steps: %d" % simulation_steps

	communication_label.text = "Communication: %s" % (
		"Enabled" if communication_enabled else "Disabled"
	)

	cnp_label.text = "CNP: %s" % (
		"Enabled" if cnp_enabled else "Disabled"
	)

	show()


func start_timer() -> void:
	if timer_running:
		return

	timer_running = true
	timer_start_msec = Time.get_ticks_msec()


func stop_timer() -> void:
	if not timer_running:
		return

	elapsed_msec += Time.get_ticks_msec() - timer_start_msec
	timer_running = false
	_update_timer_label()


func reset_timer() -> void:
	timer_running = false
	elapsed_msec = 0
	_update_timer_label()


func _process(_delta: float) -> void:
	if timer_running:
		_update_timer_label()


func _update_timer_label() -> void:
	var total_msec: int = elapsed_msec

	if timer_running:
		total_msec += Time.get_ticks_msec() - timer_start_msec

	var total_seconds: int = total_msec / 1000

	var hours: int = total_seconds / 3600
	var minutes: int = (total_seconds % 3600) / 60
	var seconds: int = total_seconds % 60

	timer_label.text = "Elapsed time: %02d:%02d:%02d" % [
		hours, minutes, seconds
	]
	
	
func get_elapsed_time_string() -> String:
	var total_msec: int = elapsed_msec

	if timer_running:
		total_msec += Time.get_ticks_msec() - timer_start_msec

	var total_seconds: int = total_msec / 1000

	var hours: int = total_seconds / 3600
	var minutes: int = (total_seconds % 3600) / 60
	var seconds: int = total_seconds % 60

	return "%02d:%02d:%02d" % [hours, minutes, seconds]
