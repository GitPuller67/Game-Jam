# Hospital Time – map project (Godot 4.7)

Open `project.godot` in Godot and run (F5). With no player yet, a **map viewer camera** lets you look around:
**WASD/arrows** pan · **mouse wheel / Q / E** zoom · **right-drag** pan · **1–6** jump to a room · **0** reset zoom · **G** show/hide the 26×51 character-size guides.
Delete the `MapViewer` node once your friend's player camera is in.

## Scene layout – `scenes/Map.tscn`
| Node | What it is |
|---|---|
| `Background` | Back walls (TileMapLayer, no collision) |
| `WallDecor` | Signs, windows, notice boards etc. painted on the walls |
| `Solid` | Floors, walls, ceilings, stairs – **has collision** (physics layer 1 "world") |
| `Rooms/Room1…6` | All props and animated objects, grouped per room |
| `Lighting` | Per-room darkening (`Shade` sprites, multiply) + ceiling lights, window sunbeams and dust. Lower a Shade's colour to darken a room, change a light's `energy` to brighten a spot |
| `RoomAnchors` | Room centres (used by the viewer) |

Paint more level with the **TileMap** panel using `tiles/hospital_tileset.tres`:
source 0 = side-view tiles (rows 0–1 walls/floors, (0,2) stairs, (2–4,2) one-way catwalk), source 1 = ward wall fixtures.

Orange `EditorNote` labels and `Marker2D`s (PlayerStart, BabyStart, guard spots, LampSwing, ElevatorCall…) show where
gameplay goes; notes are hidden when the game runs.

## Hooks for the gameplay code
- **Time power:** most animated things have a `time_scale` property (1 = normal, 0.2 = slowed, 0 = frozen):
  `SwingingLamp`, `Elevator`, each `Pillar` and its `Chunk`, Room 5 floaters, clocks, cable pulses.
  Room 6 uses `loop_speed` on the room node (drives the whole 10-second loop).
- Room 1: `ExitDoor.open()`, `PodDoor.open()`, `Observers.vanish_all()`, `Keypad.play("unlocked")`
- Room 2: `Elevator.go_to_floor(0 or 1)` (turn off `auto_cycle`), `SwingingLamp/Lamp/GrabPoint` (group `grab_point`)
- Room 4: `Pillar.break_pillar()`; vent opens when all four have broken. Untick `demo_autoplay` on `Room4_Pillars`.
- Room 5: every floater has a `Hazard` Area2D in group `hazard` (physics layer 2).
- Room 6: `door_is_open()`, `loop_time()`.

## Regenerating
`tools/build_map.gd` created the map. **Re-running it overwrites `Map.tscn`** (and your edits) – only use it to start over:
`godot --headless --path . --script res://tools/build_map.gd`
