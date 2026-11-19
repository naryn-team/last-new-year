# CLAUDE.md — The Last New Year (Godot 4.7.2 / GDScript)

This is the primary instruction file for Claude Code sessions on this repository. Read it fully before changing anything.
This file and its companion documents live in **`.claude/`** (Claude Code loads `.claude/CLAUDE.md` automatically; Godot ignores hidden folders). Companion documents: **`PROJECT_AUDIT.md`** (detailed state of the code as of commit `37c74fa`, **before** the Step 0 refactor: its file paths are the old ones) and **`DEVELOPMENT_ROADMAP.md`** (three-step plan: Step 0 / 1 / 2). If the code and these documents disagree, **the code wins**: verify, then update the documents.

## 0. Start of every session — do this first

### 0.1 Git: the owner does all commits
**Never run `git commit`, `git push`, `git reset`, `git checkout`/`git switch`, `git stash`, `git rebase`, `git merge` or create branches.** The owner makes **one commit per roadmap step** himself. Read-only git commands are fine and expected (`git status`, `git log`, `git diff`, `git show`). `git mv` / `git rm` are allowed only where the roadmap calls for moving or deleting files (they only stage changes). At the end of each step, tell the owner the work is ready to commit and suggest a commit message.

### 0.2 Session start checklist

You are working **directly inside the project folder** (the folder that contains `project.godot`). There is no archive to extract and nothing to download. Everything is already on disk.

1. **Look at what is actually here.** List the project root and every folder inside it (`core/`, `gameplay/`, `player/`, `characters/`, `interactables/`, `vehicle/`, `cinematics/`, `ui/`, `levels/`, `audio/` and any new folders), skipping `.godot/`, `.git/` and `_source/`. Compare the result with §3. If files were added, removed or moved, the code wins: note the difference.
2. **Check what changed since the audit.** Run `git status` and `git log --oneline -15`. The audit describes commit `37c74fa`; this file describes the state after Step 0 (one owner commit on top of `37c74fa`). For every newer commit, read its diff (`git show --stat <hash>`, then the changed files) so you know what is new.
3. **Read the companion documents:** `PROJECT_AUDIT.md` (current state, known bugs) and `DEVELOPMENT_ROADMAP.md` (what to build next and in what order). The roadmap has three steps: **Step 0** (cleanup, refactoring, structure, architecture), **Step 1** (car, driving, road, exit from the car), **Step 2** (capture at the car + ritual ending). Find the first sub-step that is not finished yet; check this against the code, not just the documents.
4. **Read the files you will touch, before changing them,** plus every script that uses the same nodes, groups, flags or metadata (§5, "Runtime contracts").
5. **Then start the task.** If the user gave no specific task, propose the next unfinished roadmap step in a few sentences and wait for confirmation before making large changes.
6. **At the end of the work,** update §6 (status) and §12 (known issues) in this file if anything changed, and mark progress in `DEVELOPMENT_ROADMAP.md`.

---

## 1. Project overview

A first-person 3D atmospheric horror game. On New Year's Eve, Heathcliff ("Хит") Lone returns to his estranged family's remote house in a snowy valley. The family is gone. A cult (the "ЖАТВА ГРЕХОВ" — the Harvest of Sins) has taken them, and a masked stalker ("the Keeper"; called `Maniac` in code) hunts him inside the house. The player explores, reads notes, solves a safe puzzle, hides in wardrobes, gathers items to refuel the car and escape. The intended ending is a cult ritual "at the stone".

- Developer team name shown in the menu: "Команда NARYN".
- Repository: `github.com/Erbol05-bit/last-new-year`, branch `main`.
- All player-facing text and code comments are **Russian**. Git messages are English.

## 2. Technical stack

| Item | Value |
|---|---|
| Engine | **Godot 4.7.2** (`config/features = "4.7", "Forward Plus"`) |
| Language | GDScript only (no C#, no GDExtension) |
| Renderer | Forward+; Windows driver D3D12 (the team develops on Windows) |
| Physics | Jolt Physics (3D) |
| Navigation | NavigationRegion3D with a **pre-baked** NavigationMesh (house only), cell 0.1, source group `nav_source` |
| Autoloads | `Settings` → `res://core/settings.gd`, `SceneFlow` → `res://core/scene_flow.gd` |
| Addons / plugins | none |
| Input map | InputMap actions with **physical** keys in `project.godot` `[input]` (list in §5) |
| Audio buses | `default_bus_layout.tres`: Master → Music, Ambience, SFX, UI (all 0 dB) |
| Export presets | `export_presets.cfg`: **Windows Desktop** → `build/windows/TheLastNewYear.exe` (git-ignored). Export templates must be installed in the editor first (Editor → Manage Export Templates). |
| Tests | none (see §11 for headless verification) |

Never suggest switching engines, adding C#, or adding third-party addons unless the user asks.

## 3. Actual project structure

Layout after roadmap **Step 0** (all scene references use `uid=`; every `.gd` has its `.gd.uid`, every asset its `.import`).

```
project.godot              name "The Last New Year", version 0.2.0; main_scene = uid://b3slmqio8150c (ui/main_menu.tscn);
                           autoloads Settings, SceneFlow; [input]
README.md                  Public project description (features, controls, how to run/build, structure, credits)
icon.svg                   Project icon (night house with one lit window)
export_presets.cfg         Windows Desktop export preset
.claude/                   CLAUDE.md (this file), DEVELOPMENT_ROADMAP.md, PROJECT_AUDIT.md
default_bus_layout.tres    Audio buses Master → Music / Ambience / SFX / UI
core/
  settings.gd              Autoload Settings (user://settings.cfg; F11 = action toggle_fullscreen)
  scene_flow.gd            Autoload SceneFlow: change_scene() with fades, fade_out()/fade_in(), session {}
  ui_style.gd              class_name UIStyle (palette, fonts, menu_button, box)
gameplay/
  game.gd                  "Game" node: interaction raycast, inventory, flags, notes, drawings, objectives
player/
  player.tscn / .gd        First-person CharacterBody3D + player control API + footsteps
characters/maniac/
  maniac.tscn / .gd        Stalker AI (instances maniac_model.tscn as "Model")
  maniac_model.tscn        Primitive model (Robe, Hood, Mask, EyeL, EyeR) + FaceAnchor (Marker3D)
  jumpscare.wav
interactables/             door.gd, front_door_trigger.gd, pickup.gd, safe.gd, boards.gd, note.gd, hide_spot.gd
vehicle/
  car.tscn / car.gd        The car (Step 1): hollow CSG shell with window/door openings, glass, opening driver door,
						   interior, wheels, lights, audio slots, DriverHead (first-person) + chase camera, markers,
						   collision, Snowfall, IntroCutscene + ExitCutscene; interaction (refuel; ending placeholder)
  car_driver.gd            Driving model in road coordinates (steering, grip, edges) + fuel-out rolling stop (Car/Driver)
  cockpit_camera.gd        Driver's head: mouse look, look into turns, g-force lean, vibration (Car/DriverHead)
  car_dashboard.gd         Instrument cluster drawn in a SubViewport + radio clock (Car/Model/Interior/Dashboard)
  car_mirror.gd            Working rear-view mirror (SubViewport camera) (Car/Model/Interior/RearMirror)
  car_camera.gd            Optional chase camera, key C (Car/Cameras/ChaseCamRig)
cinematics/
  cutscene.gd              class_name Cutscene (framework)
  drive_intro.tscn         Establishing shot around the moving car (child of the car)
  car_exit.tscn            First-person exit from the car (child of the car; calls car.open_door/close_door)
ui/
  main_menu.tscn / .gd     Main menu (scene + code-drawn background)
  hud.gd                   HUD CanvasLayer (crosshair, prompt, message, inventory, objective, stamina)
  pause_menu.gd  settings_panel.gd  note_window.gd  keypad_window.gd
  cinematic_overlay.gd     class_name CinematicOverlay: letterbox, fade, eyelids
  game_over.tscn / .gd     Caught screen (Retry / Menu)
  fonts/                   amatic_sc_bold.ttf (titles), caveat.ttf (handwriting) + OFL licences
levels/world/
  world.tscn / world.gd    Gameplay root: ground (CSGBox3D), Player, WorldEnvironment, Level, wind ambience;
						   world.gd = start mode (drive / arrived / on foot) and the arrival sequence
  exterior_road.tscn/.gd   Forest road: RoadPath (Path3D, 1061 m, many turns incl. a hairpin), Road (CSGPolygon3D from the
                           same curve), RoadEnd, snow planes outside the 100x100 area; at runtime: roadside MultiMesh trees,
                           posts with reflectors, snow banks and a dashed centre line (only outside the area)
  level.tscn               THE level: house, exterior, car, interactables, Game node, Maniac, notes, navmesh
  tree.tscn                Primitive pine tree (instanced 180× in Exterior/Forest)
  flicker_light.gd         OmniLight3D flicker
levels/ritual/
  ritual.tscn / ritual.gd  Ritual "at the stone": altar, 7 pedestals, torches, bonfire, 10 cultists, snow, forest ring
                           (built at runtime); plays the Finale cutscene on load, then the end screen
characters/cultist/
  cultist.tscn / .gd       Scripted actor (not AI): Model + Head/Hand_L/Hand_R/KnifeSocket(Knife); animations idle,
                           chant, walk, drag, carry, raise_knife, stab; play_anim(), set_knife()
audio/ambience/            winter wind.ogg (loop on)
audio/sfx/                 footstep_snow.ogg, footstep_wood.ogg (hero, cut from the raw WAVs), footstep_maniac.ogg,
						   footstep_hero.ogg (Footsteps fallback stream, normally replaced at runtime)
_source/                   GIT-IGNORED, has .gdignore: winter wind home.aup4 + 3 raw freesound WAVs (sources only)
.godot/                    Editor cache (git-ignored). Never edit.
```

## 4. Scenes and their purposes

| Scene | Purpose | Notes |
|---|---|---|
| `ui/main_menu.tscn` | Main menu; Play → `SceneFlow.change_scene(world)` (clears `SceneFlow.session`) | Buttons wired by `[connection]` in the .tscn; fades itself in from black |
| `levels/world/world.tscn` | Gameplay root (script `world.gd`) | Player spawn (0, 1.26, 0) — used only with `start_mode = ON_FOOT`. Ground has a subtract hole at x=6, z=-22 matching the house basement. The wind autoplays on bus `Ambience`. |
| `player/player.tscn` | Player | Nodes: `CollisionShape3D`, `Head`, `Head/Camera3D` (current), `Head/Camera3D/Flashlight` (SpotLight3D), `Footsteps` (bus `SFX`) |
| `levels/world/level.tscn` | Entire playable level | Children: `Moon`, `Exterior` (Path = footpath, Road = `exterior_road.tscn`, Car = `vehicle/car.tscn` at (4, 0, 1) with `road = ../Road`, MapBorder, Forest — 166 trees, the road corridor is cleared), `House` (Structure, Rooms_F1, Rooms_F2, Rooms_B, PatrolPoints; groups `nav_source`, `surface_wood`), `Navigation`, `Interactive` (FrontDoor, FrontDoorTrigger, BasementDoor, BackDoorBoards, WorkshopDoor, WorkshopRoom), `Game`, `Maniac`, `Notes` |
| `levels/world/tree.tscn` | Tree prop | Primitive meshes + StaticBody3D |
| `levels/ritual/ritual.tscn` | Ending scene (script `ritual.gd`) | Floor (snow, 60×60), Altar (head end at -X: `AltarHead` (-0.75, 1.2, 0)), 7 Pedestals, 6 Torches, `Cultists` (Cultist1–7 in a ring r 3.4, Dragger1/2, Priest with knife), `Bonfire` (logs, `Flames`/`Embers` GPUParticles3D, `Light` with flicker, `Crackle` slot) at (0, 0, -2.7), `Snowfall`, `Audio` (Wind, `Chant` and `Heartbeat` slots — empty), `Finale` (Cutscene, 38 s, no restore). Generated by a throw-away Python script (keys as look directions); see the roadmap Step 2 notes before hand-editing the keys. |
| `characters/cultist/cultist.tscn` | Cultist actor | Forward -Z. Exports `animation` (start), `has_knife`, `random_start`. |
| `cinematics/ending_capture.tscn` | Capture at the car (12.5 s), child `CaptureCutscene` of the car | Car-space keys: get in, door, two `crank` attempts (dashboard/headlights flash), Keeper (`maniac_model.tscn`, ×0.82, on the rear bench) appears at 5.2 s, mirror (forced on), turn back, lunge, `HitSound` (jumpscare.wav), `hit`, eyelids close, audio muffled. `restore_on_finish = false`. |
| `ui/end_screen.tscn` | End card | Title, two lines, "Команда NARYN", «В главное меню»; clears `SceneFlow.session`, removes the muffle. |
| `characters/maniac/maniac.tscn` | Stalker | CharacterBody3D, `Model` (instance of `maniac_model.tscn`), `NavigationAgent3D`, `Footsteps` (→ `audio/sfx/footstep_maniac.ogg`, bus `SFX`) |
| `levels/world/exterior_road.tscn` | Road to the house | Built from straights and exact arcs (radii 18–45 m, a 170° hairpin, 130 m start straight for the intro, 100 m final straight). `RoadPath` starts at (502, 0, 542), ends at the parking spot (4, 0, 1) heading -Z. Generated by a turtle script (see `DEVELOPMENT_ROADMAP.md` Step 1 notes); edit the curve only together with the forest clearing. |
| `vehicle/car.tscn` | The hero's car | Forward = -Z. `Driver`; `Model/Shell` (CSGCombiner: Lower + Upper minus Cavity, windshield/rear/side window holes and `DoorHole`); glass quads; `Model/DoorFL_Pivot/Door` (CSG door with window, armrest, handles); `Model/Interior` (floor, dash, `Dashboard/Cluster`, `DashGlow`, `Radio/Clock`+`Station` Label3D, console, gear lever, seats, rear bench, visors, `RearMirror` (`Frame`, `Glass`, `Eye`), `SteeringWheel/Spin` (rim, hub, spokes, `TopMark`) + `Column`); `Wheels/FL,FR,RL,RR/Spin/Tire`; `Lights`; `Audio` (**empty streams**); `Cameras/ChaseCamRig/Camera3D`; `DriverHead/Camera3D` (first-person, default); `DriverSeat`, `DriverExit` (-1.8, 0, 0.5); `Collision`; `Snowfall` (GPUParticles3D); `IntroCutscene`, `ExitCutscene`. Group `car`. |
| `cinematics/drive_intro.tscn` | Intro shot (4.5 s) | Camera keys in car space, ends outside the left rear window; blends (1.2 s) into the driver's head |
| `cinematics/car_exit.tscn` | Exit from the car (5.6 s) | `blend_in_time` 1.2 from the driver camera, door Call Method keys, ends at `DriverExit` eye height, `return_to_player` |
| `characters/maniac/maniac_model.tscn` | Maniac look (shared by the AI and future cutscenes) | `FaceAnchor` Marker3D at the mask; replace the meshes, keep the anchor |
| `ui/game_over.tscn` | Caught screen | Retry → world, Menu → main menu (both via `SceneFlow`) |

## 5. Scripts and responsibilities

| Script | Responsibility |
|---|---|
| `player/player.gd` | Walk/sprint (stamina, forward only)/crouch (capsule resize + ceiling ray)/jump/flashlight/mouse look/head bob; `noise_radius` for the AI; footsteps by distance (snow outside, wood on `surface_wood`). **Control API:** `set_control_enabled()/is_control_enabled()` + signal `control_changed`, `set_hidden(spot or null)`, `set_dead()`, `set_body_enabled()`, `set_flashlight()/is_flashlight_on()`, `teleport_to(Transform3D)`, `get_camera()`, `get_head()`. Properties `is_hidden`, `hide_spot`, `is_dead`. |
| `gameplay/game.gd` | In group `game`. Camera raycast (2.3 m) to find interactables; action `interact`; inventory `items`; `flags`; `notes_read`; `drawings` (`drawings_total` counted deferred); creates `hud`, pause menu, note window, keypad. `show_message()`, `set_hud_visible()/is_hud_visible()`, `set_interaction_enabled()/is_interaction_enabled()`, `set_objective_visible()` (hidden while driving). Objective text = if/elif chain on flags/items. |
| `ui/hud.gd` | HUD display only: `set_prompt`, `show_message`, `set_inventory`, `set_objective`, `set_objective_visible`, `set_crosshair_visible`, `set_stamina`, `hide_stamina`. Layer 5. |
| `core/settings.gd` | Autoload. Sensitivity, master volume (Master bus), fullscreen (default **on**), `toggle_fullscreen`; save/load ConfigFile; `changed` signal. |
| `core/scene_flow.gd` | Autoload. `change_scene(path, out := 0.6, in := 0.6)`, awaitable `fade_out()/fade_in()`, `is_busy()`, `session` dictionary that survives scene changes, `set_muffle(cutoff_hz, time)` (low-pass on Master, survives scene changes; `MUFFLE_OFF` removes it). Black overlay on layer 100, works while paused. |
| `ui/settings_panel.gd` | Settings controls block; used by the main menu and the pause menu. |
| `core/ui_style.gd` | `UIStyle` constants (NIGHT, RED, UMBER, BONE, PAPER, INK, CRAYON colours) and helpers. |
| `ui/pause_menu.gd` | `pause` → pause, settings, exit to menu (stays paused during the fade; the menu unpauses). Disabled while the player `is_dead`, during `SceneFlow` transitions and while a cutscene plays. |
| `ui/note_window.gd` | Pauses the game; shows hand/print text or a procedural child's drawing with a digit. Closes on `interact`/`pause`/Space/Enter/click. |
| `ui/keypad_window.gd` | Pauses the game; 4-digit entry (digit keys stay raw keycodes); `interact`/`pause` close; emits `solved`. |
| `interactables/door.gd` | Hinge door (node = pivot, child CSG = panel). Lock/key/unlock flag, `slam_and_lock()`, bolt trap (`has_bolt`, `room_path` Area3D) that calls `maniac.trap()`; `break_open()`. Group `door`. |
| `interactables/front_door_trigger.gd` | On player entry: slams and locks the front door, sets the `front_locked` flag. |
| `interactables/pickup.gd` | Adds an item and frees itself. |
| `interactables/safe.gd` | Opens the keypad (code `4817`); gives `basement_key` and the father's letter. |
| `interactables/boards.gd` | Needs `crowbar`; sets `boards_removed`; frees itself. |
| `vehicle/car.gd` | Group `car`. Signal `ending_requested` (emitted by "сесть в машину" when fuelled; `world.gd` listens). `crank()`, `set_mirror_forced()`. Interaction: "Бак пуст" → refuel with `canister` → `car_fueled` → **placeholder message, no ending**. `state` DRIVING / STOPPING / PARKED; `start_drive()` (first-person camera, ignition, engine, headlights, snow), `park()`, `set_ignition()` (dashboard), `set_engine_running()`, `set_headlights()`, `set_brake_lights()`, `set_snow()`, `sputter()`, `flicker_off_headlights()`, `open_door()/close_door()`, `get_seat_transform()`, `get_exit_transform()`, `get_look_target()`; action `car_camera` (C) toggles cockpit / chase view while driving; turns the mirror on only in the cockpit view. Export `road`. |
| `vehicle/car_driver.gd` | Kinematic bicycle model in road coordinates: `distance` s, `offset` x (+ right), `heading` psi (+ nose left), `steer` (front-wheel angle, + left). Steering is rate-limited (`steer_rate` 2.6, `return_rate` 3.0 rad/s) and speed-sensitive (`max_steer_slow` 0.7 → `max_steer_fast` 0.3 rad); turn rate `speed·tan(steer)/wheelbase` (`wheelbase` 2.35 — tuned shorter than the model for a tighter turn), limited by `grip` 12.5 m/s² (understeer); steering wheel = `steer × steering_ratio` (7); the car must be steered through turns. Edges: offset clamped, nose turned along the bank, speed lost, signal `bumped`. No reverse; idle creep 2.5 m/s; cruise 14 / max 25 m/s (90 km/h). Gauges: `speed`, `rpm`, `gear` (auto, `gear_tops`), `fuel` (0.12 → 0 at the fuel-out point). `fuel_out_distance` (85 m) before the end → signal `fuel_out`, control taken, uniform deceleration to exactly the road end (offset and heading ease to 0) → signal `stopped`. Drives `Model` roll/pitch, wheel spin/steer and `SteeringWheel/Spin` (`steer × steering_ratio`). `autopilot` for the intro. |
| `vehicle/cockpit_camera.gd` | On `DriverHead`: mouse look (yaw ±110°, pitch −50…+35°, recentres after 1.5 s); the view never turns or rolls by itself (owner's request) — only a small head shift from lateral/longitudinal g, speed vibration, shake on `bumped`. Active only while its camera is current. |
| `vehicle/car_dashboard.gd` | On `Model/Interior/Dashboard`: draws tachometer, speedometer (km/h) with odometer and gear, fuel and temperature gauges and warning lamps (fuel, battery, oil, handbrake, headlights) into a SubViewport shown on `Cluster`; radio clock from `start_time` (23:31); `set_powered()` (ignition) also toggles `DashGlow`. |
| `vehicle/car_mirror.gd` | On `RearMirror`: SubViewport camera at `Eye` looking back, mirrored onto `Glass`; `active` (renders only when true). |
| `vehicle/car_camera.gd` | Optional chase camera (key C): `top_level`, smooth follow behind/above, looks at the road 14 m ahead; `snap()`. |
| `levels/world/exterior_road.gd` | Road API used by the driver: `get_length()`, `get_frame(d)` (global; -Z forward, +X right), `get_curvature(d)` (+ = left), `half_width`. Builds roadside MultiMesh trees (from `tree.tscn` meshes) and posts on `_ready`. |
| `levels/world/world.gd` | Ending: on `car.ending_requested` → `maniac.vanish()`, player control off, `Car/CaptureCutscene`, `session.ending = true`, black hold 1.5 s, `ritual_scene`. `start_mode` AUTO / DRIVE / ARRIVED / ON_FOOT (AUTO: `SceneFlow.session.arrived` → ARRIVED, else DRIVE). Arrival sequence: player in car (control/body off, follows `DriverSeat`), intro, player drives, fuel message, stop, engine off, headlights flicker off, exit cutscene, player on foot, `session.arrived = true`. |
| `interactables/note.gd` | Readable note; `kind` = hand / print / drawing (drawings join group `note_drawing`). |
| `interactables/hide_spot.gd` | Wardrobe: player inside (via the player API), looking through a slit (yaw locked, pitch ±20°); the maniac can open the doors. `static var hidden_in`. |
| `levels/world/flicker_light.gd` | Random light energy. |
| `characters/maniac/maniac.gd` | AI states PATROL / INVESTIGATE / CHASE / SEARCH / CHECK_HIDE / TRAPPED; activates `start_delay` (25 s) after flag `front_locked`; sight (FOV, range, raycast; farther when the flashlight is on); hearing via `player.noise_radius`; auto-opens unlocked doors; avoids the basement until `basement_open`; `set_ai_paused()` / `ai_paused` (cutscenes); `vanish()` (ending); jumpscare positioned by `Model/FaceAnchor` → `SceneFlow.change_scene(game_over)`. `@export var debug` prints state changes. |
| `cinematics/cutscene.gd` | `class_name Cutscene`. Root of a cutscene scene: `AnimationPlayer` with `"main"`, `Camera3D`, markers. `play()` disables player control / HUD / interaction, pauses the maniac AI, switches camera, letterbox; hold `cutscene_skip` (0.8 s) seeks to the end (value tracks applied, **Call Method keys are not called on skip**); on finish blends back to the player camera (`blend_back_time`), restores everything, emits `finished`. Call Method helpers: `close_eyes`, `open_eyes`, `blink`, `fade_to_black`, `fade_from_black`, `say(text, seconds)` (subtitle), `hit(strength)` (red flash + camera shake), `muffle(cutoff_hz, time)`. Static `blend_camera(from, to, time)`. Exports also `blend_in_time` (blend from the previous camera into frame 0) and `return_to_player` (end on the player camera instead of the previous one). `blend_camera` follows a moving target. All null-safe (works without Game/player). |
| `ui/cinematic_overlay.gd` | `class_name CinematicOverlay`, layer 15: `set_letterbox()`, `close_eyes()`, `open_eyes()`, `blink()`, `fade_to_black()`, `fade_from_black()`, `say()`, `flash()` (awaitable). |
| `ui/game_over.gd` | Builds the subtitle and wires the buttons. |
| `ui/end_screen.gd` | End card built in code (texts fade in one by one). Export `lines`. |
| `levels/ritual/ritual.gd` | Hides the mouse, closes the eyes (overlay) before the first frame, muffles audio if opened directly, builds a ring of trees from `tree.tscn`, plays `Finale`, then `SceneFlow.change_scene(end_screen, 0, 2)`. |
| `characters/cultist/cultist.gd` | Plays the start animation (random offset for loops), `play_anim(name, blend)`, `set_knife(on)`. |

### Runtime contracts (stringly-typed; renaming any of these breaks things silently)
- **Interaction protocol:** any node (or ancestor of the hit collider) with `get_prompt(game) -> String` **and** `interact(game)` is interactable. The `game` argument is the Game node.
- **Groups:** `player`, `game`, `maniac`, `door`, `hide_spot`, `patrol_point`, `patrol_basement`, `note_drawing`, `nav_source` (navmesh bake), `surface_wood` (floor sound = wood; on `House`), `cutscene_playing` (while a `Cutscene` plays), `car`. Cultist animation names: `idle`, `chant`, `walk`, `drag`, `carry`, `raise_knife`, `stab`.
- **Player:** other scripts use only the API in §5 (no metadata, no `set_physics_process` from outside). Node paths `Head`, `Head/Camera3D`, `Head/Camera3D/Flashlight`, `CollisionShape3D`, `Footsteps` stay as they are.
- **Maniac model:** `Model/FaceAnchor` (maniac.gd jumpscare).
- **Input actions:** on foot `move_forward/back/left/right`, `sprint`, `crouch`, `jump`, `flashlight`, `interact`, `pause`, `toggle_fullscreen`; car `car_accelerate`, `car_brake`, `car_steer_left/right`, `car_handbrake`, `car_camera` (C, cockpit/chase) (used); `car_horn`, `car_lights` (defined, unused); `cutscene_skip` (Space / Esc, hold).
- **Audio buses:** `Master`, `Music`, `Ambience`, `SFX`, `UI`.
- **SceneFlow.session keys:** `arrived` (set by `world.gd` after the exit cutscene; cleared by New Game and the end card), `ending` (set before the ritual; `ritual.gd` checks it).
- **Car:** node names used by code — `Driver`, `Model`, `Model/DoorFL_Pivot`, `Model/Interior/Dashboard` (+`Cluster`, `../DashGlow`, `../Radio/Clock`), `Model/Interior/RearMirror` (+`Eye`, `Glass`), `Model/Interior/SteeringWheel/Spin`, `Wheels/*/Spin`, `Lights/*`, `Audio/Engine`, `Audio/Door`, `Cameras/ChaseCamRig/Camera3D`, `DriverHead/Camera3D`, `DriverSeat`, `DriverExit`, `Snowfall`, `IntroCutscene`, `ExitCutscene`. The parked transform is the road end; `RoadPath` must end at the parking spot heading -Z.
- **Flags:** `front_locked`, `safe_seen`, `safe_open`, `basement_open`, `boards_removed`, `car_fueled`.
- **Item ids:** `crowbar`, `basement_key`, `canister`.
- **Gameplay tuning:** player walk 4.0 / sprint 6.5 / crouch 2.0; maniac walk 2.0 / chase 4.5. The AI is balanced against these numbers. Do not change them unless asked.

## 6. Current implementation status — READ THIS BEFORE WRITING CODE

### 6.1 EXISTS AND WORKS — preserve it; do not break it, do not "rewrite for cleanliness"
Main menu · Settings (persisted) · Pause menu · Player controller (walk/sprint/stamina/crouch/jump/flashlight/head bob/noise) · Interaction raycast & prompts · Inventory & flags & objective text · HUD · Notes, letters, procedural drawings · Safe keypad puzzle · Doors (lock/key/slam/bolt trap) · Front-door slam trigger · Boarded back door · 5 wardrobe hide spots · Maniac AI (verified at runtime: activates, navigates stairs, chases, catches) · Jumpscare & game-over screen · Baked navigation in the house · The full gameplay chain up to refuelling the car.
**Added in Step 0 (verified headless):** InputMap actions (physical keys) · player control API · HUD split (`ui/hud.gd`) + HUD/interaction toggles · `SceneFlow` (fades on all 5 scene changes, `session`) · audio buses · maniac model scene with `FaceAnchor` · cutscene framework (`Cutscene`, `CinematicOverlay`: letterbox, fade, eyelids, skip, camera blend, maniac AI pause) · hero footsteps (snow/wood) · looping wind.
**Added in Step 1 (verified headless):** road to the house (1061 m, many turns) with banks, dashes, posts · car scene with a hollow cabin and interior · **first-person driving** with a real steering model (rate-limited, speed-sensitive steering, grip limit, edges) · animated steering wheel · working instrument cluster (speed, rpm, gear, fuel, temperature, lamps), radio clock, working rear-view mirror · driver head motion (no automatic view rotation) · optional chase view (C) · headlights / tail + brake lights / interior light / dash glow · snowfall around the car · wheel spin and steering · intro shot (skippable) · fuel runs out → rolling stop exactly at the old car spot · first-person exit cutscene (door opens/closes) · New Game starts in the car; Retry starts on foot at the parked car.
**Added in Step 2 (verified headless):** ending — capture at the car after refuelling (Keeper in the back seat, seen in the mirror), ritual scene with 10 cultists and a bonfire, first-person ritual cinematic, end card → main menu; audio muffle (`SceneFlow.set_muffle`), subtitles / red flash / camera shake in cutscenes. **The game can be played from the main menu to the end card.**

### 6.2 PLACEHOLDER — exists, but will be replaced; do not polish, and do not make code depend on its exact geometry
- **House**: CSG blockout (≈200 CSGBox3D). Gameplay-complete, art placeholder.
- **Car model**: CSG shell (hollow, with openings), box interior, cylinder wheels in `vehicle/car.tscn` → `Model`. Replace `Model`, then re-position wheel pivots, `DoorFL_Pivot`, lights, `DriverHead`/`DriverSeat`/`DriverExit`, the mirror `Eye`, the cluster quad and the camera keys of both cutscenes.
- **Maniac model**: primitives in `characters/maniac/maniac_model.tscn`. Code uses `FaceAnchor` only; swap the meshes and keep the anchor.
- **Trees**: primitive cones.
- **Ritual scene / cultists**: primitive capsule-and-cone cultists with transform-only placeholder animations; real models must keep the animation names and anchors. The bonfire is particles on quads. `Chant`, `Heartbeat`, `Crackle` audio slots are empty.
- **Exterior**: flat 100×100 m ground with an invisible border (the car passes through the south wall; on foot it still blocks); a 12.9 m footpath; a flat placeholder road with snow planes, MultiMesh primitive trees and posts outside the area.
- **Car audio**: `Audio/Engine`, `EngineOneShots`, `Door`, `Tyres` exist with **no streams** (sputter is visual only: headlight dips).
- **Hero footstep sounds**: one snow and one wood step cut from the raw WAVs (pitch-randomised). Not listened to by Claude; the owner should judge them.

### 6.3 PLANNED — does NOT exist; never assume it exists, never call it, never "fix" references to it
- Engine / door / tyre sounds (assets missing; the tachometer `rpm` is ready to drive an engine loop) · horn / lights keys (actions exist, unused) · chant / heartbeat / fire / blow sounds (slots exist) · real cultist/maniac/car/house models · any character animation · save/checkpoints · localization · gamepad · key remapping UI · export presets.

If a task needs something from 6.3, build it as part of the task (following the roadmap's order) or ask. Never write code that silently expects it.

## 7. Planned features (summary — details in DEVELOPMENT_ROADMAP.md)

**Step 0 — cleanup, refactoring, structure, architecture — DONE** (no new features; gameplay stayed identical): remove `last-new-year/` and unused source audio; fix the known bugs; re-save scenes in the editor (owner); move files into the new folder layout; InputMap actions; player control API; split HUD out of `game.gd`; `SceneFlow` autoload (fades + `session` dictionary); audio buses; separate maniac model scene with `FaceAnchor`; cutscene framework (`Cutscene` + cinematic overlay with eyelids); hero footsteps.

**Step 1 — car, driving, road, exit — DONE:** New Game starts behind the wheel. The player drives along a forest road to the house (**road-follow arcade driving**: speed + sideways offset along a `Path3D`, clamped to the road; no `VehicleBody3D`). The car has headlights, tail/brake lights, an interior light, wheel spin, engine audio slots and **first-person driving** (owner's request; chase view on C). Near the house the fuel runs out (this matches the lore), control is taken, and the car rolls to a stop at the fixed parking spot. A first-person exit cutscene follows (seat → door opens → out → door closes), then today's gameplay. Retry after a death skips the drive (`SceneFlow.session.arrived`).

**Step 2 — ending — DONE:** after refuelling, "сесть в машину" starts a **scripted** capture cutscene at the car (the AI maniac is disabled; a cutscene copy of the maniac model appears, e.g. in the back seat; blow; eyelids close). Then the ritual scene: wake while being dragged → placed on the altar → ~10 cultists around a bonfire → a cultist approaches with a knife → first-person final moments → fade to black → end card → main menu. Cultists are scripted actors (`cultist.tscn` with named placeholder animations), not AI.

**Decisions already taken** (see the roadmap's "Decisions" section): road-bound arcade driving; the fuel runs out at the house; first-person exit; the catch at the car is scripted; **being caught inside the house still goes to the game-over screen**; the ritual is a separate scene; Retry skips the drive. If the user changes any of these, update the roadmap and this section.

## 8. Architecture & coding conventions (match the existing code)

- **Indentation: tabs.** UTF-8, LF line endings (`.gitattributes` enforces `eol=lf`).
- `snake_case` files, functions and variables; `PascalCase` node names and `class_name`; ids and flags are lowercase snake strings.
- Private members start with `_`. Public tunables use `@export` with `@export_group` (Russian group names are fine).
- `##` doc comment at the top of each script describing its role, plus `##` after exported vars. Comments are **in Russian**, to match the codebase. Code comments explain *what the code does*; they never mention roadmap steps, sessions, the owner, other games or "later/temporary" notes — that belongs in `.claude/` docs (the code is shown publicly). Player-facing strings are **Russian**.
- Use static typing where it is natural (`var x := 0.0`, `-> void`, typed arrays). Untyped duck-typed calls on the `game`/`player` parameters are the existing style and acceptable.
- UI is **built in code** (`CanvasLayer` + Controls) using `UIStyle` colours and fonts. Prefer `UIStyle.menu_button()` / `UIStyle.box()` over new ad-hoc styling.
- New interactables implement the `get_prompt(game)` / `interact(game)` protocol. Do not invent a second interaction mechanism.
- Find shared nodes the existing way: `get_tree().get_first_node_in_group("game" | "player" | "maniac")`. Null-check them: scenes such as `ritual.tscn` will not have a Game node.
- Windows that pause the game set `process_mode = PROCESS_MODE_ALWAYS` and guard against closing on the same frame that opened them (`Engine.get_process_frames()` pattern). Reuse that pattern.
- Story progression: set flags via `game.set_flag()`, and extend `game._update_objective()` for new objectives.
- **New systems:** add the smallest thing that serves the current roadmap step. No event buses, managers or frameworks "for later".
- **New assets:** put each new system in its folder from the Step 0.2 layout (`vehicle/`, `cinematics/`, `characters/…`). Every `.gd.uid` / `.import` file must stay next to its source file (and be left for the owner to commit with it).
- **Replaceable art:** every new character or prop scene has a `Model` child plus named `Marker3D` anchors; code references anchors, never mesh offsets.

## 9. Development principles

1. **Read before you write.** Open every file you will change, and every script that references the nodes, groups, metadata or flags involved (use §5's contracts list; grep the whole repo excluding `.godot/` and `_source/`).
2. **Preserve behaviour.** Refactors must be behaviour-neutral and verified with the regression checklist (§11.3). If behaviour must change, say so explicitly.
3. **Incremental.** One roadmap sub-step per change. No mass renames and no file moves (the Step 0.2 layout is done; if a move is ever needed: `git mv` with the `.uid`/`.import` sidecars, grep every old `res://` path, validate headless).
4. **Dependencies first.** Do not start Step 1 before Step 0 is complete (input actions, player API, HUD split, SceneFlow, cutscene framework), and do not start Step 2 before Step 1.
5. **Do not invent.** No made-up files, nodes, assets, autoloads or engine APIs. If unsure whether a Godot 4.7 API exists, check the class reference or test it headless.
6. **Do not assume assets.** No model, animation or sound exists beyond what §3 lists. Use primitives, and leave clearly named empty slots (e.g. an `AudioStreamPlayer3D` with no stream) for missing assets.
7. **Keep the docs true.** When a feature moves from PLANNED to PLACEHOLDER/WORKS, update §6 of this file (and the roadmap status) in the same change.

## 10. Inspecting and modifying files

### Scripts (`.gd`)
- Edit freely, following §8. Keep public members other scripts read (`noise_radius`, `stamina`, `stamina_max`, `exhausted`, `stand_eye`, `is_crouching`, `active`, `caught`, `is_open`, `locked`, …).
- New script → Godot creates the `.uid` sidecar on the next editor or headless import. Run the import (§11.1) so the `.uid` is created; leave it for the owner's commit.

### Scenes (`.tscn`) — text-editing rules (Claude Code cannot use the editor GUI)
- Prefer small, surgical edits. `levels/world/level.tscn` is large (548 nodes). Read the relevant blocks, not the whole file.
- Preserve the header, existing `ext_resource`/`sub_resource` ids, and node `unique_id=` values. New `id`s must be unique within the file. A new node may omit `unique_id` (`main_menu.tscn` has none and loads fine); the editor adds them on re-save.
- `parent="..."` paths are relative to the scene root (`"."` = root). Node names must be unique among siblings.
- All scenes have `uid=` headers and reference each other by UID + path. Code still uses `res://` path strings (preloads, `SceneFlow.change_scene`), so do not move or rename `.tscn`/`.gd` files without updating every reference (grep for `res://<path>`). A new scene written by hand has no `uid=`: generate one with `ResourceUID.id_to_text(ResourceUID.create_id())` (headless `-s` script) and put it in the header.
- **Never hand-edit** `NavigationMesh` vertices/polygons or anything in `.godot/`.
- After changing the `House` geometry, the navmesh must be **re-baked in the editor** (select `Navigation` → Bake NavigationMesh). Tell the user if a change requires this; you cannot do it by text editing.
- Prefer creating **new scenes** for new systems (car, cutscenes, cultists) and instancing them, rather than growing `level.tscn`.
- After every scene edit, validate with the headless import and a headless run (§11).

### `project.godot`
- Input actions, autoloads and the bus layout exist (Step 0.3). Keep the existing keys intact; add new actions in the same physical-key format. Prefer editor-generated formats; if writing by hand, match Godot's serialisation exactly and validate headless.

### Assets
- Do not delete or re-encode audio or fonts unless asked. Raw sources live in the git-ignored `_source/`.

### Tasks only the owner can do (in the Godot editor) — ask for them, do not fake them
- Re-saving scenes in the editor when a scene needs normalising (done once in Step 0.1).
- Re-baking the navmesh after any change to `House` geometry.
- Moving files in the FileSystem dock (preferred for any future move; otherwise follow the `git mv` rules).
- Listening to audio, judging lighting and visuals, and playing the game for feel; headless runs cannot check any of these.
When a task needs one of these, stop at that point, tell the user exactly what to do, and continue after they confirm.

## 11. Testing & debugging

**Godot on the owner's machine:** the console wrapper `C:\godot_game_engine\Godot_v4.7.2-stable_win64_console.exe` only works if `Godot_v4.7.2-stable_win64.exe` sits **in the same folder** (it is currently on the Desktop, so the wrapper prints "Main executable … not found"). The main executable works directly; its output is captured when redirected to a file:
```bash
GODOT="$HOME/Desktop/Godot_v4.7.2-stable_win64.exe"   # Git Bash; $HOME = the user folder
"$GODOT" --headless --editor --quit --path . > "$TEMP/godot_log.txt" 2>&1; cat "$TEMP/godot_log.txt"
```
(If the owner copies the main exe next to the console wrapper, use the wrapper instead.) All commands run from the project root. Wrap long runs in `timeout 200` — a script that fails to compile never reaches `quit()` and hangs. **Never kill Godot processes by name**: the owner's editor may be open.

### 11.1 Import + parse check (run after every change)
```bash
"$GODOT" --headless --editor --quit --path .
```
Expected output contains no `ERROR` / `SCRIPT ERROR`. Right after moving files, the first editor run may print one stale autoload error from the `.godot` cache; a second run must be clean.

### 11.2 Smoke-run scenes headless
```bash
"$GODOT" --headless --path . --quit-after 120                                     # main menu
"$GODOT" --headless --path . res://levels/world/world.tscn --quit-after 600       # gameplay
"$GODOT" --headless --path . res://levels/ritual/ritual.tscn --quit-after 60
"$GODOT" --headless --path . res://ui/game_over.tscn --quit-after 60
```
Possible baseline noise on quitting `world.tscn`: "4 ObjectDB instances were leaked / 2 resources still in use" (the autoplaying wind stream; it does not appear on every run). Quitting **in the middle of the drive** (the 600-frame smoke run does) gives up to "8 ObjectDB / 3 resources" plus a `PagedAllocator ... BucketMedium` line — the arrival coroutine is still awaiting. Anything else is new.
Note: `--check-only --script res://file.gd` reports false "Identifier not found: Settings" errors because autoloads are not loaded in script mode. Use 11.1 instead.

### 11.3 Manual regression checklist (the user runs this in the editor; list which items your change affects)
1. Menu fades in; Settings opens/closes; Play fades to the world (and the world fades in).
1a. **Drive (New Game):** intro shot around the car (hold Space/Esc skips) → blends into the driver's head → W/S accelerate/brake, A/D steer (the steering wheel turns smoothly, the car needs steering through every turn, brake before sharp ones), Space handbrake (brake lights, "(P)" lamp), mouse look, C chase view and back; speedometer, tachometer, gear, fuel needle near E with the amber lamp, clock 23:31+; rear-view mirror shows the road behind; snow in the headlights; hitting a bank shakes the camera and slows the car but never leaves the road; Esc pauses. About 85 m before the house: message "Мотор закашлял…", headlights dip, the car coasts on the final straight and stops at the parking spot; red battery/oil lamps, headlights flicker off, the dashboard goes dark; exit cutscene (door opens, step out, door closes) → normal control, objective "Дойти до дома".
2. WASD/arrows, Shift sprint (stamina bar, exhaustion), Ctrl crouch under a low ceiling, Space jump, F flashlight, mouse look. Footsteps: snow outside, wood in the house, quieter when crouching.
3. Car prompt "Бак пуст"; the car blocks walking; walk the footpath; entering the hall slams and locks the front door (objective changes).
4. ~25 s later the maniac appears, patrols, hears sprinting, chases, opens doors.
5. Hide in a wardrobe (slit view, yaw locked, flashlight off/restored); maniac checks it; exit with E.
6. Bolt trap: lure the maniac into the workshop, bolt it, it breaks out after ~15 s.
7. Read notes and the 4 drawings ("x из 4"); safe code 4817 → basement key + letter; basement door; canister; crowbar; boards.
8. Refuel the car; "E — сесть в машину" → capture cutscene (door, two cranks with dashboard/headlights, the Keeper appears in the rear-view mirror, turn back, scream, red flash, eyes close, sound muffles) → black → ritual (wake while dragged with blinks, muffled sound clears; on the altar; head turns: ring of cultists, bonfire flares; subtitles; priest with a knife raises it; «С Новым годом, Хитклифф.»; black) → end card → «В главное меню». Holding Space/Esc skips each cutscene.
9. Caught → jumpscare (mask right in front of the camera) → game over fades in → Retry (starts on foot next to the parked car, no drive) and Menu (Play again → drive) both work.
10. Esc pause/resume/settings/exit to menu (fades); F11 fullscreen.
11. The wind keeps playing after 6 minutes (loop).

### 11.4 Probe scenes for automated checks
For logic checks, create a temporary probe scene (e.g. `res://_probe/…`) and **delete it afterwards**: a `Node` whose script instantiates `res://levels/world/world.tscn`, awaits physics frames, drives input with `Input.parse_input_event()` (set both `keycode` and `physical_keycode`), asserts state, prints results and calls `get_tree().quit()`. Note that the player spawns 1.26 m up and needs ~45 physics frames to land. A helper node added to `get_tree().root` survives scene changes (to follow game over → Retry → menu). Step 1 probes used `Engine.time_scale = 4` and a "bot driver" that feeds analog values into the `car_*` actions (`Input.action_press(action, strength)`: steer by road curvature ahead, brake to `sqrt(grip·0.75/k)`), and checked offsets, the steering wheel ratio, gears, fuel, the exact parked transform, the C toggle, mirror/dashboard power, the exit, Retry. Note: `--editor --quit` does **not** report GDScript parse errors — only the smoke runs (11.2) do. Step 0 was verified this way: input actions, flashlight, pause, door slam, maniac activation, notes, keypad 4817, wardrobe, footsteps surface, cutscene play/skip/restore, catch → game over → Retry → pause → menu. Never leave probe files in the repo unless the user asks for a tests folder.
To generate engine-formatted data (input map, bus layout, new UIDs) run a throw-away `extends SceneTree` script with `-s` and delete it; `ProjectSettings.save()` writes input events with `"device":16` — replace with `-1` (all devices).

### 11.5 Warnings
As of Step 0 there are **0** default-enabled GDScript warnings. To check: temporarily put an `override.cfg` in the project root with a `[debug]` section setting each `gdscript/warnings/<name>=2` (error), run 11.1/11.2, then **delete `override.cfg`**. New code must not add warnings.

### 11.6 Debug aids that exist
- `Maniac.debug = true` (inspector export) prints state changes, catch, unstick and give-up events.
- Shorten the maniac start for testing via its exports `start_delay` / `start_flag` on the `Level/Maniac` instance. Do not leave debug values in the files.

## 12. Known issues & limitations (after Step 2)

- **No gamepad, no key remapping UI** (actions exist, so both are cheap now).
- `HideSpot.hidden_in` is a static var reset manually in `game._ready()`; any new entry point into gameplay must keep that reset.
- `world.tscn`'s ground hole is hardcoded to the house basement position.
- The navmesh covers only the house; the maniac cannot follow the player outside (by design today).
- `Cutscene` skip does not fire Call Method keys between the current time and the end; put state changes in value tracks or in a `finished` handler.
- Hero footsteps use a single snow and a single wood sample (pitch-randomised); `audio/sfx/footstep_hero.ogg` is only the fallback stream. Volumes/step lengths are first guesses (exports in `player.gd`).
- The capture and ritual cinematics (camera moves, timing, subtitles, cultist poses, bonfire look) were authored by numbers only, never seen — the owner must judge them. Their keys are generated from look directions; small tweaks can be made in the editor's Animation panel.
- The driving feel (`car_driver.gd` exports: `steer_rate`, `grip`, `max_steer_*`, speeds), head motion (`cockpit_camera.gd`), gauge look (`car_dashboard.gd`), light levels, the intro/exit camera moves and the drive length (~80 s for a careful driver) were tuned by numbers only, never seen — the owner must judge them.
- Performance of the cockpit: two SubViewports (cluster 768×320 2D, mirror 320×96 3D — the mirror renders only in the cockpit view), 1500 snow particles, the 1061 m CSG road. Not profiled.
- Exiting a wardrobe teleports without a free-space check (audit B7).
- The game starts **fullscreen** by default (`Settings.fullscreen = true`).
- Git history still contains the 66 MB `.aup4` and the raw WAVs (removal only stops further growth).
- Performance has not been profiled. Watch CSG count, 11 shadow-casting omni lights, 164 non-instanced trees, the 1061 m CSG road (rebuilt on load) and the shadowed headlight.

## 13. Do / Don't quick list

**Do:** read the related files first · keep changes small · follow the roadmap order · use the interaction protocol, groups and the player API · null-check `game`/`player` · use primitives plus anchors for missing art · validate headless after every change · update §6 when status changes · ask the user before changing any decision listed in §7.

**Don't:** touch `.godot/` or `_source/` · hand-edit navmesh data · rename shared nodes, groups, flags, item ids, input actions or public members casually · manipulate the player from outside its API · retune player/maniac speeds · move files casually (keep the Step 0 layout) · add addons, C#, a physics `VehicleBody3D`, NPC AI for cultists, dialogue/quest/save frameworks without a request · claim a feature works without testing it · leave probe files, `override.cfg` or debug values in the project · kill Godot processes by name · run `git commit`, `git push`, `git reset`, `git checkout`/`switch` or create branches (§0.1).
