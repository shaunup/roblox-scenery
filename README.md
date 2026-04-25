# Twilight Trail – Mindful Journey (Roblox)

A guided walking experience set in a twilight evening landscape. The player follows a zig-zag stone trail through two milestones, each with an interactive activity.

---

## Experience overview

```
[Spawn Platform]  →  zig-zag trail  →  [Breathing Circle]  →  trail continues  →  [Bonfire & Musician]
```

| Zone | What happens |
|---|---|
| **Spawn Platform** | Large welcome sign, the trail begins here |
| **Zig-zag stone trail** | 8-segment path with side torches lighting the way |
| **Breathing Circle** (Milestone 1) | ProximityPrompt activates a box-breathing exercise UI. Complete 4 rounds → earn a rising lantern |
| **Bonfire & Musician** (Milestone 2) | ProximityPrompt triggers a musician NPC dialog. Choose a music mood → audio plays client-side |

---

## Scene details

| Feature | Details |
|---|---|
| **Sky** | `ClockTime` 19.6, large moon, 6 000 stars, violet dusk `Atmosphere` |
| **Post-FX** | BloomEffect, SunRaysEffect, ColorCorrection (lavender night tint) |
| **Terrain** | Flat grass, rolling perimeter hills |
| **Trail** | 8 stone-slab segments in a zig-zag pattern, torches on alternating segments |
| **Breathing Circle** | Glowing cyan medallion, standing-stone ring, milestone sign |
| **Bonfire** | Log fire with PointLight, stone ring, log seats, musician porch with NPC and guitar |
| **Ambient** | ~20 trees, firefly `ParticleEmitter` across the whole area |

---

## File structure

```
default.project.json
src/
  server/
    ScenerySetup.server.lua      ← full environment built at run-time
    MilestoneManager.server.lua  ← ProximityPrompts, rewards, music routing
  client/
    BreathingUI.client.lua       ← animated box-breathing overlay + lantern toast
    MusicUI.client.lua           ← musician dialog + genre buttons + audio player
    PlayerSetup.client.lua       ← standard follow-camera
  shared/
    MusicLibrary.lua             ← genre key → Roblox audio asset ID map
```

---

## How to run

### Option A – Rojo (recommended)

```bash
rojo serve default.project.json
```
Connect in Roblox Studio via the Rojo plugin, then press **Play**.

### Option B – Manual Studio paste

| Script | Service | Type |
|---|---|---|
| `src/server/ScenerySetup.server.lua` | `ServerScriptService` | Script |
| `src/server/MilestoneManager.server.lua` | `ServerScriptService` | Script |
| `src/client/BreathingUI.client.lua` | `StarterGui` | LocalScript |
| `src/client/MusicUI.client.lua` | `StarterGui` | LocalScript |
| `src/client/PlayerSetup.client.lua` | `StarterPlayer > StarterPlayerScripts` | LocalScript |
| `src/shared/MusicLibrary.lua` | `ReplicatedStorage` | ModuleScript (name: `MusicLibrary`) |

Also create a **Folder** named `Remotes` in `ReplicatedStorage` containing these **RemoteEvent** objects:
- `OpenBreathing`
- `BreathingComplete`
- `AwardLantern`
- `OpenMusicDialog`
- `PlayMusic`

---

## Breathing exercise flow

```
Player walks to Breathing Circle
  → presses ProximityPrompt
  → BreathingUI appears
  → Box breathing: Inhale 4s | Hold 4s | Exhale 4s | Hold 4s  × 4 rounds
  → BreathingComplete fires to server
  → Server spawns a rising lantern at player position
  → AwardLantern fires to client → toast notification slides in
```

## Music flow

```
Player walks to Bonfire
  → presses ProximityPrompt ("Talk to the Musician")
  → Musician dialog slides up; NPC speaks 3 lines
  → Genre buttons shown: Lo-Fi, Ambient, Classical, Jazz, Nature, Upbeat, Meditation, Folk
  → Player clicks a genre → PlayMusic(genreKey) fires to server
  → Server looks up audio ID in MusicLibrary → fires PlayMusic(genreKey, audioId) back to client
  → Client creates a looping Sound in SoundService and plays it
  → Now-playing bar slides up at screen bottom with Stop button
```

---

## Customisation

| Goal | Where |
|---|---|
| Change sky time / colours | `Lighting.ClockTime` in `ScenerySetup` |
| Add more trail waypoints | `WAYPOINTS` table in `ScenerySetup` |
| Change breathing round count | `TOTAL_ROUNDS` in `BreathingUI` |
| Add music genres | `CATALOGUE` table in `MusicLibrary` |
| Change audio assets | Replace `id = "rbxassetid://..."` values in `MusicLibrary` |
| Move milestone positions | `BREATHING_POS` / `BONFIRE_POS` constants in `ScenerySetup` |
