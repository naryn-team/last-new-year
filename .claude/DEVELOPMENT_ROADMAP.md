# DEVELOPMENT_ROADMAP.md — "The Last New Year"

**Based on:** `PROJECT_AUDIT.md` (snapshot `37c74fa`, Godot 4.7.2).
**Structure:** three steps, agreed with the project owner.

| Step | Goal | Result |
|---|---|---|
| **Step 0** ✅ | Clean up, refactor, establish a good structure and architecture | Same gameplay as today, on a clean codebase with every foundation Steps 1–2 need |
| **Step 1** ✅ | The car (lights etc.), driving controls, the road to the house, the exit-from-car animation | The game starts behind the wheel; the player drives to the house; the car dies; the player gets out |
| **Step 2** ✅ | The ending: the maniac catches the player at the car → the ritual cutscene | The game can be played from the main menu to the end card |

After that come asset integration and polish (§"After Step 2").

**Rules for all steps**
- Keep everything that works today: the house, the maniac AI, hiding, notes, the safe, doors and the item chain (audit §5).
- Each step ends with the game in a playable state that passes the regression checklist (CLAUDE.md §11.3). Then the owner reviews it and makes **one commit for the step**; Claude Code never commits.
- Final models and animations do not exist. Everything new is built from primitives with a swappable `Model` child and named `Marker3D` anchors.
- Names marked *(proposed)* do not exist yet.

---

## Decisions this plan is based on

These were derived from the owner's step list. Change them here if they are wrong.

1. **Driving is real player control, but arcade and road-bound.** The player steers and accelerates along the road. The car cannot leave the road, flip over or get stuck. This is implemented as *road-follow driving*: the car moves along the road's `Path3D`, the player controls speed and a sideways offset clamped to the road width. It is not a `VehicleBody3D` physics simulation. Reasons: the drive is short and linear, the ending of the drive is scripted (the fuel runs out at the house), and physics vehicles need long tuning and can get stuck in snow or trees. A physics car remains possible later if the design ever needs free driving.
2. **The fuel runs out at the house.** This is what the existing lore says (`car.gd:22`: "Бензин кончился у самого дома"). Near the house the engine sputters, control is taken away, and the car rolls to a stop. This guarantees the car always parks in the same spot, where the refuel gameplay already expects it.
3. **The exit from the car is first-person.** There is no protagonist model. The "animation" is the camera moving from the driver's seat out through the opened door to standing height, plus the door swing and sounds.
4. **The catch at the car is scripted, not AI.** The maniac's navmesh covers only the house, so the AI cannot chase outdoors, and the ending must always trigger. After the player refuels and tries to leave, a cutscene plays: the maniac appears and knocks the player out.
5. **Being caught inside the house stays as it is now:** jumpscare → game-over screen → Retry. Only the car scene leads into the ritual. *If the owner wants every catch to lead to the ritual, only Step 2.1's trigger changes.*
6. **The ritual is a separate scene:** `ritual.tscn`, upgraded. It is not a location on the world map.
7. **Retry after a death in the house skips the drive:** the player respawns next to the parked car.

---

# STEP 0 — Cleanup, refactoring, structure and architecture

**Status: ✅ DONE — committed as `8291ab6`.**
Verified headless: import, all scenes, 0 GDScript warnings, probe of the gameplay chain and of the cutscene framework.
Implementation notes (where the plan left a choice):
- 0.1: all items done; the owner re-saved the scenes, the two remaining path-only references (`world.tscn` → `level.tscn`, `level.tscn` → `tree.tscn`) got their `uid=` by hand. The inline maniac footstep Ogg was byte-identical to `footstep_maniac.ogg`.
- 0.2: done as in the target layout; `game/car.gd` → `vehicle/car.gd` already now. Old folders `game/`, `level/`, `maniac/` are gone.
- 0.3: `SceneFlow` fades: menu → world 0.8/0.6, pause → menu 0.4/0 (the game stays paused during the fade), game over → world 0.6/0.6, game over → menu 0.6/0, catch → game over 0/0.6. The note window still also closes on Space/Enter; keypad digits stay raw keycodes.
- 0.4: decision — during a cutscene the maniac AI is **paused** (`maniac.set_ai_paused`, state kept). While a cutscene plays Esc/Space are `cutscene_skip` and the pause menu does not open. On skip, Call Method keys are not fired (documented in `cutscene.gd`). The throw-away fly-by test cutscene was deleted after the check.
- 0.5: hero footsteps done (`audio/sfx/footstep_snow.ogg`, `footstep_wood.ogg`, wood = floor under group `surface_wood` on `House`). The optional Windows export preset was **not** made.

**Priority:** Critical · **Size:** L (largest step, but no new features)
**Objective:** identical gameplay on a clean, well-organised codebase that already contains every foundation the car and the cutscenes need. Doing this first means Steps 1 and 2 are built *on* systems instead of being hard-wired *around* them.

Do the sub-steps in order and run the headless checks after each one. **Claude Code does not commit**: the owner makes one commit for the whole step after checking it.

## 0.1 Cleanup and bug fixes (hours) — ✅

1. `git rm -r last-new-year/`. It is a stale copy of commit `503ecd3`; Godot ignores it and nothing references it.
2. Move `audio/winter wind home.aup4` (66 MB) and the three unused freesound WAVs out of the game folders, into a git-ignored `_source/`. Keep the snow and wood footstep WAVs available for 0.4.
3. Set **Loop** on `audio/winter wind.ogg` (it currently stops after 5 min 36 s).
4. Fix the drawing counter (`game.gd:47-51` counts before the drawings register): count deferred.
5. Rename the shadowing identifiers (`game.gd` `name` → `flag_name`, `hide_spot.gd` `sign` → `side`) for 0 warnings.
6. Remove the unused `_mouse_was_captured` in `pause_menu.gd`. Make `maniac.tscn` reference `audio/footstep_maniac.ogg` instead of its inline copy.
7. Open every scene in the Godot editor once and save it. This adds `uid=` headers and UID references to the scenes that were written outside the editor (`level.tscn`, `tree.tscn`, `ritual.tscn`, `game_over.tscn`). This is done by the owner in the editor **before Step 0 starts** (and committed by him separately, because the diff is large). Claude Code only verifies that the scene headers now have `uid=`; if not, it stops and asks. **This must happen before 0.2**, so that moved files keep their references.

## 0.2 Folder structure (move files) — ✅

**Why:** today systems (settings, UI windows) are mixed with level props in `game/`, and the player and menu sit in the root. Steps 1–2 add vehicles, cutscenes and characters. A clear layout now prevents a mess later.

**Target layout** *(proposed)*:

```
project.godot
core/                      autoloads and shared code
  settings.gd              (from game/)            autoload Settings
  scene_flow.gd            NEW (0.3)               autoload SceneFlow
  ui_style.gd              (from game/)            class_name UIStyle
gameplay/
  game.gd                  (from game/)            Game node: interaction, inventory, flags, objectives
player/
  player.tscn, player.gd   (from root)
characters/
  maniac/   maniac.tscn, maniac.gd, maniac_model.tscn (NEW 0.5), jumpscare.wav
  cultist/  (Step 2)
interactables/
  door.gd, front_door_trigger.gd, pickup.gd, safe.gd, boards.gd, note.gd   (from game/)
  hide_spot.gd                                                             (from level/)
vehicle/                   (Step 1)  car.tscn, car.gd (from game/car.gd)
cinematics/
  cutscene.gd              NEW (0.4)
ui/
  main_menu.tscn, main_menu.gd   (from root)
  hud.gd                   NEW (0.3, split out of game.gd)
  pause_menu.gd, settings_panel.gd, note_window.gd, keypad_window.gd   (from game/)
  cinematic_overlay.gd     NEW (0.4)
  game_over.tscn, game_over.gd   (from maniac/)
  fonts/                   (unchanged)
levels/
  world/   world.tscn (from root), level.tscn, tree.tscn, flicker_light.gd, flat.gdshader (from level/)
  ritual/  ritual.tscn (from level/)
audio/
  ambience/ winter wind.ogg
  sfx/      footstep_hero.ogg, footstep_maniac.ogg (+ trimmed snow/wood steps)
```

**How to move safely (important)**
- Best: the owner moves the files by drag-and-drop in the **Godot editor's FileSystem dock**, which updates references automatically. Claude Code provides this table as a checklist.
- If Claude Code moves the files: use `git mv` and **always move the sidecar too** (`x.gd` + `x.gd.uid`, `x.ogg` + `x.ogg.import`). Then grep for every old `res://` path, because the code also contains hardcoded path strings:
  - `change_scene_to_file("res://world.tscn")` / `("res://main_menu.tscn")`,
  - `preload("res://game/pause_menu.gd")` and the other window preloads in `game.gd`,
  - `preload("res://game/settings_panel.gd")`,
  - `const HideSpot = preload("res://level/hide_spot.gd")`,
  - `"res://maniac/jumpscare.wav"`, `game_over_scene := "res://maniac/game_over.tscn"`,
  - `UIStyle` font paths `res://ui/fonts/...` (these do not move),
  - `project.godot`: `run/main_scene` (UID, stays valid) and the `Settings` autoload path (must be updated).
- After moving: headless import with no errors, then the full regression checklist.

## 0.3 Core architecture — ✅

**A. Input actions** (replace all hardcoded keycodes)
- InputMap actions with **physical** keys: on foot `move_forward`, `move_back`, `move_left`, `move_right`, `sprint`, `crouch`, `jump`, `flashlight`, `interact`, `pause`; for Step 1 `car_accelerate` (W/↑), `car_brake` (S/↓), `car_steer_left` (A/←), `car_steer_right` (D/→), `car_handbrake` (Space), `car_horn` (H, optional), `car_lights` (L, optional); for cutscenes `cutscene_skip` (hold Space or Esc).
- Files: `player.gd`, `game.gd`, `pause_menu.gd`, `settings.gd` (F11), `settings_panel.gd` (help text), and optionally the note and keypad windows (digit keys may stay raw).

**B. Player control API** in `player.gd`, replacing external manipulation:
- `set_control_enabled(enabled: bool)`, `is_control_enabled()`, signal `control_changed(enabled)`.
- Real properties `is_hidden`, `is_dead` (replacing the metadata `hidden` / `dead` / `hide_spot_node`).
- `get_camera()`, `set_flashlight(on)`, `teleport_to(xform: Transform3D)`, `set_body_enabled(enabled)` (collision on/off, used when the player sits in the car).
- Migrate `hide_spot.gd`, `maniac.gd`, `game.gd` and `pause_menu.gd` to the API **without changing behaviour**. Keep the gameplay numbers (speeds, stamina, noise radii) exactly as they are.

**C. Split `game.gd` into game state and HUD**
- `gameplay/game.gd` keeps the interaction raycast, inventory, flags, notes, drawings and objectives.
- `ui/hud.gd` *(new)* builds the crosshair, prompt, message, inventory, objective and stamina bar. `game.gd` updates it through methods: `hud.set_prompt()`, `hud.show_message()` and so on.
- New: `game.set_hud_visible(bool)`, `game.set_interaction_enabled(bool)`.
- Keep the flag and item ids unchanged (audit §4.4).

**D. Scene flow autoload** `core/scene_flow.gd` → autoload `SceneFlow`:
- `change_scene(path, fade_out := 0.6, fade_in := 0.6)` with a black overlay on CanvasLayer 100.
- Awaitable `fade_out()` / `fade_in()`.
- `session: Dictionary`, which survives scene changes. Keys used later: `arrived` (Step 1), and `ending` (Step 2).
- Replace all 5 `change_scene_to_file` calls.

**E. Audio buses** (`default_bus_layout.tres`): `Master` → `Music`, `Ambience`, `SFX`, `UI`. Assign the existing players.

**F. Maniac model separation**
- Move the maniac's primitive `Model` into `characters/maniac/maniac_model.tscn` with a `FaceAnchor` Marker3D, and instance it in `maniac.tscn`.
- Change the jumpscare to use `FaceAnchor` instead of the magic `1.57 / 0.31` (`maniac.gd:649`).
- Step 2 reuses `maniac_model.tscn` in the capture cutscene, so the AI maniac and the cutscene maniac always look the same, and a future real model replaces both at once.

## 0.4 Cutscene and camera framework — ✅

Steps 1 and 2 are both made of cutscenes (car stop, exit, capture, ritual), so the framework belongs in the foundation.

- A cutscene is a **scene** whose root uses `cinematics/cutscene.gd` (`class_name Cutscene`). It contains an `AnimationPlayer` with an animation named `"main"`, one or more `Camera3D` nodes, and `Marker3D` anchors. Events use **Call Method** tracks.
- `Cutscene.play()`:
  1. disables player control, the HUD and interaction (null-safe: the ritual scene has no `Game` node and no player);
  2. makes its camera current;
  3. plays `"main"`;
  4. supports skip: holding `cutscene_skip` **seeks to the end**, so the final state is always applied;
  5. on finish, optionally blends to the player camera, restores everything and emits `finished`.
- `ui/cinematic_overlay.gd`: letterbox bars, fade, and an "eyelids" effect (two black rects closing and opening, the same technique as the wardrobe slit in `hide_spot.gd`). Step 2 needs the eyelids for the wake-up.
- Camera handling stays simple: `make_current()` plus a tween-based blend helper. No camera manager.
- Decide and implement: during any cutscene the AI maniac is paused or ignores the player.
- Validate with a throw-away test cutscene (camera fly-by around the house, then control returns). Delete it afterwards.

## 0.5 Small extras — ✅ (export preset skipped)

- Hero footsteps: the `Footsteps` node exists in `player.tscn` but is never played. Play it by distance walked, like `maniac.gd:_play_footsteps`. Snow outside, wood inside (use the trimmed WAVs).
- Optional: a Windows export preset for playtest builds.

**Step 0 — files touched:** nearly all scripts (moves and paths), `project.godot` (input, autoloads, buses), all scenes (re-save, paths).
**New files:** `core/scene_flow.gd`, `ui/hud.gd`, `cinematics/cutscene.gd`, `ui/cinematic_overlay.gd`, `characters/maniac/maniac_model.tscn`, `default_bus_layout.tres`.
**Expected result:** the game plays **exactly** as before (same start, same puzzles, same maniac), on the new structure, with input actions, a player API, a HUD/game split, scene fades, audio buses and a working cutscene framework.
**Do not** add the car, the road or the ending in Step 0.

---

# STEP 1 — Car, driving, road to the house, exit from the car

**Status: ✅ DONE — committed as `ad3fc38`.** After it: a presentation pass (docs moved to `.claude/`, README, project name/icon/version, Windows export preset, process comments removed from code, unused `flat.gdshader` deleted).
Verified headless with probes (whole drive at `time_scale` 4, Retry, on-foot regression, intro skip); 0 warnings.
Implementation notes (where the plan left a choice):
- 1.1: road = `levels/world/exterior_road.tscn` (903 m, starts at (-120, 0, 820), ends at the car spot (4, 0, 1) heading -Z). Ground outside the 100x100 area = three flat snow planes (not CSG). Roadside trees and posts are MultiMesh, generated on `_ready` from the curve, only outside the play area; 14 trees of the level forest in the road corridor were removed. No snow banks (they would cross the footpath at the parking end). `MapBorder` kept (the car ignores it).
- 1.2: `vehicle/car.tscn` as planned; `InteriorCam` exists but has no toggle key; audio players have no streams. Driver door = front left.
- 1.3: no reverse; with no throttle the car creeps at 2.5 m/s, so the drive can never stall. Cruise 15 m/s (autopilot in the intro), max 19.5 m/s.
- 1.4: the fuel runs out at a **distance** (70 m before the road end), not an Area3D: the car is path-bound, so this is exact and cannot be missed. Uniform deceleration ends exactly at the road end (minimum coast speed 6 m/s). Sputter = headlight dips (no audio yet); after the stop the headlights flicker off, so the on-foot lighting is the same as before Step 1. The exit cutscene is a child of the car (`cinematics/car_exit.tscn`), the intro too (`cinematics/drive_intro.tscn`).
- 1.5: start logic lives in `levels/world/world.gd` (`start_mode` AUTO / DRIVE / ARRIVED / ON_FOOT). Retry puts the player at `DriverExit` next to the parked car; ON_FOOT keeps the old spawn for tests.
- `Cutscene` got `blend_in_time` and `return_to_player`; `blend_camera` now follows a moving target.
- **Revision (owner's request, same day): first-person driving.** The default view is the driver's head inside a modelled cabin (hollow CSG shell, glass, interior, animated steering wheel, working instrument cluster with speedometer / tachometer / gear / fuel / temperature / lamps, radio clock, working rear-view mirror, dash glow, head motion, snowfall). The chase camera stays as an optional view on C. The driving model was replaced: instead of following the road tangent automatically, the car has its own heading and front-wheel angle (kinematic bicycle model in road coordinates) with rate-limited, speed-sensitive steering and a grip limit — the player has to steer through every turn and brake before sharp ones; the road edges still keep the car on the road (it slides along the bank, loses speed, the camera shakes). The road was rebuilt from straights and exact arcs: 1061 m, radii 18–45 m including a 170° hairpin, a 130 m start straight for the intro and a 100 m final straight where the fuel runs out (85 m before the end) — so the car parks at exactly 0°. Snow banks, a dashed centre line and posts with reflectors (all generated from the curve, outside the play area) give speed and edge cues in the headlights. The road generator is a throw-away Python "turtle" script (commands S length / L,R angle radius, built backwards from the parking spot); keep the command list in this note if the road must be regenerated:
  `S100, L75 R28, S35, R140 R20, S45, L170 R18, S60, R60 R35, S30, R75 R24, S50, L110 R22, S40, L50 R40, R95 R26, S55, R80 R30, L120 R20, S45, L40 R45, R55 R30, S130` (built from the parking spot heading south; L/R refer to that backward direction).
- **Tuning after the first playtest (owner):** the camera no longer looks into turns or rolls (it turns only with the car); steering made stronger and quicker (`max_steer_fast` 0.14 → 0.3, `max_steer_slow` 0.6 → 0.7, `steer_rate` 1.5 → 2.6, `return_rate` 2.4 → 3.0, `grip` 7.5 → 11, `steering_ratio` 8 → 7). A keyboard-style probe driver that reacts late hit the banks 5 times with the old values and 0 times with the new ones.
- **Second tuning (owner):** the car turns tighter at the same steering-wheel angle: `wheelbase` 2.7 → 2.35 (≈ +15 % turn rate), `grip` 11 → 12.5. The steering wheel animation is unchanged.

**Priority:** High · **Size:** L
**Depends on:** Step 0 (input actions, player API, SceneFlow, cutscene framework).
**Objective:** New Game starts behind the wheel at night on a forest road. The player drives to the house. The car runs out of fuel and rolls to a stop at the usual spot. The player gets out in first person. From there, today's gameplay continues unchanged.

## 1.1 Road and exterior — ✅

- A `Path3D` named `RoadPath` *(proposed)*, starting **far outside** today's playable 100 × 100 m area (a drive of roughly 60–90 seconds at the cruise speed) and ending at the parking spot near (4, 0, 1), where the car stands today.
- A placeholder road surface generated from the **same curve** with `CSGPolygon3D` in *Path* mode. Road and driving path can never disagree. Add snow banks or edge posts (primitives).
- Extend the ground along the road. The `MapBorder` walls stay for the on-foot part. Remove the wall segment the road passes through *only if* the player must not be blocked on foot there; otherwise keep it, because the car follows the path and does not collide with the walls.
- Move or remove trees in the road corridor; add trees along the new road (reuse `tree.tscn`).
- Keep the existing footpath from the parking spot to the porch.
- **Do not change the `House`**, so no navmesh re-bake is needed.
- Suggested location: a new `levels/world/exterior_road.tscn` *(proposed)*, instanced in `level.tscn`.

## 1.2 Car scene `vehicle/car.tscn` — ✅

Replaces the inline `Exterior/Car` CSG in `level.tscn`.

```
Car (Node3D, vehicle/car.gd)
├─ Model                    placeholder: current CSG body + cabin (later the real model)
│   └─ DoorFL_Pivot         driver door as its own pivoted piece (swings open for the exit)
├─ Wheels/FL FR RL RR       pivots: spin with speed; front pair steers visually
├─ Lights
│   ├─ HeadlightL/R         SpotLight3D (shadows on for at most one of them; check the cost)
│   ├─ HeadlightGlow        emissive placeholder meshes
│   ├─ TailLightL/R         small red OmniLight3D + emissive meshes; brighter while braking
│   └─ InteriorLight        dim OmniLight3D, on while the door is open
├─ Audio
│   ├─ Engine               AudioStreamPlayer3D (idle/drive loop; pitch from speed) — ASSET MISSING
│   ├─ EngineOneShots       start / sputter / stop — ASSETS MISSING
│   ├─ Door                 open/close — ASSET MISSING
│   └─ Tyres                snow crunch loop (optional)
├─ Cameras
│   ├─ ChaseCamRig/Camera3D third-person follow camera (default while driving)
│   └─ InteriorCam          driver's-eye camera (toggle with C, optional)
├─ DriverSeat (Marker3D)    first-person eye point inside the car
├─ DriverExit (Marker3D)    where the player stands after getting out, facing the house
└─ Collision                StaticBody3D/AnimatableBody3D box, so the player cannot walk through the parked car
```

`vehicle/car.gd` keeps the existing interaction (the "Бак пуст" / refuel / "сесть в машину" prompts and the `car_fueled` flag) and adds:
- `state`: `DRIVING`, `STOPPING`, `PARKED`.
- `set_engine_running(on)`, `set_headlights(on)`, `set_brake_lights(on)`, `open_door()` / `close_door()` (tweens).

## 1.3 Driving controls (road-follow arcade) — ✅

*(proposed `vehicle/car_driver.gd`, attached to the car or a child.)*
- The car moves along `RoadPath` by distance; it is placed at `curve.sample_baked_with_rotation(distance)` plus a sideways offset.
- `car_accelerate` / `car_brake` change the speed (cruise ≈ 50–60 km/h, max ≈ 70, reverse slowly or not at all). Speed decays with no input; the handbrake stops quickly.
- `car_steer_left/right` change the sideways offset, clamped to the road width minus the car width. The car yaws slightly into the steer and the body sways, so it *feels* like steering. In curves, too much speed pushes the car toward the outer edge, a simple and readable challenge.
- Optional: snow-covered patches lower the grip (the offset drifts more).
- Wheels spin from speed; engine pitch from speed; brake lights from braking.
- The chase camera follows with smoothing and looks ahead in curves.
- HUD: none, or a minimal speed hint. The first objective appears only after the player gets out.
- Pause works normally while driving. The player character is disabled (`set_control_enabled(false)`, `set_body_enabled(false)`) and parented or teleported to `DriverSeat`.

## 1.4 Arrival sequence: the car dies, the player gets out — ✅

1. **Opening:** fade in from the menu on a short establishing shot of the car on the road (2–5 s, skippable), then hand control to the chase camera. The owner's original intro ("camera follows the car and establishes the atmosphere") fits here.
2. **Fuel runs out:** an `Area3D` near the end of the road (out of sight of the house's front, before the parking spot) starts the stop. A dashboard warning or message appears, the engine sputters 2–3 times (engine audio cut-outs), and control is taken away.
3. **Rolling stop:** the car coasts along the path and stops exactly at the parking spot (ease-out on distance), so the refuel gameplay finds the car where it expects it.
4. **Engine off:** `set_engine_running(false)`; the headlights flicker and dim (or stay on; it is an atmosphere choice). Silence plus wind.
5. **Exit cutscene** `cinematics/car_exit.tscn` *(proposed)*:
   - the camera moves from the chase view to `DriverSeat` (the driver's eyes);
   - a short pause; a look at the dark house through the windshield;
   - the door opens (pivot tween + sound + interior light on);
   - the camera moves out through the door and up to standing height at `DriverExit` (turn, slight bob, a hand on the door frame is not possible without a model, so keep the move itself smooth and weighty);
   - the door closes behind (sound);
   - blend into the player camera, enable player control and collision, show the HUD and the first objective "Дойти до дома".
6. Set `SceneFlow.session.arrived = true`.

## 1.5 Game flow changes — ✅

- New Game (main menu): `session` is cleared → the world loads in **drive mode**: the player is in the car, the car is at the start of `RoadPath`.
- Retry after a death in the house: `session.arrived` is set → the world loads with the car `PARKED` at the stop point, the engine off, and the player standing at `DriverExit`. This is exactly today's start.
- The maniac stays inactive until `front_locked`, as now. Verify that nothing in the drive triggers it.
- The old fixed player spawn in `world.tscn` stays as a fallback and for testing.

**Step 1 — files modified:** `levels/world/level.tscn` (car instance, road), `levels/world/world.tscn` (ground extension, start-mode logic), `player/player.gd` (only if the API needs small additions), `gameplay/game.gd` (objective appears after the exit).
**New files** *(proposed)*: `vehicle/car.tscn`, `vehicle/car.gd` (moved from `game/car.gd` in Step 0), `vehicle/car_driver.gd`, `vehicle/car_camera.gd` (if the chase camera needs code), `cinematics/car_exit.tscn`, `levels/world/exterior_road.tscn`.
**Missing assets to request:** engine idle/drive loop, engine start, sputter, engine off, door open/close, tyres on snow, optionally a horn and a dashboard warning beep.
**Expected result:** Menu → drive at night with headlights → engine dies → car rolls to a stop → first-person exit → today's gameplay. Retry skips the drive.

**Acceptance**
- The drive cannot be failed or blocked (the player cannot leave the road or get stuck).
- The car always ends at the same parking transform (check with a print of the final position).
- After the exit, everything in the regression checklist still works, including refuelling at the parked car.

---

# STEP 2 — Ending: capture at the car and the ritual cutscene

**Status: ✅ DONE (2026-11-19), waiting for the owner's commit and manual check (CLAUDE.md §11.3, item 8).**
Verified headless: the full chain world → refuel → «сесть в машину» → capture → ritual → end card → main menu, and the skip path; 0 warnings.
Implementation notes:
- 2.1: trigger = «сесть в машину» after refuelling (signal `car.ending_requested`, handled in `world.gd`); the AI maniac `vanish()`es. Capture cutscene is a child of the car (`cinematics/ending_capture.tscn`): get in → door closes → two `crank()` attempts (dashboard/headlights flash, «Ну же… заводись.») → the Keeper appears on the rear bench (5.2 s) and is seen in the **working rear-view mirror** (`car.set_mirror_forced`) → turn back → lunge, scream (`jumpscare.wav`), red flash and shake (`Cutscene.hit`) → eyelids close, low-pass muffle (`SceneFlow.set_muffle`, survives the scene change) → 1.5 s black → ritual.
- 2.2: `characters/cultist/cultist.tscn` with the planned animation names and anchors (knife on `KnifeSocket`). Ritual: 7 ring cultists + 2 draggers (join the ring during the black cut) + a priest; bonfire at (0, 0, -2.7) with particles and a flickering light; snowfall; a forest ring built at runtime; wind. No `DragPath` node — the drag is keyed directly (12.8 m in 10 jerky pulls).
- 2.3: `Finale` (38 s) inside `ritual.tscn`: blinks while dragged, muffle clears, subtitles («Меня… тащат.», «Нет… нет-нет-нет…», «Семеро ждали. Восьмой пришёл.», «С Новым годом, Хитклифф.»), placed on the altar during a black cut, head turns (bonfire flares / ring), priest walks up and raises the knife, push-in with fov 70 → 52, stab, black. **Skippable** (hold Space/Esc) — the optional "not skippable on the first playthrough" was not done. End card `ui/end_screen.tscn` → main menu.
- Cutscene keys for both scenes are generated by a throw-away Python script (look-direction → quaternion, `position_3d`/`rotation_3d` tracks). Method keys in one track must not share a time (Godot merges them) — keep them ≥ 0.01 s apart.
- Audio still missing: blow, chant, heartbeat, fire crackle (slots exist).

**Priority:** High · **Size:** L
**Depends on:** Steps 0 and 1 (cutscene framework, car scene, maniac model scene, SceneFlow).
**Objective:** after refuelling, the escape attempt ends with the maniac capturing the player at the car, followed by the owner's ritual sequence and an end card.

## 2.1 Capture at the car

- **Trigger:** when `car_fueled` is set and the player uses "сесть в машину" (the existing prompt in `car.gd`), the capture cutscene starts. *(Alternative trigger, if preferred: right after refuelling.)*
- **Before it starts:** deactivate the AI maniac (`active = false`, hidden) so it cannot interfere, and disable the player API.
- **Cutscene** `cinematics/ending_capture.tscn` *(proposed)*, first-person:
  1. the player opens the door and sits down (camera to `DriverSeat`, door closes);
  2. turns the key: the engine coughs and almost starts (sound) — a moment of hope;
  3. a glance at the rear-view mirror, or a sound from the back seat: the maniac (an instance of `maniac_model.tscn`, using `FaceAnchor` for framing) is in the back seat, as `car.gd:3` intended — *or* behind the driver's window, if the camera framing is easier;
  4. a fast lunge or blow; the camera jerks; the red flash and shake reuse the jumpscare style;
  5. **loss of consciousness:** the eyelids close slowly (the overlay from Step 0), sound muffles (an audio-bus low-pass), black.
- Then `SceneFlow.session.ending = true` and `SceneFlow.change_scene(<ritual scene>)` with a long black hold (1–2 s).
- Being caught **inside the house** still goes to the game-over screen (decision 5).

## 2.2 Ritual scene setup (`levels/ritual/ritual.tscn`, upgraded)

- **Reusable placeholder cultist** `characters/cultist/cultist.tscn` *(proposed)*:
  - `Model` (robe capsule + hood cone, as in today's ritual scene and the maniac);
  - an `AnimationPlayer` with **named** placeholder animations made of simple transform keys: `idle`, `chant` (sway), `walk`, `drag` (lean back, arms forward), `carry`, `raise_knife`, `stab`;
  - anchors: `Hand_L`, `Hand_R`, `Head`, `KnifeSocket`.
  Real models must later provide the same animation names. This is the project's "NPC system": **scripted actors, no AI**.
- **Scene contents:**
  - the existing altar, 7 pedestals (likely the seven taken family members) and torches;
  - **~10 cultist instances** in a ring;
  - a **bonfire** (GPUParticles3D flames and embers + OmniLight3D with `flicker_light.gd` + crackle audio slot, asset missing);
  - a `DragPath` Path3D on the ground leading to the altar;
  - an `AltarHead` anchor (POV while lying on the altar);
  - a primitive knife prop;
  - a root script `levels/ritual/ritual.gd` that plays the cutscene on load.
- The scene has no `Game` node, no HUD and no player controller. The POV is the cutscene camera.

## 2.3 Ritual cutscene (the owner's sequence)

`cinematics/ritual_finale.tscn` *(proposed)*, or the `"main"` animation inside the ritual scene; first-person throughout:

1. **Loses consciousness:** already done at the end of 2.1; the scene starts in black.
2. **Wakes while being dragged:** the eyelids open in short blinks (black–blurred–black); the camera is ~0.4 m above the ground, looking up and back, moving backwards along `DragPath` with a jerky drag rhythm (step pulls + sway); the bonfire glow and the night sky flicker in view; the feet and boots of the dragging cultists at the edges of the frame; muffled audio that slowly clears; distant chanting.
3. **Several cultists drag him to the altar:** 2–3 cultists in `drag`/`walk`; the light grows as they approach the fire.
4. **Placed on the altar:** a black blink; the camera is lifted and laid at `AltarHead` (lying POV, looking up).
5. **Reveal of ~10 cultists:** the head turns slowly left and right (keyed camera rotation). Optional: allow limited mouse look (small yaw/pitch clamps) for agency during this moment.
6. **The bonfire lights the scene:** fire light and particles keyed up; the cultists `chant`.
7. **One cultist approaches with a knife:** `walk` → stands over the altar → `raise_knife`.
8. **Final moments in POV:** a slow push toward the blade; heartbeat; breathing; the chant stops; the last blink.
9. **Fade to black:** silence → end card `ui/end_screen.tscn` *(proposed)* (title, "Команда NARYN", Exit to menu) → `SceneFlow.change_scene(main_menu)`. Clear `SceneFlow.session`.

- The ending is **not skippable on the first playthrough** (optional decision); after that, `cutscene_skip` jumps to the end card.

**Step 2 — files modified:** `vehicle/car.gd` (the ending trigger replaces the placeholder message), `characters/maniac/maniac.gd` (deactivate for the ending), `levels/ritual/ritual.tscn`.
**New files** *(proposed)*: `cinematics/ending_capture.tscn`, `characters/cultist/cultist.tscn` (+ `cultist.gd` if needed), `levels/ritual/ritual.gd`, `cinematics/ritual_finale.tscn`, `ui/end_screen.tscn` (+ `.gd`).
**Missing assets to request:** knock-out hit, heartbeat, breathing, dragging on snow, chanting, fire crackle, knife.
**Expected result:** the complete game, main menu → drive → house → escape attempt → capture → ritual → end card → main menu, all with placeholder art.

---

# After Step 2

## Asset integration (when models and animations arrive) — Medium

- glTF 2.0 (`.glb`) pipeline; one folder per asset.
- **Maniac:** replace `maniac_model.tscn`'s content and keep `FaceAnchor`. This fixes both the AI maniac and the capture cutscene.
- **Cultists:** replace `Model` in `cultist.tscn`; the animations must use the Step 2.2 names (AnimationLibrary / retargeting).
- **Car:** replace `Model`; re-position the wheel pivots, the door pivot, the lights and the seat/exit markers.
- **House:** replace the CSG room by room, or bake it (CSG "Bake Mesh Instance" / "Bake Collision Shape"). **Re-bake the navmesh after every structural change** and re-test the maniac's patrol and stairs.

## Polish — Low

Forest → `MultiMeshInstance3D` (if profiling shows a need) · fewer shadow-casting lights · one UI `Theme` · separate volume sliders · subtitles · gamepad (cheap after the input actions) · localization · checkpoints (only if the house section becomes long).

## Explicitly not planned

A physics `VehicleBody3D` (decision 1), AI for cultists, a dialogue system, a quest framework, an event bus, a save system, third-party addons. Add any of these only when a concrete need appears.
