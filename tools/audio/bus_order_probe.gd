extends Node
## Round 17 (guns): ground truth for the order the game builds its audio buses in. Injected as an autoload into a
## scratch copy of any tree (make bus-order): once the match has run BUS_ORDER_AFTER_S seconds it prints every bus in
## index order with its send, and every compressor's sidechain source and settings, then quits. Changes nothing else.

const BUS_ORDER_AFTER_S := 12.0
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	if _t < BUS_ORDER_AFTER_S:
		return
	var buses := PackedStringArray()
	for i in AudioServer.bus_count:
		var effects := PackedStringArray()
		for e in AudioServer.get_bus_effect_count(i):
			var effect := AudioServer.get_bus_effect(i, e)
			if effect is AudioEffectCompressor:
				var c := effect as AudioEffectCompressor
				effects.append("Compressor(%s %.0fdB %.1f:1)" % [c.sidechain, c.threshold, c.ratio])
			else:
				effects.append(effect.get_class().replace("AudioEffect", ""))
		buses.append("%d:%s>%s[%s]" % [i, AudioServer.get_bus_name(i), AudioServer.get_bus_send(i), ",".join(effects)])
	print("BUS_ORDER " + " ".join(buses))
	get_tree().quit(0)
