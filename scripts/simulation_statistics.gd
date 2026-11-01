extends PanelContainer
class_name SimulationStatistics

@onready var timer_label: Label = $Content/Values/ElapsedTimeValue
@onready var direct_label: Label = $Content/Values/DirectDiscoveriesValue
@onready var merge_label: Label = $Content/Values/MergeDiscoveriesValue
@onready var transfer_label: Label = $Content/Values/MergeContributionValue
@onready var movements_label: Label = $Content/Values/TotalMovementsValue
@onready var steps_label: Label = $Content/Values/SimulationStepsValue
@onready var communication_label: Label = $Content/Values/CommunicationValue
@onready var cnp_label: Label = $Content/Values/CNPValue

var timer_running: bool = false
var timer_start_msec: int = 0
var elapsed_msec: int = 0


func show_statistics(
	direct_count: int,
	merge_count: int,
	merge_percentage: float,
	total_moves: int,
	simulation_steps: int,
	communication_enabled: bool,
	cnp_enabled: bool
) -> void:
	direct_label.text = str(direct_count)
	merge_label.text = str(merge_count)
	transfer_label.text = "%.2f%%" % merge_percentage
	movements_label.text = str(total_moves)
	steps_label.text = str(simulation_steps)
	communication_label.text = "Enabled" if communication_enabled else "Disabled"
	cnp_label.text = "Enabled" if cnp_enabled else "Disabled"


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
	timer_label.text = get_elapsed_time_string()


func get_elapsed_time_string() -> String:
	var total_msec: int = elapsed_msec
	if timer_running:
		total_msec += Time.get_ticks_msec() - timer_start_msec
	var total_seconds: int = floori(total_msec / 1000.0)
	var hours: int = floori(total_seconds / 3600.0)
	var minutes: int = floori((total_seconds % 3600) / 60.0)
	var seconds: int = total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, seconds]
