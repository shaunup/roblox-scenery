--[[
═══════════════════════════════════════════════════════════════════════════════
  ModuleConfig.lua  –  THE ONLY FILE YOU NEED TO EDIT TO PLACE MODULES
═══════════════════════════════════════════════════════════════════════════════

  Each module is an independent station. Set its Position to wherever you
  want the centre of that station to sit in your map.

  The Direction field (Vector3) controls which way the arch / sign faces
  (usually pointing toward the path the player arrives from).

  Prerequisites: a list of module IDs that must be completed before this
  one becomes active. Leave as {} to make it always available.

  To DISABLE a module entirely, set Enabled = false.
  To make ALL modules accessible at once (no ordering), clear every
  Prerequisites table.

  TRIGGER_RADIUS: how many studs away the player must be to start a module.
═══════════════════════════════════════════════════════════════════════════════
]]

return {

    -- ── Global ────────────────────────────────────────────────────────────────
    TRIGGER_RADIUS = 10,    -- studs; touch-zone radius for every station

    -- ── Module definitions ────────────────────────────────────────────────────
    Modules = {

        Breathing = {
            Enabled      = true,
            -- Place the breathing arch near the start of your path
            Position     = Vector3.new(50, 1, -60),
            Direction    = Vector3.new(0, 0, -1),   -- faces north
            Prerequisites = {},                      -- first module – no prereqs
            Reward       = "Lantern",                -- awards one lantern on complete
        },

        Garden = {
            Enabled      = true,
            -- Put this near one of the benches on your grassy island
            Position     = Vector3.new(-10, 1, -20),
            Direction    = Vector3.new(0, 0, -1),
            Prerequisites = { "Breathing" },
            Reward       = "Lantern",
        },

        Jigsaw = {
            Enabled      = true,
            -- Another bench spot, or anywhere along the path
            Position     = Vector3.new(30, 1, -90),
            Direction    = Vector3.new(0, 0, -1),
            Prerequisites = { "Garden" },
            Reward       = "Lantern",
        },

        Lantern = {
            Enabled      = true,
            -- !! Set this to the dock/ledge coordinates in your lake !!
            -- Look at your map: the stone pier juts out at roughly these coords.
            -- In Studio: hover over the tip of the dock and read the coordinates.
            Position     = Vector3.new(0, 1, -160),   -- ledge over the lake
            Direction    = Vector3.new(0, 0, 1),       -- faces back toward shore
            Prerequisites = {},   -- can release any time you have ≥1 lantern
            Reward       = nil,
        },

    },
}
