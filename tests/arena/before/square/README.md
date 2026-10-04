# The square layouts (yard, round 17)

`arenas/*.json` as they were at `3713fdaa` (the round-17 launch tree), copied for every layout whose containers
`tools/container_skew.py` turned. Frozen, never regenerated: they are the BEFORE of two things.

- `tests/test_arena_container_joints.gd` fires rays across every joint of these layouts and of today's, and fails if a
  ray the square wall blocked gets through the turned one ("a wall must stay a wall").
- The frames page (`make container-frames`): the same pose, square vs turned (`--arena=res://tests/arena/before/square/<name>.json`).

Do not edit. If the kit or schema changes so these stop loading, re-freeze them from the commit before the change
that turned the containers and say so here.
