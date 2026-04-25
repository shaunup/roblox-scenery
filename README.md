# Twilight Lantern Festival – Roblox Experience

A peaceful, cinematic Roblox experience set at twilight where players walk a
zigzag stone trail, complete a breathing exercise, listen to Gemini-powered
music at a bonfire, and finally release a glowing paper lantern over a
shimmering pond.

---

## Scene Overview

| Feature | Details |
|---|---|
| **Sky** | Deep twilight (`ClockTime 19.5`), Atmosphere effect (orange–purple haze), 4 000 stars, large visible moon with glow aura |
| **Horizon glow** | Two neon planes simulate the last light of a dimming sunset |
| **Mountains** | Six layered wedge mountains with snow caps in the background |
| **Ground** | Grass baseplate with rolling hill overlays |
| **Trail** | 11-waypoint zigzag cobblestone path with lantern posts every other segment |
| **Fireflies** | 20 ambient glowing particles above the trail area |
| **Camera** | Scriptable cinematic third-person; right-click drag to orbit; auto-returns behind player |

---

## Game Flow

```
Spawn (baseplate)
   │
   ▼ walk zigzag trail
   │
[Breathing Grove – Waypoint 5]
   │  → Breathing overlay appears
   │  → 4-cycle animated breathing exercise (inhale 4s / hold 2s / exhale 5s)
   │  → Lantern awarded (+1 Lanterns leaderstats)
   │
   ▼ continue trail
   │
[Bonfire – Waypoint 8]
   │  → Elara the Musician NPC dialog appears
   │  → Player types music mood (calm / jazz / classical / lofi / ambient / upbeat)
   │  → Server calls Gemini API → returns matching Roblox audio asset ID
   │  → Music fades in; "Now Playing" banner shown
   │
   ▼ continue trail
   │
[Glow Pond – Waypoint 11]
   │  → "Release your lantern" button appears
   │  → Lantern spawns, rises with sway + sparkle trail
   │  → Camera widens to FOV 80
   │  → "Journey Complete" cinematic card shown
   ▼
  END
```

---

## File Structure

```
default.project.json              ← Rojo project file
src/
  ServerScriptService/
    WorldBuilder.server.lua       ← Builds entire 3-D world on server start
    GameManager.server.lua        ← Remote events, state, Gemini API call
  StarterPlayerScripts/
    CameraFollow.client.lua       ← Cinematic camera with orbit
    BreathingExercise.client.lua  ← Breathing UI + reward notification
    MusicianDialog.client.lua     ← NPC chat UI + music playback
    LanternRelease.client.lua     ← Lantern physics + journey-complete screen
  ReplicatedStorage/
    GameConfig.lua                ← Shared constants
```

---

## Setup

### Requirements
- [Roblox Studio](https://www.roblox.com/create)
- [Rojo](https://rojo.space/) (`rojo serve` or Rojo Studio plugin)

### Steps

1. **Clone** this repository.
2. **Open Roblox Studio** → New Baseplate place.
3. **Start Rojo**: `rojo serve default.project.json`
4. Connect the Rojo Studio plugin to the local server.
5. All scripts sync into their correct services automatically.

### Gemini API (music)

The bonfire musician fetches a music suggestion from Google Gemini.

1. Obtain a Gemini API key from [Google AI Studio](https://aistudio.google.com/).
2. In Roblox Studio → **Game Settings → Security**, enable **Allow HTTP Requests**.
3. Set the secret in one of two ways:
   - **Roblox Studio**: Add a `Script` that sets `os.getenv("GEMINI_API_KEY")` — or
   - **Cloud Agents / CI**: set the `GEMINI_API_KEY` environment variable before running.
4. If the key is absent or the API is unreachable, the game gracefully falls back to
   curated royalty-free Roblox audio IDs.

---

## Customisation

| What to change | Where |
|---|---|
| Trail length / waypoints | `trailWaypoints` table in `WorldBuilder.server.lua` |
| Number of breathing cycles | `BREATHING_CYCLES` in `GameConfig.lua` |
| Camera offset / smoothing | `CAMERA_OFFSET` / `CAMERA_SMOOTH` in `GameConfig.lua` |
| Fallback audio IDs | `FALLBACK_AUDIO` table in `GameConfig.lua` |
| Lantern rise speed / sway | `LANTERN_RISE_SPEED`, `LANTERN_SWAY_AMP` in `GameConfig.lua` |
| Sky / lighting mood | `Lighting.*` properties at the top of `WorldBuilder.server.lua` |
| Mountain count / layout | `mountainData` table in `WorldBuilder.server.lua` |

---

## Architecture Notes

- **Server authority**: all game state (lantern ownership, milestone progression,
  Gemini fetch) lives in `GameManager.server.lua`.  The client never self-awards
  items.
- **RemoteEvents** bridge server ↔ client:  
  `BreathingStart`, `BreathingComplete`, `LanternAwarded`, `MusicianApproach`,
  `MusicChoice`, `PlayMusic`, `CanReleaseLantern`, `ReleaseLantern`
- **No datastore** in this version (single-session experience).  Adding
  `DataStoreService` persistence is straightforward via `playerState` in
  `GameManager`.
- **Gemini integration**: HTTP POST to
  `generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent`.
  The prompt asks for a single Roblox asset ID; the server extracts the first
  5+-digit number from the response.

---

## License

MIT
