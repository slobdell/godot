class_name CleanFeed
extends Node
## O5 (`make showmatch`, the lead: *"pit 2 computer players against each other so I can easily record the game to
## share with people"*): the clean feed of a recording. Every frame, after the HUD has laid itself out, everything on
## the HUD layer is hidden except the end banner ("WINNER: <FACTION>", and its frame) and, with `keep_score`, the score
## bug: no status block, buttons, messages, captions, command card, radar, group bar or unit bars. It only hides, so
## the HUD keeps working underneath and nothing here changes a match. Added only for `--cinematic --clean`.

var hud: CanvasLayer
## `--clean-score`: the score bug stays on screen (who is ahead, on a video).
var keep_score := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = 1000  # after HudSkin and the rest have set their own visibility this frame


func _process(_delta: float) -> void:
	if hud != null:
		CleanFeed.apply(hud, keep_score)


## Hide what a clean feed hides on `layer` (the game's HUD). The banner and the skin's banner frame keep their own
## visibility (they show at the end); so does the score bug when `keep_score`.
static func apply(layer: CanvasLayer, keep_score: bool) -> void:
	for child in layer.get_children():
		if not child is CanvasItem:
			continue
		match String(child.name):
			"Banner":
				continue
			"HudSkin":
				var skin := child as Control
				var banner_frame: Variant = skin.get("banner_frame")
				for part in skin.get_children():
					if part is CanvasItem and part != banner_frame:
						(part as CanvasItem).visible = false
				continue
			"ScoreBug":
				if keep_score:
					continue
		(child as CanvasItem).visible = false
