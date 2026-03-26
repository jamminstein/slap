-- personalities.lua
-- 4 autonomous personalities for slap, one per Fred's Lab voice
-- each personality has a song form with sections, moods, and energy arcs

local util = require "util"

local P = {}

P.NAMES = {"MANTA", "ZKIT", "TOROID", "BZZT"}

-- ======================================================================
-- 1. MANTA — The Ambient Drifter
-- spectral pads that evolve through harmonic clouds
-- ======================================================================
P[1] = {
  name = "MANTA",
  desc = "ambient spectral drift",
  tick_speed = 2,
  ticks_per_bar = 2,
  focus_tracks = {1, 3},  -- manatee pads + tooro melody

  form = {
    {name = "EMERGE",   mood = "emerge",   bars = 12, energy = {0.1, 0.3}, transition = "fade"},
    {name = "FLOAT",    mood = "float",    bars = 16, energy = {0.3, 0.5}, transition = "fade"},
    {name = "BLOOM",    mood = "bloom",    bars = 12, energy = {0.5, 0.8}, transition = "push"},
    {name = "DISSOLVE", mood = "dissolve", bars = 8,  energy = {0.6, 0.1}, transition = "fade"},
  },

  intervals = {0, 2, 3, 5, 7, 10, 12, 14, 15, 19, 24},
  density_range = {0.2, 0.5},
  on_cycle = "vary",

  moods = {
    emerge = function(evo, tracks, progress, energy)
      evo.sweep_toward("t1_cutoff", 1500 + progress * 2000, 0.02)
      evo.sweep_toward("t1_spread", 0.2 + progress * 0.3, 0.02)
      evo.sweep_toward("t1_brightness", 0.3 + progress * 0.3, 0.02)
      evo.sweep_toward("reverb_mix", 0.4, 0.02)
      evo.sweep_toward("t3_cutoff", 2000, 0.01)
      if math.random() < 0.08 then
        evo.pattern_mutate(tracks, 1, "velocity_drift")
      end
    end,
    float = function(evo, tracks, progress, energy)
      evo.sweep_toward("t1_cutoff", 3000 + progress * 3000, 0.01)
      evo.sweep_toward("t1_spread", 0.5 + progress * 0.3, 0.01)
      evo.sweep_toward("t1_brightness", 0.5 + progress * 0.2, 0.01)
      evo.sweep_toward("t3_morph", 0.2 + progress * 0.4, 0.02)
      evo.sweep_toward("t3_fmamt", progress * 0.3, 0.02)
      if math.random() < 0.06 then
        evo.pattern_mutate(tracks, 3, "replace_one", {scale_notes = tracks._scale_notes or {}})
      end
      if math.random() < 0.04 then
        evo.pattern_mutate(tracks, 1, "shift", {interval = ({5, 7, 12})[math.random(3)]})
      end
    end,
    bloom = function(evo, tracks, progress, energy)
      evo.sweep_toward("t1_cutoff", 6000 + progress * 4000, 0.02)
      evo.sweep_toward("t1_brightness", 0.8, 0.02)
      evo.sweep_toward("t1_spread", 0.8, 0.02)
      evo.sweep_toward("t3_cutoff", 5000 + progress * 3000, 0.02)
      evo.sweep_toward("t3_morph", 0.6 + progress * 0.3, 0.02)
      evo.sweep_toward("reverb_mix", 0.5 + progress * 0.2, 0.01)
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, 3, "thicken")
      end
      if math.random() < 0.05 then
        evo.pattern_mutate(tracks, 1, "thicken")
      end
    end,
    dissolve = function(evo, tracks, progress, energy)
      evo.sweep_toward("t1_cutoff", 2000 - progress * 1000, 0.03)
      evo.sweep_toward("t1_brightness", 0.3, 0.03)
      evo.sweep_toward("t1_spread", 0.2, 0.03)
      evo.sweep_toward("t3_cutoff", 2000, 0.02)
      evo.sweep_toward("reverb_mix", 0.6, 0.02)
      if math.random() < 0.15 then
        evo.pattern_mutate(tracks, 3, "thin")
      end
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, 1, "thin")
      end
    end,
  },
}

-- ======================================================================
-- 2. ZKIT — The Acid Machine
-- squelchy bass patterns that build and strip
-- ======================================================================
P[2] = {
  name = "ZKIT",
  desc = "acid bass machine",
  tick_speed = 1,
  ticks_per_bar = 2,
  focus_tracks = {2, 4},  -- zekit bass + buzzzy percussion

  form = {
    {name = "PULSE",  mood = "pulse",  bars = 8,  energy = {0.3, 0.4}, transition = "fade"},
    {name = "BUILD",  mood = "build",  bars = 16, energy = {0.4, 0.7}, transition = "push"},
    {name = "ACID",   mood = "acid",   bars = 12, energy = {0.8, 1.0}, transition = "cut"},
    {name = "STRIP",  mood = "strip",  bars = 8,  energy = {0.5, 0.3}, transition = "pull"},
    {name = "ACID II",mood = "acid",   bars = 12, energy = {0.85, 1.0},transition = "cut"},
    {name = "COOL",   mood = "cool",   bars = 8,  energy = {0.4, 0.15},transition = "fade"},
  },

  intervals = {0, 3, 5, 7, 10, 12, -5, -7, -12},
  density_range = {0.5, 0.9},
  on_cycle = "vary",

  moods = {
    pulse = function(evo, tracks, progress, energy)
      evo.sweep_toward("t2_cutoff", 400 + progress * 200, 0.02)
      evo.sweep_toward("t2_res", 0.6, 0.02)
      evo.sweep_toward("t2_accent", 0.5, 0.03)
      evo.sweep_toward("t4_cutoff", 5000, 0.02)
      if math.random() < 0.08 then
        evo.pattern_mutate(tracks, 4, "velocity_drift")
      end
    end,
    build = function(evo, tracks, progress, energy)
      evo.sweep_toward("t2_cutoff", 500 + progress * 2000, 0.02)
      evo.sweep_toward("t2_res", 0.6 + progress * 0.2, 0.02)
      evo.sweep_toward("t2_accent", 0.5 + progress * 0.4, 0.02)
      evo.sweep_toward("t4_cutoff", 5000 + progress * 3000, 0.02)
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, 2, "accent")
      end
      if math.random() < 0.08 then
        evo.pattern_mutate(tracks, 4, "thicken")
      end
    end,
    acid = function(evo, tracks, progress, energy)
      evo.sweep_toward("t2_cutoff", 2000 + progress * 4000, 0.03)
      evo.sweep_toward("t2_res", 0.85, 0.03)
      evo.sweep_toward("t2_accent", 0.95, 0.03)
      evo.sweep_toward("t2_gate", 0.3, 0.02)
      evo.sweep_toward("t4_cutoff", 8000, 0.02)
      if math.random() < 0.12 then
        evo.pattern_mutate(tracks, 2, "replace_one", {scale_notes = tracks._scale_notes or {}})
      end
      if math.random() < 0.06 then
        evo.pattern_mutate(tracks, 2, "rotate", {n = 1})
      end
    end,
    strip = function(evo, tracks, progress, energy)
      evo.sweep_toward("t2_cutoff", 800, 0.03)
      evo.sweep_toward("t2_res", 0.5, 0.03)
      evo.sweep_toward("t2_accent", 0.4, 0.03)
      if math.random() < 0.15 then
        evo.pattern_mutate(tracks, 2, "thin")
      end
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, 4, "thin")
      end
    end,
    cool = function(evo, tracks, progress, energy)
      evo.sweep_toward("t2_cutoff", 400, 0.03)
      evo.sweep_toward("t2_res", 0.4, 0.03)
      evo.sweep_toward("t2_accent", 0.3, 0.03)
      evo.sweep_toward("reverb_mix", 0.35, 0.02)
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, 2, "ghost")
      end
    end,
  },
}

-- ======================================================================
-- 3. TOROID — The Melodic Explorer
-- waveform morphing arpeggios that shift harmonically
-- ======================================================================
P[3] = {
  name = "TOROID",
  desc = "melodic morph explorer",
  tick_speed = 1,
  ticks_per_bar = 2,
  focus_tracks = {3, 1},  -- tooro melody + manatee pads

  form = {
    {name = "DRIFT",   mood = "drift",   bars = 10, energy = {0.2, 0.4}, transition = "fade"},
    {name = "WEAVE",   mood = "weave",   bars = 16, energy = {0.4, 0.7}, transition = "push"},
    {name = "SOAR",    mood = "soar",    bars = 12, energy = {0.7, 0.9}, transition = "push"},
    {name = "SCATTER", mood = "scatter", bars = 8,  energy = {0.6, 0.3}, transition = "fade"},
    {name = "RETURN",  mood = "return",  bars = 10, energy = {0.3, 0.5}, transition = "fade"},
  },

  intervals = {0, 2, 4, 5, 7, 9, 11, 12, 14, 16, 19},
  density_range = {0.4, 0.8},
  on_cycle = "vary",

  moods = {
    drift = function(evo, tracks, progress, energy)
      evo.sweep_toward("t3_morph", 0.2 + progress * 0.2, 0.02)
      evo.sweep_toward("t3_fmamt", 0.1, 0.02)
      evo.sweep_toward("t3_cutoff", 3000 + progress * 1500, 0.02)
      evo.sweep_toward("t3_lfoDepth", 0.1 + progress * 0.1, 0.02)
      if math.random() < 0.06 then
        evo.pattern_mutate(tracks, 3, "velocity_drift")
      end
    end,
    weave = function(evo, tracks, progress, energy)
      evo.sweep_toward("t3_morph", 0.3 + progress * 0.3, 0.02)
      evo.sweep_toward("t3_fmamt", progress * 0.4, 0.02)
      evo.sweep_toward("t3_cutoff", 4000 + progress * 4000, 0.02)
      evo.sweep_toward("t3_lfoRate", 2 + progress * 4, 0.02)
      evo.sweep_toward("t1_cutoff", 3000 + progress * 2000, 0.01)
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, 3, "replace_one", {scale_notes = tracks._scale_notes or {}})
      end
      if math.random() < 0.05 then
        evo.pattern_mutate(tracks, 3, "thicken")
      end
    end,
    soar = function(evo, tracks, progress, energy)
      evo.sweep_toward("t3_morph", 0.7 + progress * 0.2, 0.02)
      evo.sweep_toward("t3_fmamt", 0.4 + progress * 0.3, 0.02)
      evo.sweep_toward("t3_cutoff", 8000 + progress * 4000, 0.02)
      evo.sweep_toward("t3_res", 0.4 + progress * 0.2, 0.02)
      evo.sweep_toward("reverb_mix", 0.4 + progress * 0.2, 0.01)
      if math.random() < 0.08 then
        evo.pattern_mutate(tracks, 3, "shift", {interval = ({2, 5, 7})[math.random(3)]})
      end
    end,
    scatter = function(evo, tracks, progress, energy)
      evo.sweep_toward("t3_morph", 0.5, 0.03)
      evo.sweep_toward("t3_fmamt", 0.2, 0.03)
      if math.random() < 0.15 then
        evo.pattern_mutate(tracks, 3, "rotate", {n = math.random(-2, 2)})
      end
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, 3, "thin")
      end
    end,
    ["return"] = function(evo, tracks, progress, energy)
      evo.sweep_toward("t3_morph", 0.3, 0.02)
      evo.sweep_toward("t3_fmamt", 0.15, 0.02)
      evo.sweep_toward("t3_cutoff", 3500, 0.02)
      evo.sweep_toward("reverb_mix", 0.3, 0.02)
    end,
  },
}

-- ======================================================================
-- 4. BZZT — The Rhythm Architect
-- multi-engine percussion that builds and breaks
-- ======================================================================
P[4] = {
  name = "BZZT",
  desc = "digital rhythm architect",
  tick_speed = 1,
  ticks_per_bar = 2,
  focus_tracks = {4, 2},  -- buzzzy percussion + zekit bass

  form = {
    {name = "CLICK",  mood = "click",  bars = 8,  energy = {0.2, 0.4}, transition = "fade"},
    {name = "GROOVE", mood = "groove", bars = 16, energy = {0.4, 0.7}, transition = "push"},
    {name = "SMASH",  mood = "smash",  bars = 12, energy = {0.8, 1.0}, transition = "cut"},
    {name = "BREAK",  mood = "break",  bars = 6,  energy = {0.5, 0.3}, transition = "cut"},
    {name = "SMASH2", mood = "smash",  bars = 10, energy = {0.85, 1.0},transition = "cut"},
    {name = "FADE",   mood = "fade",   bars = 8,  energy = {0.4, 0.1}, transition = "fade"},
  },

  intervals = {0, 5, 7, 12, 24, 36, -12, -24},
  density_range = {0.4, 0.85},
  on_cycle = "vary",

  moods = {
    click = function(evo, tracks, progress, energy)
      evo.sweep_toward("t4_cutoff", 4000 + progress * 2000, 0.02)
      evo.sweep_toward("t4_gate", 0.15, 0.03)
      if math.random() < 0.08 then
        evo.pattern_mutate(tracks, 4, "velocity_drift")
      end
    end,
    groove = function(evo, tracks, progress, energy)
      evo.sweep_toward("t4_cutoff", 5000 + progress * 3000, 0.02)
      evo.sweep_toward("t2_cutoff", 500 + progress * 800, 0.02)
      evo.sweep_toward("t2_accent", 0.5 + progress * 0.3, 0.02)
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, 4, "thicken")
      end
      if math.random() < 0.08 then
        evo.pattern_mutate(tracks, 4, "accent")
      end
    end,
    smash = function(evo, tracks, progress, energy)
      evo.sweep_toward("t4_cutoff", 10000, 0.03)
      evo.sweep_toward("t4_gate", 0.1 + progress * 0.15, 0.02)
      evo.sweep_toward("t2_cutoff", 1500 + progress * 3000, 0.02)
      evo.sweep_toward("t2_res", 0.7 + progress * 0.15, 0.02)
      if math.random() < 0.12 then
        evo.pattern_mutate(tracks, 4, "replace_one", {scale_notes = tracks._scale_notes or {}})
      end
      if math.random() < 0.06 then
        evo.pattern_mutate(tracks, 4, "rotate", {n = 1})
      end
    end,
    ["break"] = function(evo, tracks, progress, energy)
      if math.random() < 0.2 then
        evo.pattern_mutate(tracks, 4, "thin")
      end
      evo.sweep_toward("t4_cutoff", 5000, 0.03)
      evo.sweep_toward("t2_cutoff", 600, 0.03)
    end,
    fade = function(evo, tracks, progress, energy)
      evo.sweep_toward("t4_cutoff", 3000 - progress * 1500, 0.03)
      evo.sweep_toward("t2_cutoff", 400, 0.03)
      evo.sweep_toward("reverb_mix", 0.4, 0.02)
      if math.random() < 0.15 then
        evo.pattern_mutate(tracks, 4, "thin")
      end
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, 2, "ghost")
      end
    end,
  },
}

-- ======================================================================
-- 5. ATEMPORAL — The Formless
-- no fixed bar grid. drunk-walk energy, stochastic mutations,
-- sections that stretch, skip, and bleed into each other.
-- touches ALL voices simultaneously with slow continuous drift.
-- ======================================================================
P[5] = {
  name = "ATEMPORAL",
  desc = "formless drift",
  tick_speed = 2,       -- slower ticks (half notes)
  ticks_per_bar = 1,    -- sparse timing
  focus_tracks = {1, 2, 3, 4},
  atemporal = true,     -- flag for song engine: drunk walk + section stretch
  on_cycle = "vary",

  intervals = {0, 2, 3, 5, 7, 10, 12, 14, 19, 24, -5, -7, -12},
  density_range = {0.25, 0.65},

  form = {
    -- long, overlapping moods with wide energy ranges
    -- bars_range gives the song engine a randomization window
    {name = "NEBULA",   mood = "nebula",   bars = 48, bars_range = {32, 80},  energy = {0.15, 0.5},  transition = "fade"},
    {name = "CURRENT",  mood = "current",  bars = 36, bars_range = {24, 64},  energy = {0.3, 0.75},  transition = "fade"},
    {name = "ERUPTION", mood = "eruption", bars = 28, bars_range = {16, 48},  energy = {0.5, 0.95},  transition = "fade"},
    {name = "HOLLOW",   mood = "hollow",   bars = 56, bars_range = {40, 96},  energy = {0.6, 0.1},   transition = "fade"},
    {name = "SPORE",    mood = "spore",    bars = 44, bars_range = {28, 72},  energy = {0.1, 0.45},  transition = "fade"},
    {name = "TIDE",     mood = "tide",     bars = 40, bars_range = {24, 80},  energy = {0.2, 0.7},   transition = "fade"},
  },

  moods = {
    -- NEBULA: slow spectral clouds, everything drifts gently
    nebula = function(evo, tracks, progress, energy)
      -- all cutoffs drift randomly
      for i = 1, 4 do
        local pre = "t" .. i .. "_"
        local drift = (math.random() - 0.5) * 0.008
        local ok, cur = pcall(function() return params:get(pre .. "cutoff") end)
        if ok then evo.sweep_toward(pre .. "cutoff", cur * (1 + drift), 0.003) end
      end

      -- manta: wide, bright, slow evolving
      evo.sweep_toward("t1_spread", 0.3 + energy * 0.5, 0.004)
      evo.sweep_toward("t1_brightness", 0.2 + energy * 0.5, 0.004)
      evo.sweep_toward("t1_gate", 0.8 + energy * 0.15, 0.005)

      -- toroid: gentle morph movement
      evo.sweep_toward("t3_morph", 0.2 + math.sin(progress * 3.7) * 0.3, 0.006)
      evo.sweep_toward("t3_lfoDepth", energy * 0.25, 0.005)

      -- reverb breathes with energy
      evo.sweep_toward("reverb_mix", 0.25 + energy * 0.3, 0.005)

      -- rare mutations (3% per tick = very sparse at tick_speed=2)
      if math.random() < 0.03 then
        local t = math.random(1, 4)
        evo.pattern_mutate(tracks, t, "velocity_drift")
      end
      if math.random() < 0.015 then
        local t = math.random(1, 4)
        evo.pattern_mutate(tracks, t, "replace_one",
          {scale_notes = tracks._scale_notes or {}})
      end
    end,

    -- CURRENT: things start moving, polyrhythmic feel emerges
    current = function(evo, tracks, progress, energy)
      -- zkit filter opens in waves
      local wave = math.sin(progress * 5.3) * 0.5 + 0.5
      evo.sweep_toward("t2_cutoff", 400 + (energy * wave) * 3000, 0.008)
      evo.sweep_toward("t2_accent", 0.3 + energy * wave * 0.5, 0.008)
      evo.sweep_toward("t2_res", 0.4 + energy * 0.3, 0.006)

      -- toroid melodic shifts
      evo.sweep_toward("t3_cutoff", 3000 + energy * 5000, 0.006)
      evo.sweep_toward("t3_fmamt", energy * 0.35, 0.005)

      -- bzzt gains density
      if math.random() < 0.05 * energy then
        evo.pattern_mutate(tracks, 4, "thicken")
      end
      if math.random() < 0.04 then
        evo.pattern_mutate(tracks, math.random(2, 3), "replace_one",
          {scale_notes = tracks._scale_notes or {}})
      end

      -- occasional harmonic shift (whole pattern transposes)
      if math.random() < 0.01 then
        local t = math.random(1, 3)
        evo.pattern_mutate(tracks, t, "shift",
          {interval = ({2, 5, 7, -5, -7, 12})[math.random(6)]})
      end
    end,

    -- ERUPTION: intense but unpredictable, not a wall of sound
    eruption = function(evo, tracks, progress, energy)
      -- acid screams in bursts
      if math.random() < 0.1 then
        evo.sweep_toward("t2_cutoff", 2000 + math.random() * 6000, 0.04)
        evo.sweep_toward("t2_accent", 0.7 + math.random() * 0.3, 0.04)
      end
      evo.sweep_toward("t2_res", 0.6 + energy * 0.25, 0.01)

      -- bzzt: engine switches randomly
      if math.random() < 0.03 then
        pcall(function()
          params:set("t4_engine", math.random(1, 4))
        end)
      end
      evo.sweep_toward("t4_cutoff", 5000 + energy * 5000, 0.01)

      -- toroid: high morph + FM
      evo.sweep_toward("t3_morph", 0.5 + energy * 0.4, 0.01)
      evo.sweep_toward("t3_fmamt", energy * 0.5, 0.01)

      -- manta: filters open wide
      evo.sweep_toward("t1_cutoff", 3000 + energy * 6000, 0.01)
      evo.sweep_toward("t1_brightness", 0.6 + energy * 0.3, 0.01)

      -- aggressive mutations
      if math.random() < 0.08 then
        evo.pattern_mutate(tracks, math.random(1,4), "accent")
      end
      if math.random() < 0.04 then
        evo.pattern_mutate(tracks, math.random(1,4), "rotate",
          {n = math.random(-3, 3)})
      end

      -- reverb pulls back during intensity
      evo.sweep_toward("reverb_mix", 0.15, 0.01)
    end,

    -- HOLLOW: everything empties out slowly, not linearly
    hollow = function(evo, tracks, progress, energy)
      -- thin patterns stochastically
      if math.random() < 0.06 then
        evo.pattern_mutate(tracks, math.random(1, 4), "thin")
      end
      if math.random() < 0.04 then
        evo.pattern_mutate(tracks, math.random(1, 4), "ghost")
      end

      -- filters drift closed
      for i = 1, 4 do
        local pre = "t" .. i .. "_"
        local ok, cur = pcall(function() return params:get(pre .. "cutoff") end)
        if ok then evo.sweep_toward(pre .. "cutoff", cur * 0.997, 0.005) end
      end

      -- reverb expands as sounds recede
      evo.sweep_toward("reverb_mix", 0.35 + (1 - energy) * 0.3, 0.006)
      evo.sweep_toward("reverb_room", 0.7 + (1 - energy) * 0.25, 0.004)

      -- manta becomes the anchor
      evo.sweep_toward("t1_gate", 0.9, 0.005)
      evo.sweep_toward("t1_spread", 0.5 + (1 - energy) * 0.3, 0.004)

      -- rare surprise: one voice gets a dramatic shift
      if math.random() < 0.008 then
        local t = math.random(1, 4)
        evo.pattern_mutate(tracks, t, "shift",
          {interval = ({12, -12, 7, -7})[math.random(4)]})
      end
    end,

    -- SPORE: minimal seeds, quiet potential
    spore = function(evo, tracks, progress, energy)
      -- keep things sparse
      evo.sweep_toward("t2_gate", 0.2, 0.005)
      evo.sweep_toward("t4_gate", 0.1, 0.005)
      evo.sweep_toward("t1_gate", 0.85, 0.005)

      -- manta pad: the main voice
      evo.sweep_toward("t1_cutoff", 1500 + energy * 2500, 0.004)
      evo.sweep_toward("t1_spread", 0.5 + energy * 0.2, 0.003)

      -- reverb: vast
      evo.sweep_toward("reverb_mix", 0.45, 0.005)
      evo.sweep_toward("reverb_room", 0.85, 0.003)

      -- toroid: quiet melodic fragments
      evo.sweep_toward("t3_cutoff", 2000 + energy * 2000, 0.004)
      evo.sweep_toward("t3_morph", 0.15 + energy * 0.2, 0.003)

      -- very rare: a new note appears
      if math.random() < 0.02 then
        local t = ({1, 3})[math.random(2)]
        evo.pattern_mutate(tracks, t, "thicken", {count = 1})
      end
      -- even rarer: velocity drift adds micro-dynamics
      if math.random() < 0.04 then
        evo.pattern_mutate(tracks, math.random(1, 4), "velocity_drift")
      end
    end,

    -- TIDE: long slow waves of energy, polyrhythmic undulation
    tide = function(evo, tracks, progress, energy)
      -- multiple sine waves at different rates create complex energy shape
      local wave1 = math.sin(progress * 4.1) * 0.3
      local wave2 = math.sin(progress * 7.3) * 0.15
      local wave3 = math.sin(progress * 2.7) * 0.2
      local composite = energy + wave1 + wave2 + wave3
      composite = util.clamp(composite, 0.05, 0.95)

      -- all cutoffs follow the composite wave
      evo.sweep_toward("t1_cutoff", 1500 + composite * 5000, 0.006)
      evo.sweep_toward("t2_cutoff", 400 + composite * 3000, 0.006)
      evo.sweep_toward("t3_cutoff", 2000 + composite * 5000, 0.006)
      evo.sweep_toward("t4_cutoff", 3000 + composite * 5000, 0.006)

      -- accent follows wave
      evo.sweep_toward("t2_accent", 0.3 + composite * 0.5, 0.008)

      -- morph follows a different phase
      evo.sweep_toward("t3_morph", 0.2 + (energy + wave2) * 0.5, 0.006)
      evo.sweep_toward("t3_fmamt", composite * 0.3, 0.005)

      -- density follows composite: thick at peaks, thin at troughs
      if composite > 0.7 and math.random() < 0.05 then
        evo.pattern_mutate(tracks, math.random(1, 4), "thicken")
      elseif composite < 0.3 and math.random() < 0.05 then
        evo.pattern_mutate(tracks, math.random(1, 4), "thin")
      end

      -- reverb inverse of energy
      evo.sweep_toward("reverb_mix", 0.2 + (1 - composite) * 0.3, 0.005)

      -- occasional pattern rotation for polyrhythmic feel
      if math.random() < 0.02 then
        local t = math.random(1, 4)
        evo.pattern_mutate(tracks, t, "rotate", {n = ({1, -1, 2, -2})[math.random(4)]})
      end
    end,
  },
}

return P
