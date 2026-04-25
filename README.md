# Flying Lanterns – Twilight Scenery (Roblox)

A complete Roblox 3-D scene featuring **38 rising sky lanterns** set against a **twilight mountain landscape** with a dimming golden-hour sunset, a reflective lake, stars, fireflies, and a stone viewing platform.

---

## Scene overview

| Feature | Details |
|---|---|
| **Lighting** | `ClockTime` ≈ 18.8 (late dusk), warm amber fog, purple-shadow ambient |
| **Atmosphere** | Haze 2.6, orange colour scatter, violet decay, gentle glare |
| **Sky** | 5 000 stars, oversized moon, built-in Roblox sky texture |
| **Post-processing** | BloomEffect (glow on lanterns), SunRaysEffect, ColourCorrection |
| **Terrain** | Procedural mountain ridges (3 ranges), snow caps, valley floor, water lake |
| **Treeline** | Cosmetic cylinder forest at mountain bases |
| **Lanterns** | 38 physics-driven rising lanterns with Fire particles and PointLight glow |
| **Decorations** | Stone viewing platform, wooden poles with red hanging lanterns |
| **Particles** | Firefly/sparkle ParticleEmitter across the valley floor |
| **Camera** | Cinematic orbit intro; exits to standard Roblox camera on input |

---

## File structure

```
default.project.json          ← Rojo project manifest
src/
  server/
    ScenerySetup.server.lua   ← Main scene builder (lighting, terrain, lanterns)
  client/
    CameraScript.client.lua   ← Cinematic orbit intro camera
  shared/
    LanternTemplate.lua       ← Shared lantern colour palette & constants
```

---

## How to use

### Option A – Rojo (recommended)

1. Install [Rojo](https://rojo.space/) (v7+).
2. Clone this repo and run:
   ```bash
   rojo serve default.project.json
   ```
3. Open **Roblox Studio**, install the [Rojo Studio plugin](https://rojo.space/docs/v7/installation/), and click **Connect**.
4. Press **Play** – the scenery builds automatically at run-time.

### Option B – Manual Studio import

1. Open a blank Roblox Studio place.
2. Create a `Script` inside `ServerScriptService`, paste the contents of `src/server/ScenerySetup.server.lua`.
3. Create a `LocalScript` inside `StarterPlayerScripts`, paste `src/client/CameraScript.client.lua`.
4. Create a `ModuleScript` inside `ReplicatedStorage` named `LanternTemplate`, paste `src/shared/LanternTemplate.lua`.
5. Press **Play**.

---

## Customisation tips

| What to change | Where |
|---|---|
| Time of day / sun angle | `Lighting.ClockTime` in `ScenerySetup` |
| Number of lanterns | `LANTERN_COUNT` constant |
| Lantern rise speed | `LANTERN_RISE_SPEED` constant |
| Mountain shapes & positions | `buildMountainRidge(...)` calls |
| Lantern colours | `LanternTemplate.BodyColours` table |
| Firefly particle rate | `particles.Rate` in `buildDecorations()` |
| Clock advance speed | `Lighting.ClockTime = t + 0.005` loop tick |

---

## Performance notes

- All lantern motion runs on the **server** via `RunService.Heartbeat` coroutines. For large player counts consider moving animation to a `LocalScript` using a `RemoteEvent` to seed initial positions.
- `Workspace.StreamingEnabled` is set to `false` by default; enable it for large maps.
- Terrain generation runs once at startup and is static thereafter.
