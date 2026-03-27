# Yorlords

**A turn-based fantasy conquest game in the spirit of Warlords II.**

Built with [Godot 4](https://godotengine.org/) — runs on Windows, Linux, macOS, Android, and iOS.

---

## Quick Start

### Requirements
- [Godot 4.3+](https://godotengine.org/download/) (free and open source)

### Run in Editor
1. Clone this repo
2. Open Godot 4, click **Import** and select the `project.godot` file
3. Press **F5** (or click the Play button) to run

### Export
Use **Project → Export…** in the Godot Editor. Export presets for Windows, Linux, macOS, Android, and iOS are included in `export_presets.cfg`. You will need to install the [export templates](https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html) first.

---

## How to Play

### Main Menu
```
A)  Single Player         — Play alone (city management & exploration)
B)  Host Multiplayer Game — Create a game others can join over LAN/internet
C)  Join Multiplayer Game — Enter a host's IP address to connect
D)  Quit
```

### Setup Screen
Choose your **name** and **race**:
```
A) Human  — Balanced kingdom; Knights and Wizards
B) Elf    — Fast Rangers and mighty Dragons
C) Dwarf  — Mountain lords with powerful siege weapons
D) Orc    — Savage Wolf Riders and regenerating Trolls
E) Undead — Cheap Skeleton hordes and fearsome Ghosts
F) Demon  — Small Imps building toward the ultimate Demon Lord
```

### Multiplayer Lobby
The **host** shares their IP address shown on the lobby screen.
Clients enter it on the Join screen and press **Confirm**.
Once all players have joined, the host presses **A) Start Game**.

---

## Game Rules (Warlords II style)

### Map
- Square grid map (**24 × 16** tiles)
- Terrain: Plains, Forest, Mountain, Swamp, Water, Road, City, Ruins

### Cities
- Each city produces one unit type per turn (slower = stronger unit)
- Cities generate **gold** every turn (higher city level = more gold)
- **Capture** a city by walking an army into it when it is undefended
- **Set production** by tapping a city you own and choosing:
  ```
  A) Infantry   B) Cavalry   C) Archer   D) Catapult
  E) Knight     F) Wizard    (etc. — list varies by race)
  ```

### Armies
- Stack of up to **8 units** per tile
- **Tap** an army to select it — move points are shown
- **Tap a destination tile** to move one step (costs movement points)
- Armies **merge** automatically when meeting a friendly stack at the same tile
- The slowest unit in the stack limits total movement

### Heroes
- Special units hired at friendly cities (costs gold)
- Gain **experience** from battles and **level up** (max level 10)
- Provide a **leadership bonus** to all units in the same army
- Can carry up to 4 **items** found in ruins tiles

### Combat (Warlords II style)
When an army moves onto a tile occupied by an enemy:
1. Best unit from each side fights each round (highest effective strength)
2. Terrain gives the **defender** a bonus (Mountains +2, Forest +1, City +2 …)
3. A **d6 roll** adds randomness to each round
4. Battle continues until one side is eliminated
5. A winning Hero earns experience toward their next level

### Turn Structure
Each round every living player takes a full turn in sequence:
```
1. Collect income  — gold from all owned cities
2. Advance production — finished units appear at their city
3. Reset movement  — all armies regain their move points
4. Player acts:
     - Move armies (tap army → tap destination)
     - Set city production (tap city → choose unit)
5. End Turn        — press E or tap the "End Turn" button
```

### Victory
- **Last player** with at least one city wins
- A player is **eliminated** when they lose all cities AND all armies

---

## Multiplayer Architecture
- Host machine acts as **server + player 1** (Godot ENet networking)
- All game logic is **authoritative on the host**
- Clients send action requests (move, set production, end turn) via RPC
- Host validates every request, then broadcasts the full game state
- Default port: **7777** (change in `scripts/GameData.gd`)

---

## Project Structure
```
Yorlords/
├── project.godot            — Godot 4 project configuration
├── export_presets.cfg       — Mobile & PC export configurations
├── autoloads/
│   ├── GameManager.gd       — Central game state singleton
│   └── NetworkManager.gd    — Multiplayer host/client singleton
├── scripts/
│   ├── GameData.gd          — Static data: units, terrain, races, constants
│   ├── Player.gd            — Player resource
│   ├── Unit.gd              — Unit resource
│   ├── Hero.gd              — Hero unit (extends Unit)
│   ├── Army.gd              — Army stack resource
│   ├── City.gd              — City resource
│   ├── MapCell.gd           — Map tile resource
│   ├── MapGenerator.gd      — Procedural map generation
│   ├── CombatResolver.gd    — Warlords II-style round combat
│   ├── TurnManager.gd       — Turn order, income, production, victory check
│   ├── MainMenu.gd          — Main menu UI controller
│   ├── LobbyMenu.gd         — Multiplayer lobby UI controller
│   ├── GameWorld.gd         — In-game scene controller (input, rendering)
│   └── ui/
│       ├── HUD.gd           — In-game heads-up display
│       ├── CityPanel.gd     — City info & production UI
│       ├── UnitPanel.gd     — Selected army info UI
│       ├── CombatLog.gd     — Battle report popup
│       ├── TurnSummary.gd   — Turn-start summary popup
│       └── GameOver.gd      — Game over / winner screen
├── scenes/
│   ├── MainMenu.tscn        — Main menu scene
│   ├── LobbyMenu.tscn       — Multiplayer lobby scene
│   └── GameWorld.tscn       — Main game scene (map + all UI panels)
└── assets/
    └── icon.svg             — Application icon
```

---

## License
See repository license.
