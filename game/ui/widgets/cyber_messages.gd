class_name CyberMessages
extends Control
## The HUD's message system: a WARNING banner at the top (yellow warnings, red errors) and a STATUS
## banner at the bottom (cyan info), independent timers/histories/dedup (banner spec §7). Put it
## under the Hud and it listens to `Hud.message_posted` (the `Hud.post_message` contract), so
## gameplay code only ever calls `hud.post_message(text, Hud.WARNING)`.

var warning := CyberBanner.new()
var status := CyberBanner.new()


func _init() -> void:
	name = "CyberMessages"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	warning.name = "WarningBanner"
	warning.kind = CyberBanner.Kind.WARNING
	status.name = "StatusBanner"
	status.kind = CyberBanner.Kind.STATUS


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(status)
	add_child(warning)
	var hud := get_parent()
	while hud != null and not hud.has_signal("message_posted"):
		hud = hud.get_parent()
	if hud != null:
		hud.message_posted.connect(post)


## Put the banners in side columns (info left, warnings right), or back to the spec's
## top/bottom strips with an empty Rect2.
func set_columns(info_column: Rect2, warning_column: Rect2) -> void:
	status.column = info_column
	warning.column = warning_column


## Severity ints match Hud.INFO / WARNING / ERROR (0 / 1 / 2).
func post(text: String, severity: int) -> void:
	if severity >= CyberBanner.Severity.WARNING:
		warning.post(text, clampi(severity, CyberBanner.Severity.WARNING, CyberBanner.Severity.ERROR))
	else:
		status.post(text, CyberBanner.Severity.INFO)
