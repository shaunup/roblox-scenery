# Glowing Pond – Twilight Environment (Roblox)

A peaceful Roblox 3-D scene centred on a **glowing cyan pond** under a deep **twilight night sky**. Players spawn on the bank and are free to walk around the entire area.

---

## Scene at a glance

| Feature | Details |
|---|---|
| **Sky** | `ClockTime` 20.2 – full night, 8 000 stars, oversized moon |
| **Atmosphere** | Thin deep-blue haze, preserves star visibility |
| **Post FX** | Strong BloomEffect (pond glow radiates outward), ColorCorrection (cool blue tint) |
| **Pond** | Terrain water basin + translucent neon disc surface + ring of 8 accent PointLights + shimmer ParticleEmitter |
| **Lily pads** | 7 glowing green neon pads floating on the pond |
| **Terrain** | Flat grassy ground, mud bank around pond, dirt path leading to the water, rolling hills closing in the horizon |
| **Trees** | ~24 hand-placed trees (trunk + sphere canopy) scattered around the area |
| **Rocks** | Clusters of rocks around the pond bank |
| **Reeds** | Thin reed-grass tufts at the waterline |
| **Fireflies** | Green/yellow ParticleEmitter sparkles drifting over the whole area |
| **Camera** | Standard Roblox follow-camera – full player freedom |

---

## File structure

```
default.project.json            ← Rojo project manifest
src/
  server/
    ScenerySetup.server.lua     ← Builds everything at run-time
  client/
    PlayerSetup.client.lua      ← Sets standard follow-camera
```

---

## How to use

### Option A – Rojo (recommended)

1. Install [Rojo v7](https://rojo.space/).
2. In the project root run:
   ```bash
   rojo serve default.project.json
   ```
3. Open Roblox Studio, connect via the Rojo plugin, then press **Play**.

### Option B – Manual paste into Studio

1. Open a blank place in Roblox Studio.
2. In `ServerScriptService` create a **Script**, paste `src/server/ScenerySetup.server.lua`.
3. Under `StarterPlayer > StarterPlayerScripts` create a **LocalScript**, paste `src/client/PlayerSetup.client.lua`.
4. Press **Play**.

---

## Customisation

| Goal | Where |
|---|---|
| Lighter / darker night | `Lighting.ClockTime` (try 19–21) |
| Pond glow colour | `glowDisc.Color` and `centreLight.Color` |
| Pond size | `POND_RADIUS` constant + matching FillCylinder calls |
| More / fewer trees | `treeSpots` table |
| Firefly density | `ff.Rate` value |
| Bloom intensity | `bloom.Intensity` and `bloom.Size` |
