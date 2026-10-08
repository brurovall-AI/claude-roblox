# Ironhaven — Architecture & Contracts

Ironhaven is a premium Roblox gym simulator. This document is the contract
between all parts of the codebase. Read it fully before writing code.

## 1. Repository layout

```
default.project.json        Rojo project (ReplicatedStorage.Shared, ServerScriptService.Server,
                            StarterPlayerScripts.Client, Workspace.Map from assets/Map.rbxm,
                            Lighting + post-processing)
src/shared/                 ReplicatedStorage.Shared (configs, formulas, utils) — FOUNDATION
src/server/                 ServerScriptService.Server
  Main.server.luau          bootstrap: loads every ModuleScript in Services/ (Init then Start)
  Core/                     Events (gameplay event bus), Notify (toasts / game events)
  Services/                 one ModuleScript per service
  Visuals/                  server-built visuals (gear on characters, held props)
src/client/                 StarterPlayerScripts.Client
  Main.client.luau          bootstrap: loads every ModuleScript in Controllers/
  Core/                     GameEvents (server event dispatcher), State (shared client state)
  Controllers/              one ModuleScript per controller
  UI/                       Theme, Create, Icons, Components (+ Windows/ helpers)
src/map/                    map builder (NOT part of the game at runtime; baked by Lune)
  init.luau                 orchestrator  | Kit, Palette, Layout, Gameplay, Context — FOUNDATION
  Shell/ Site/              architecture, site, city
  Equipment/                station builders (tiered)   Props/  furniture & details
  Areas/                    per-area dressing
tools/check/                strict Luau type checker (node tools/check/check.mjs)
tools/bake/bake.luau        bakes src/map -> assets/Map.rbxm (+ preview dump)
tools/render/               offline preview renderer (PNG)
tools/build.sh              check + bake + rojo build -> Ironhaven.rbxl
```

## 2. Commands

```
node tools/check/check.mjs              # type-check everything (must end with 0 errors)
node tools/check/check.mjs src/server   # filter by path substring
lune run tools/bake/bake.luau           # bake the map (prints part/light counts, FAILED modules)
lune run tools/bake/bake.luau --no-rbxm --out build/<you>   # parallel-safe bake: dump only, to your own dir
tools/render/target/release/ironhaven-render build/preview/dump.json tools/render/cameras.json build/preview <camera>
                                        # render one preset (see tools/render/cameras.json); omit <camera> for all
rojo build default.project.json -o build/Ironhaven.rbxl
```
Render images are approximations of Roblox Future lighting — good for layout,
composition, colour and density checks. View PNGs with the Read tool.
You can add your own temporary camera presets to a separate JSON file in build/.

## 3. Coding rules (enforced by the checker)

* Every file starts with `--!strict`. Tabs for indentation. Match existing style and comment density.
* Requires: in game code use Roblox paths only:
  `local Shared = ReplicatedStorage:WaitForChild("Shared")` then `require(Shared.Config.Stats)`,
  or `require(script.Parent.Foo)`. In src/map use relative strings: `require("../Kit")`.
* Server code may index ReplicatedStorage children directly after the alias above.
* Checker quirks (write code that satisfies them — they also make code safer):
  - `:IsA()` does NOT narrow types. Cast after checking: `if x:IsA("BasePart") then local p = x :: BasePart ... end`.
  - `FindFirstChild`, `FindFirstChildOfClass`, `WaitForChild` return `Instance`/`Instance?` — cast: `char:FindFirstChildOfClass("Humanoid") :: Humanoid?`.
  - `Instance.new("Part")` and `game:GetService("X")` are typed automatically (string literal only).
  - Calling a function stored in an `any` table field after a truthiness check fails to type-check:
    use `(props.OnClick :: any)()` or store it in a typed local.
  - `type(x) == "function"` refines to an uncallable type: cast before calling.
  - Annotate `table.sort` comparator parameters: `table.sort(list, function(a: Item, b: Item) ... end)`.
  - Annotate empty table locals that you fill later: `local list: { Frame } = {}`.
  - Enum types in annotations: `Enum.Material` style is fine (checker maps it).
  - Tuple types like `{ string, number }` are invalid; use records `{ name: string, n: number }`.
* Never use deprecated APIs: `wait`, `spawn`, `delay` → `task.*`; no `BodyVelocity`/`BodyGyro`.
* Client↔server: validate every client payload type and range on the server. Rate-limit with `Net.allow`.
* No asset IDs that you cannot verify. Audio goes through `Config/Audio` keys; UI icons through `UI/Icons`.
* Performance: no per-frame `FindFirstChild` chains; cache. Disconnect connections (use `Trove`).
  One `RenderStepped`/`PreSimulation` connection per controller, not per object.

## 4. Foundation APIs (do not edit these files; extend through them)

### Shared (`src/shared`)
* `Config/*` — all tuning data: Stats, Tiers, Stations, Minigames, Areas, Ranks, Progression,
  Gear, Companions, Cosmetics (Auras/Titles/Emotes/Decor), Boosts, Missions, Achievements,
  DailyRewards, Competitions, Monetization, Audio, Currency, Rewards.
* `Formulas.rep(stationType, tier, quality, combo, multipliers)` → `{Stat, StatGain, XP, Cash, EnergyDelta}`;
  `Formulas.socialMult(partyNearby, friendsNearby)`.
* `DataSchema` — `PlayerData` type + defaults; `dayNumber()`, `weekNumber()`.
* `Util/Net` — `Net.event(name)`, `Net.unreliable(name)`, `Net.handle(action, fn)` (server),
  `Net.request(action, payload)` (client) → `(ok, result)`, `Net.allow(player, key, perSec, burst)`.
  Name request actions `Feature.Verb` (e.g. `Shop.Buy`, `Training.Stop`).
* `Util/Signal`, `Util/Trove`, `Util/Format` (`short`, `commas`, `clock`, `duration`), `Util/TableUtil`.

### Server (`src/server`)
* Service module shape: `{ Priority = n?, Init = fn?, Start = fn? }` (see Main.server.luau).
* `Services/DataService` — `get(player)`, `waitFor(player)`, `set(player, path, value)`,
  `increment(player, path, delta)`, `update(player, path, fn)`, `replicate(player, path)`;
  signals `Loaded(player, data)`, `Releasing(player, data)`, `Changed(player, path, value)`.
  ALWAYS mutate data through these so the client replica stays in sync.
* `Services/ProgressionService` — `award(player, reward, source, quiet?)`, `addStat(player, stat, n)`,
  `addXP`, `addCash(player, n, source)`, `spend(player, cost)`, `canAfford`, `count(player, key, d)`,
  `best(player, key, value, lowerIsBetter)`, `power`, `rank`, `rebirth`;
  signals `StatsChanged`, `LevelChanged`, `RankChanged`.
* `Services/CharacterService` — applies speed/jump/muscle/nameplate attributes/gear;
  `refresh(player)`, `setOverride(player, key, {WalkSpeed?, JumpHeight?})`, `clearOverride(player, key)`.
  Player attributes for nameplates: Level, Rank, RankName, Power, Rebirths, Title, Aura, Companions (csv).
  Other slices may add attributes: VIP (bool), PartyId (string), Training (string station type).
* `Services/MultiplierService` — `forStat(player, stat)` → `Formulas.Multipliers` (gear, companions,
  boosts, rebirths, social, flags); `setSocial(player, partyNearby, friendsNearby)`; `setFlag(player, "DoubleCash", bool)`;
  `boostActive(player, id)`; `windowMult(player)` (Lucky Chalk); `energyRegenMult(player)`.
* `Services/SettingsService` — `Settings.Set` request (client SettingsController owns the window).
* `Core/Events` — `fire(player, key, amount?, meta?)`, `on(key, fn)`, `any(fn)`. Standard keys are listed in the file.
* `Core/Notify` — `toast(player, title, text, kind)`, `event(player, name, payload)`, `all(name, payload)`, `others`.
* `Visuals/GearVisuals.apply(character, equipped)` — implemented by the Progression slice.

### Client (`src/client`)
* Controller module shape: `{ Priority = n?, Init = fn?, Start = fn? }`.
* `Controllers/DataController` — `ready()`, `get(path)`, `data`, `observe("Dot.Path", fn) -> unsubscribe`, `Changed`.
* `Controllers/UIController` — HUD slots `hud.TopLeft/TopRight/Top/Left/Right/Bottom/BottomStack/Overlay`;
  `registerWindow(id, {Title, Icon, Build(body, ctx), OnOpen?, OnClose?, Width?, Height?})`,
  `open(id)`, `close()`, `toggle(id)`, `isOpen(id)`, `setBadge(id, n)`, `hide(key)`/`unhide(key)`.
  Rail ids (fixed order): Stats, Inventory, Shop, Missions, Daily, Leaderboards, Social, Settings.
* `Controllers/AudioController.play(key, {At?, Position?, Volume?, Pitch?, Looped?, Group?})`; `groups` (Music/Ambience/Sfx/UI SoundGroups).
* `Controllers/NotificationController.toast(title, text, kind)`, `.banner({Kicker, Title, Subtitle, Color, Sound, Duration})`.
* `Core/GameEvents.on(name, fn)` — server `Notify.event` messages (LevelUp, RankUp, Reward, Rebirth, …) + local `emit`.
* `Core/State` — `get/set/changed` for shared flags: Training, Window, Zone, PhotoMode, Minigame, Cinematic, Emoting.
* `UI/Theme` (colours, fonts, radii, tweens), `UI/Create` (`New(class, props, children)`),
  `UI/Icons.make(name, size, color)` (stats gear shop missions daily ranks social party settings close plus check
  cash trophy token energy lock star user clock flame companion emote rebirth camera info boost elevator up down left right),
  `UI/Components` (`frame label card button iconButton progress pill divider scroll tabs toggle slider iconBadge empty corner stroke padding list tween`).

UI style rules: warm graphite surfaces, warm-white text, ONE accent (amber). No full-screen
panels except intentional moments; HUD widgets stay small at screen edges. Every window is
built from Components. Animate with `Theme.Tween`. Touch targets ≥ 44px. Test small
screens mentally (UIScale already handles 0.62–1.3).

## 5. World contract (map ↔ runtime)

Runtime finds world objects with CollectionService tags. Exact names/attributes:

| Tag | Instance | Attributes / children |
|---|---|---|
| `Station` | Model | StationType, Tier, StationId, AreaId; `UserSpot` (HRP target), `PromptPart` + ProximityPrompt `TrainPrompt`; optional `Mover` (+ attr MoverTravel Vector3 world), `Spinner` (attr SpinRate), `Swinger` |
| `AreaZone` | Part (Map.Zones, Persistent) | AreaId, Ambience? |
| `AreaGate` | Model (Persistent) | AreaId; `Door1`,`Door2` (attr SlideX, local X slide), `Barrier` (invisible collider), `SignPart` with SurfaceGuis `GateSignFront/Back` → TextLabel `Text` |
| `ElevatorStop` | Part | Floor (B1/G/L2/Roof); ProximityPrompt `ElevatorPrompt`; child marker `Arrive` |
| `EventSpot` | Part | EventId (Competitions ids), Role, Index |
| `CourseCheckpoint` | Part | CourseId (Sprint/Obstacle), Index (0 start … n finish) |
| `LockerSlot` | Part | Index |
| `PhotoSpot` | Part | prompt `PhotoPrompt`; child `CameraPoint` |
| `LeaderboardBoard` | Part | Board (Power/Weekly/Trophies/Rebirths/Server) – runtime draws the Front face |
| `Scoreboard` | Part | Board = "Arena" |
| `ShopCounter` | Part | Shop (JuiceBar/ProShop/Companions/Cosmetics); prompt `ShopPrompt` |
| `DuelTable` | Model | TableId; markers `SeatA`, `SeatB` (HRP targets), `Grip` |
| `NpcSpot` | Part | Role (Idle/Spectate/Chat) |

Map helpers that create these: `src/map/Gameplay.luau`, `src/map/Equipment/init.luau`.
StreamingEnabled is ON: client code must handle stations/parts streaming in and out
(`CollectionService:GetInstanceAddedSignal`/`RemovedSignal`, never assume presence).

### Poses (training animation contract)
Station `Pose` (Config/Stations) tells the client which procedural animation to run.
UserSpot CFrames per pose are documented at the top of `src/map/Equipment/init.luau`
(standing HRP 3.0 above floor; bench: lying with LookVector = up; seated: seat + 1.3; …).
The server positions the trainee's HRP at UserSpot (anchored) and the client animates
Motor6D.Transform for every training character locally from replicated attributes.

## 6. Map building rules

* Build only with `Kit` (+ finishes from `Palette`) — never raw Instance property soup.
* All coordinates come from `Layout`. Do not invent room bounds; stay inside your rects.
* Doorways listed in `Layout.Gates` get gate models automatically — leave them empty.
* Floors: walk surfaces are the slab tops (`Layout.Y`). Put dressing ON the floor (y = floor + h/2).
* Small parts: `Kit.DETAIL` (no collision, no query). Big furniture that people bump: collide.
* Budgets (parts): each dressed area 400–1200 parts depending on size; whole map ≤ 35k parts.
  Lights: ≤ 40 per area, `Shadows = true` only for a few key lights per area (≤ 4).
  SurfaceGui signs: ≤ 12 per area. ParticleEmitters: none in the map (runtime only).
* Lighting design: real fixtures (Props.ceilingLight) with SurfaceLight/PointLight/SpotLight,
  warm 2700–3500K tones for hospitality spaces, neutral 4000K for training floors, daylight
  through windows. No giant neon strips. Neon only for small emissive bits (screens, Apex lines).
* Mirrors: `Props.mirror` on training walls (free weights, studio, VIP, boxing).
* Every area needs: a clear identity (materials/palette), a focal point, wayfinding sign,
  functional equipment layout with aisles ≥ 4 studs, small life details (towels, bottles,
  cleaning stations, plants), ceiling detail (lights/ducts/acoustic panels) and wall detail.

## 7. Ownership

Each parallel slice owns specific files (listed in its brief). Do not edit files you don't
own. Foundation files (section 4, plus src/map/{Kit,Palette,Layout,Gameplay,Context,init}.luau,
Equipment/init.luau, Equipment/Style.luau, Props/init.luau) are read-only for slices.
If a foundation change is truly required, write it down in your final report instead.
