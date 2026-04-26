# Twilight Lantern Festival – Modular Experience

A peaceful Roblox experience set at twilight. Four independent activity stations sit around your map. Complete them to earn lanterns, then release them from the dock over the lake.

---

## Quick Start

1. **Clone** the repo and open Roblox Studio (New Place or your existing map).
2. Install the [Rojo plugin](https://rojo.space/) and run:
   ```
   rojo serve default.project.json
   ```
3. Connect the plugin — all scripts sync automatically.
4. **Open `src/shared/ModuleConfig.lua`** and set each module's `Position` to match your map.
5. Play-test!

---

## Placing the Modules

`src/shared/ModuleConfig.lua` is the **only file you need to edit** to position all four stations. Each entry looks like:

```lua
Breathing = {
    Enabled   = true,
    Position  = Vector3.new(50, 1, -60),   -- ← change this
    Direction = Vector3.new(0, 0, -1),
    Prerequisites = {},
    Reward    = "Lantern",
},
```

| Field | Meaning |
|---|---|
| `Position` | World-space centre of the station |
| `Direction` | Which way the arch/sign faces |
| `Prerequisites` | Module IDs that must be done first (`{}` = always open) |
| `Enabled` | Set `false` to hide a station entirely |

**TRIGGER_RADIUS** (top of the file) controls how close a player must be to activate a station (default 10 studs).

---

## The Four Modules

### 1 · Breathing Grove
Animated expanding/contracting circle. 4 inhale-hold-exhale cycles.  
**Reward:** 1 lantern.

### 2 · Garden of Gratitude
3 reflective writing prompts. Each answer grows a 3-D flower (stem → bloom → petals → sparkle burst) on a raised garden bed next to a bench.  
**Reward:** 1 lantern.

### 3 · Wisdom Puzzle (Jigsaw)
3 rounds of quote-tile ordering. Shuffled word tiles appear in a pool; tap to place them into the sentence tray. Submit when the quote is complete.  
Server validates the answer — wrong answers shake the tray and let the player retry.  
**Reward:** 1 lantern.

### 4 · Lantern Release
On the dock ledge over your lake. Press the button to release all earned lanterns simultaneously — each rises with a gentle sway, sparkle trail, and glow that fades as it climbs. Cinematic FOV widens. Journey-complete card slides in.

---

## File Layout

```
default.project.json          ← Rojo project
src/
  shared/
    ModuleConfig.lua          ← ★ Edit positions here
  server/
    LightingSetup.server.lua  ← Twilight sky/atmosphere (no terrain changes)
    ModuleManager.server.lua  ← Builds all 4 stations, owns all RemoteEvents,
                                 validates client events, awards lanterns
  client/
    BreathingModule.client.lua
    GardenModule.client.lua
    JigsawModule.client.lua
    LanternModule.client.lua
```

---

## Architecture

```
                ┌───────────────────────────────────────┐
                │         ModuleManager (server)        │
                │  • builds 3-D props from ModuleConfig │
                │  • proximity scan every 0.5 s         │
                │  • owns all RemoteEvents in RS/Remotes│
                │  • validates + awards lanterns        │
                └──────────────┬────────────────────────┘
                               │ RemoteEvents
          ┌────────────────────┼───────────────────────┐
          │                    │                       │
   BreathingModule      GardenModule             JigsawModule
   (client)             (client)                 (client)
          │                    │                       │
          └────────────────────┴───────────────────────┘
                               │
                        LanternModule
                        (client – release on dock)
```

All RemoteEvents live in `ReplicatedStorage/Remotes` (created by the server at startup).  
Clients use `WaitForChild` and never create their own remotes.

### Remote Event Reference

| Remote | Direction | Payload |
|---|---|---|
| `Breathing_Start` | S→C | — |
| `Breathing_Complete` | C→S | — |
| `Garden_Start` | S→C | — |
| `Garden_Flower` | C→S | gratitudeText |
| `Garden_Flower` | S→C | plotIndex (1-3) |
| `Garden_Complete` | C→S | — |
| `Jigsaw_Start` | S→C | — |
| `Jigsaw_Submit` | C→S | roundNumber, answer |
| `Jigsaw_Submit` | S→C | "ROUND_DATA" / "CORRECT" / "WRONG" |
| `Jigsaw_Complete` | S→C | — |
| `Lantern_Start` | S→C | — |
| `Lantern_Release` | C→S | — |
| `Global_LanternCount` | S→C | count (number) |
| `Global_ModuleDone` | S→C | moduleId (string) |

---

## Extending

- **Add a module**: create a new entry in `ModuleConfig.lua`, add a server handler in `ModuleManager`, and write a new `client/YourModule.client.lua`.
- **Change jigsaw quotes**: edit `JIGSAW_ROUNDS` inside `ModuleManager.server.lua`.
- **Change flower palettes / names**: edit `PALETTES` / `NAMES` in `GardenModule.client.lua`.
- **Change breathing timing**: `CYCLES`, `INHALE_T`, `HOLD_T`, `EXHALE_T` at the top of `BreathingModule.client.lua`.
