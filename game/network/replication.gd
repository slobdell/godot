class_name Replication
extends RefCounted
## What networked objects replicate, in one place (netcode workstream owns this file).
## Built in code rather than in tank.tscn so gameplay and netcode don't edit the same scene.

const TANK_SYNC_INTERVAL := 0.033
## [property, replication mode]. ALWAYS = unreliable every interval; ON_CHANGE = reliable on change.
const TANK_PROPERTIES := [
	["sync_position", SceneReplicationConfig.REPLICATION_MODE_ALWAYS],
	["sync_yaw", SceneReplicationConfig.REPLICATION_MODE_ALWAYS],
	["sync_turret_yaw", SceneReplicationConfig.REPLICATION_MODE_ALWAYS],
	["sync_health", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE],
	["sync_alive", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE],
	["sync_reload", SceneReplicationConfig.REPLICATION_MODE_ALWAYS],
	["sync_firing", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE],
	["sync_intent", SceneReplicationConfig.REPLICATION_MODE_ON_CHANGE],
]


## Must run on EVERY peer inside the spawn function, before the tank enters the tree,
## so the synchronizer's node path exists identically everywhere.
static func attach_tank_sync(tank: Tank) -> void:
	var config := SceneReplicationConfig.new()
	for entry in TANK_PROPERTIES:
		var path := NodePath(".:" + String(entry[0]))
		config.add_property(path)
		config.property_set_spawn(path, true)
		config.property_set_replication_mode(path, entry[1])
	var sync := MultiplayerSynchronizer.new()
	sync.name = "StateSync"
	sync.replication_interval = TANK_SYNC_INTERVAL
	sync.replication_config = config
	tank.add_child(sync)
