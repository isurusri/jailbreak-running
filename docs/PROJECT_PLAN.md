# Jailbreak — "The Grand Retirement" Project Plan

Godot **4.7**, 2D sprite-based stealth game. Click/tap-to-move breadcrumb navigation,
guard vision cones, light/shadow hiding, contraband collection, 3-minute lockdown timer.

Guiding rule: **use Godot built-ins first** (NavigationAgent2D, PointLight2D,
LightOccluder2D, Area2D, AnimationPlayer, ResourceLoader), plus a small set of
proven Asset Library addons. No custom pathfinding, lighting, or serialization code.

---

## 1. Folder structure

```
res://
├── autoloads/                # true globals only — registered in Project Settings
│   ├── event_bus.gd          #   signal hub, zero logic
│   ├── game_manager.gd       #   run state: timer, score, level flow, caught/escaped
│   ├── save_manager.gd       #   persistence (JSON via built-in JSON class)
│   └── registry.gd           #   scans data/ at boot, indexes definitions by id
│
├── resources/                # custom Resource CLASS scripts (schemas)
│   ├── character_data.gd     #   CharacterData
│   ├── item_data.gd          #   ItemData (contraband)
│   └── level_config.gd       #   LevelConfig
│
├── data/                     # .tres INSTANCES of those schemas (the actual config)
│   ├── characters/           #   slick.tres, guard_grunt.tres, guard_elite.tres
│   ├── items/                #   cigarettes.tres, smuggled_phone.tres, gold_watch.tres
│   └── levels/               #   level_01_deep_blocks.tres ... level_final_wardens_office.tres
│
├── scenes/
│   ├── main/                 # main.tscn (root: swaps levels), boot.tscn
│   ├── actors/               # player.tscn, guard.tscn, pickup.tscn
│   ├── levels/               # deep_blocks.tscn, cell_block_b.tscn, wardens_office.tscn
│   └── ui/                   # hud.tscn, pause_menu.tscn, caught_screen.tscn, results.tscn
│
├── scripts/                  # reusable component scripts (attached to scene nodes)
│   ├── components/           #   movement.gd, input_handler.gd, vision_cone.gd,
│   │                         #   hideable_detector.gd, pickup.gd
│   ├── actors/               #   player.gd, guard.gd
│   └── ui/                   #   hud.gd, ...
│
├── assets/                   # sprites/, audio/, fonts/
└── addons/                   # Asset Library plugins (see §5)
```

Conventions:
- `resources/` = *what a thing can be* (schemas). `data/` = *what things are* (tuned values). Designers only touch `data/` and `scenes/`.
- Actor scenes are composed of components; scripts in `scripts/components/` never reference concrete game classes — they talk through exports and EventBus.

---

## 2. Data layer

### 2.1 Static definitions — custom Resources

`resources/character_data.gd`
```gdscript
class_name CharacterData
extends Resource

@export_group("Identity")
@export var display_name: String = ""
@export var sprite_frames: SpriteFrames

@export_group("Movement")
@export var move_speed: float = 220.0

@export_group("Guard AI (ignored for player)")
@export var vision_range: float = 300.0
@export var vision_angle_deg: float = 45.0
@export var patrol_wait_time: float = 1.5
@export var suspicion_seconds: float = 0.4   # time in cone before caught
```

`resources/item_data.gd`
```gdscript
class_name ItemData
extends Resource

enum Rarity { COMMON, RARE, LEGENDARY }

@export var id: StringName
@export var display_name: String = ""
@export var icon: Texture2D
@export var value: int = 10          # retirement-fund credits
@export var rarity: Rarity = Rarity.COMMON
@export_multiline var flavor_text: String = ""
```

`resources/level_config.gd`
```gdscript
class_name LevelConfig
extends Resource

@export var id: StringName
@export var display_name: String = ""
@export_file("*.tscn") var scene_path: String
@export var lockdown_seconds: float = 180.0
@export var par_loot_value: int = 100        # "escape rich" threshold
@export var next_level: LevelConfig          # chain: Deep Blocks -> ... -> Warden's Office
```

Instances live in `data/` as `.tres` files, edited in the Inspector. A guard scene
exports `@export var data: CharacterData` — swapping grunt/elite is a drag-and-drop,
no code change.

### 2.2 Runtime/save data — separate from definitions

Save files are **JSON**, not `.tres` (loading `.tres` from user:// can execute
embedded scripts; JSON is safe and diff-able). Definitions are referenced by `id`,
never serialized whole.

`autoloads/save_manager.gd`
```gdscript
extends Node

const SAVE_PATH := "user://save.json"

var profile := {
	"version": 1,
	"unlocked_level": "level_01_deep_blocks",
	"banked_loot": 0,                 # value extracted on successful escapes
	"best_times": {},                 # level_id -> seconds
	"collected_ids": [],              # ItemData ids ever collected (for a "ledger" UI)
	"settings": {"sfx": 1.0, "music": 1.0},
}

func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(profile, "\t"))

func load_profile() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if parsed is Dictionary and parsed.get("version") == 1:
		profile = parsed
```

Run-scoped state (current carried loot, timer) lives in `GameManager` and is
intentionally lost on "caught" — that's the story's confiscation mechanic.

**Save versioning & migration** — every save carries `version`. `load_profile()`
runs it through a migration chain before use, so future features can add fields
without breaking old saves:

```gdscript
const CURRENT_VERSION := 1

func _migrate(data: Dictionary) -> Dictionary:
	var v: int = data.get("version", 0)
	while v < CURRENT_VERSION:
		match v:
			0: data["banked_loot"] = data.get("banked_loot", 0)  # example
			# 1: data["upgrades"] = []          # future: meta-progression
			# 2: data["achievements"] = {}      # future: achievements
		v += 1
		data["version"] = v
	return data
```

Rule: **never rename or repurpose a save key** — add new keys with defaults and
migrate. Unknown keys are preserved on write (forward compatibility).

### 2.3 Content registry — add content by adding files

New items/characters/levels must not require touching code. A lightweight
registry autoload scans `data/` folders at boot, so a new `.tres` file *is* the
integration:

`autoloads/registry.gd`
```gdscript
extends Node
## Indexes all definition .tres files by id. Adding a file = adding content.

var items: Dictionary[StringName, ItemData] = {}
var levels: Dictionary[StringName, LevelConfig] = {}

func _ready() -> void:
	_scan("res://data/items/", items)
	_scan("res://data/levels/", levels)

func _scan(dir_path: String, into: Dictionary) -> void:
	for file in ResourceLoader.list_directory(dir_path):
		var res := load(dir_path + file)
		if res and "id" in res:
			into[res.id] = res
```

This is what lets saves reference content by `id` string: `Registry.items[&"gold_watch"]`.
It also makes future systems (shop, achievements ledger, random loot tables,
daily-challenge item pools) free — they iterate the registry instead of
maintaining their own lists.

---

## 3. Systems / mechanics

### 3.1 Autoloads (only four)

| Autoload | Responsibility | What it must NOT do |
|---|---|---|
| `EventBus` | declare signals | hold state or logic |
| `GameManager` | run state machine (PLAYING / CAUGHT / ESCAPED), lockdown timer, carried loot, level chaining via `LevelConfig.next_level` | touch UI nodes or actor internals |
| `SaveManager` | read/write `user://save.json`, version migration | know about gameplay rules |
| `Registry` | index definition `.tres` files by id | hold mutable state |

Everything else (player, guards, HUD, pickups) is a plain scene-tree node.

### 3.2 EventBus

`autoloads/event_bus.gd`
```gdscript
extends Node
## Global signal hub. Declares signals only — no state, no logic.

# Input → movement / interaction
signal move_requested(world_pos: Vector2)
signal interact_requested(target: Interactable)   # see §4.1

# Stealth
signal player_spotted(guard: Node2D)
signal player_caught
signal player_entered_cover
signal player_left_cover

# Loot
signal contraband_collected(item: ItemData)

# Run flow
signal lockdown_tick(seconds_left: float)
signal lockdown_sealed
signal level_completed(config: LevelConfig)
signal run_failed          # caught or sealed in → loot confiscated
```

Rule of thumb: use EventBus for **cross-system** communication (pickup → HUD,
guard → GameManager). For **parent–child** communication inside one scene
(Movement → Player), use local signals — don't globalize what's local.

### 3.3 Input (separate from movement)

`scripts/components/input_handler.gd` — attach as child of the level (Node2D).
Handles mouse *and* touch ("tapping the screen" per the story).

```gdscript
class_name InputHandler
extends Node2D
## Translates clicks/taps into world-space move requests. Knows nothing about the player.

func _unhandled_input(event: InputEvent) -> void:
	var pressed_at := Vector2.INF
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed_at = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed_at = event.position

	if pressed_at != Vector2.INF:
		var world_pos := get_canvas_transform().affine_inverse() * pressed_at
		EventBus.move_requested.emit(world_pos)
		get_viewport().set_input_as_handled()
```

Because it uses `_unhandled_input`, any UI (buttons, pause menu) consumes clicks
first — no "walked because I clicked a button" bugs.

### 3.4 Breadcrumb movement component (NavigationAgent2D)

`scripts/components/movement.gd` — plain `Node` child of the player/guard scene.
Owns *how* to move; owner decides *when*.

```gdscript
class_name MovementComponent
extends Node
## Drives a CharacterBody2D along a NavigationAgent2D path. Reusable by player and guards.

signal destination_reached
signal moving(velocity: Vector2)   # for animation

@export var body: CharacterBody2D
@export var agent: NavigationAgent2D
@export var data: CharacterData    # speed comes from data, not code

func _ready() -> void:
	set_physics_process(false)     # idle components cost nothing

func move_to(world_pos: Vector2) -> void:
	agent.target_position = world_pos   # NavigationServer computes the path
	set_physics_process(true)

func stop() -> void:
	body.velocity = Vector2.ZERO
	set_physics_process(false)

func _physics_process(_delta: float) -> void:
	if agent.is_navigation_finished():
		stop()
		destination_reached.emit()
		return
	var next := agent.get_next_path_position()   # the "breadcrumb"
	body.velocity = body.global_position.direction_to(next) * data.move_speed
	body.move_and_slide()
	moving.emit(body.velocity)
```

Level scenes need a `NavigationRegion2D` with a baked polygon (bake in-editor —
built-in, zero code). Obstacles (pillars, overturned tables) carve holes in the
navmesh automatically, which *also* makes them cover — geometry does double duty.

### 3.5 Player state machine (enum-based)

`scripts/actors/player.gd`
```gdscript
class_name Player
extends CharacterBody2D

enum State { IDLE, WALKING, INTERACTING, CAUGHT }
var state: State = State.IDLE

@export var data: CharacterData
@onready var movement: MovementComponent = $Movement
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	sprite.sprite_frames = data.sprite_frames
	EventBus.move_requested.connect(_on_move_requested)
	EventBus.player_caught.connect(func(): _enter_state(State.CAUGHT))
	movement.destination_reached.connect(func(): _enter_state(State.IDLE))
	movement.moving.connect(_update_facing)

func _on_move_requested(world_pos: Vector2) -> void:
	if state == State.CAUGHT or state == State.INTERACTING:
		return
	movement.move_to(world_pos)   # re-clicking mid-walk just retargets: Slick darts
	_enter_state(State.WALKING)

func _enter_state(new_state: State) -> void:
	if new_state == state:
		return
	state = new_state
	match state:
		State.IDLE:
			sprite.play(&"idle")
		State.WALKING:
			sprite.play(&"walk")
		State.CAUGHT:
			movement.stop()
			sprite.play(&"caught")

func _update_facing(vel: Vector2) -> void:
	if absf(vel.x) > 0.01:
		sprite.flip_h = vel.x < 0.0
```

If states grow complex later (crouch, lockpick, carry-body), promote to LimboAI's
hierarchical state machine (§5) — the enum version's `_enter_state` boundary makes
that migration mechanical.

### 3.6 Stealth: lights, shadows, vision cones (all built-in)

- **Emergency lighting**: one `CanvasModulate` per level tinted dark red — the whole
  prison reads as "blackout".
- **Guard flashlight**: `PointLight2D` with a cone gradient texture on the guard,
  rotated with facing. Purely visual, and it's also honest: `LightOccluder2D` on
  pillars/tables blocks the light exactly where gameplay says you're hidden.
- **Detection** (gameplay truth, separate from visuals): `Area2D` with a cone
  `CollisionPolygon2D` on the guard. On `body_entered(player)`, fire a
  `RayCast2D` at the player; if the ray hits a wall/occluder first, the player is
  behind cover — no detection. If line-of-sight holds for
  `data.suspicion_seconds`, emit `EventBus.player_spotted`, then `player_caught`.
- **Cover feedback**: `Area2D` shadow zones behind occluders emit
  `player_entered_cover` so the HUD/audio can telegraph "safe".

### 3.7 Story mechanics mapping

| Story beat | System |
|---|---|
| 3-minute window, Protocol Zero | `GameManager` timer from `LevelConfig.lockdown_seconds`, `lockdown_tick`/`lockdown_sealed` on EventBus, HUD countdown |
| Contraband empire | `pickup.gd` (Area2D + `@export var item: ItemData`) → `contraband_collected` → GameManager adds to `carried_loot`, HUD updates |
| Caught = confiscation + restart | `player_caught` → GameManager zeroes `carried_loot`, emits `run_failed`, reloads level; `banked_loot` in the save is untouched |
| Escape rich | Level exit banks `carried_loot` into `SaveManager.profile.banked_loot`; results screen compares vs `par_loot_value` |
| Deep Blocks → Warden's Office | `LevelConfig.next_level` chain walked by GameManager |

---

## 4. Adaptability: extension points & future features

The architecture defines five **extension points**. Every future feature attaches
to one or more of them; none requires modifying existing systems:

1. **New Resource schema** in `resources/` + `.tres` files in `data/` → auto-indexed by `Registry`.
2. **New EventBus signals** — additive only; existing emitters/listeners unaffected.
3. **New component** in `scripts/components/` — a self-contained node dropped into a scene.
4. **New save keys** with defaults + a migration step — old saves keep working.
5. **New UI scene** in `scenes/ui/` that only listens to EventBus — never pokes gameplay nodes.

### 4.1 The generic interaction system (build this early)

Most future mechanics (looting a safe, bribing a guard, picking a lock, pulling a
lever, hiding in a locker) are the same shape: *walk to a thing, then do something*.
One component covers all of them, so build it in milestone 3:

`scripts/components/interactable.gd`
```gdscript
class_name Interactable
extends Area2D
## "Walk here, then interact." Subclass or connect to `interacted` for behavior.

signal interacted(by: Node2D)

@export var interact_radius: float = 24.0
@export var hold_seconds: float = 0.0      # 0 = instant; >0 = lockpick-style hold

func _ready() -> void:
	input_pickable = true
	input_event.connect(_on_input_event)

func _on_input_event(_vp: Node, event: InputEvent, _idx: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		EventBus.interact_requested.emit(self)
		get_viewport().set_input_as_handled()
```

The player handles `interact_requested` by walking within `interact_radius`
(reusing `MovementComponent`), entering `State.INTERACTING`, and emitting
`interacted` after `hold_seconds`. Pickups become a 5-line `Interactable`
subclass. So do doors, lockers, safes, dialogue triggers, and level exits —
**every future "thing you click on" is this component plus data**, and the
click-vs-move ambiguity is solved once, centrally.

### 4.2 Future feature map

Each row lists exactly what gets *added* — the "touches" column is the honest
cost of the feature. If a feature needs more than these, the design is wrong.

| Future feature | Adds | Touches existing code |
|---|---|---|
| **Inventory UI / loot ledger** | `inventory_panel.tscn` listening to `contraband_collected`; iterates `Registry.items` for the "ever collected" ledger | nothing |
| **Dialogue / bribing guards** | Dialogue Manager addon, `DialogueData` resource, `dialogue_started/ended` signals; guard pauses patrol on `dialogue_started` | nothing (`INTERACTING` state already gates movement) |
| **Gadgets/abilities** (smoke bomb, coin lure) | `AbilityData` schema, `ability_used(data, pos)` signal, hotbar UI; guards gain a listener component reacting to lures | nothing |
| **Disguises** | `disguise_changed(kind)` signal; vision-cone component checks current disguise before spotting | vision_cone.gd gains one check |
| **Meta-progression shop** (spend banked loot between runs) | `UpgradeData` schema + `data/upgrades/`, save key `upgrades: []` (migration v2), shop UI; `CharacterData` values modified through a small `StatQuery` helper at spawn | player reads stats via helper instead of raw `data.move_speed` |
| **New levels/guards/items** | `.tres` + `.tscn` files only | nothing (Registry + `LevelConfig.next_level`) |
| **Daily challenge / seeded runs** | `run_seed` in GameManager, seeded RNG for pickup placement from Registry pools | nothing |
| **Achievements** | achievement definitions as Resources; one `achievement_tracker.gd` autoload-free node in main.tscn listening to existing signals | nothing |
| **Localization** | Godot's built-in `tr()` + CSV/PO; works because all player-facing text lives in Resources, not string literals | display code calls `tr()` |
| **Controller / keyboard support** | second input component emitting the same `move_requested`/`interact_requested` signals (cursor or direct control) | nothing (input was isolated from day one) |
| **Mobile port** | touch already handled; add UI scaling pass | HUD layout only |
| **Complex guard AI** (search patterns, alert states, coordination) | LimboAI behavior trees replacing the guard's enum SM; blackboard reads the same `CharacterData` | guard.gd internals only — its outward signals (`player_spotted`) are the contract |

### 4.3 Invariants — the rules that keep it adaptable

Check every PR/feature against these; they are the whole load-bearing structure:

1. Components never hard-reference other components or concrete game classes — communication is exports (wired in the scene) or EventBus.
2. Resources hold data, never logic. Logic lives in components; tuning lives in `.tres`.
3. EventBus signals are **facts, not commands** ("contraband_collected", not "update_hud") — emitters must not know or care who listens.
4. Signals and save keys are append-only. Deprecate by ignoring, remove only with a save migration.
5. UI reads EventBus + GameManager; it never reaches into actor scenes. Gameplay never reaches into UI.
6. Anything a designer might tune is an `@export` on a Resource, not a constant in a script.
7. A system's outward contract is its signals. Internals (enum SM → LimboAI, sprite → skeletal anim) may be rewritten freely as long as the signals hold.

---

## 5. Prebuilt libraries (Godot Asset Library)

| Addon | Use | When |
|---|---|---|
| **LimboAI** | behavior trees + hierarchical state machines for guard AI (patrol → suspicious → chase → return) | Milestone 2 if enum guards feel limiting |
| **Dialogue Manager** (Nathan Hoad) | branching dialogue, balloon UI | when dialogue enters scope |
| **PhantomCamera** | smooth follow-cam, zoom on spotted, room framing | Milestone 3 polish |
| **GUT** | unit tests for GameManager/SaveManager logic | optional, Milestone 4 |

Everything else — pathfinding, avoidance, 2D lights/occlusion, particles,
serialization — is engine built-in. Don't add addons for those.

---

## 6. Milestones

1. **Skeleton** — folders, three autoloads registered, input map, empty gray-box level with `NavigationRegion2D`.
2. **Vertical slice: movement** — InputHandler + MovementComponent + Player states; click/tap moves Slick around obstacles with idle/walk anims. *This is the feel-critical milestone — tune speed and path smoothing here.*
3. **Stealth core** — guard scene (reuses MovementComponent for patrol waypoints), vision cone Area2D + raycast, caught → restart. Build the generic `Interactable` component (§4.1) here. One guard, one pillar, one pickup: the whole game loop exists.
4. **Presentation of stealth** — CanvasModulate blackout, flashlight PointLight2D, LightOccluder2D, cover zones + feedback.
5. **The score** — pickups, ItemData set, HUD (loot value + countdown), lockdown timer, confiscation on caught, banking on escape, SaveManager wired.
6. **Content & flow** — LevelConfig chain, 3–4 levels Deep Blocks → Warden's Office, results screen, menus, audio, polish (screen shake on spotted, guard bark VO, helicopter finale).

Build order matters: 2 and 3 prove the game is fun before any art or content investment.
