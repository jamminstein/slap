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
  tick_speed = 1,       -- every beat
  ticks_per_bar = 2,    -- enough ticks for mutations to fire
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
    -- helper: pick random track
    -- (defined inline since lua closures capture upvalues)

    -- NEBULA: spectral clouds — patterns shift constantly but gently
    nebula = function(evo, tracks, progress, energy)
      local sc = tracks._scale_notes or {}
      local t_pick = math.random(1, 4)

      -- every tick: one note replacement somewhere (the key change!)
      if #sc > 0 then
        evo.pattern_mutate(tracks, t_pick, "replace_one", {scale_notes = sc})
      end

      -- 12% per tick: velocity micro-drift on a random track
      if math.random() < 0.12 then
        evo.pattern_mutate(tracks, math.random(1, 4), "velocity_drift")
      end

      -- 6% per tick: rotate a track by 1 (phase shift)
      if math.random() < 0.06 then
        evo.pattern_mutate(tracks, math.random(1, 4), "rotate", {n = ({1, -1})[math.random(2)]})
      end

      -- 3% per tick: transpose a track
      if math.random() < 0.03 then
        evo.pattern_mutate(tracks, math.random(1, 3), "shift",
          {interval = ({2, 5, 7, -5, -7, 12, -12})[math.random(7)]})
      end

      -- param drift
      evo.sweep_toward("t1_spread", 0.3 + energy * 0.5, 0.008)
      evo.sweep_toward("t1_brightness", 0.2 + energy * 0.5, 0.008)
      evo.sweep_toward("t3_morph", 0.2 + math.sin(progress * 3.7) * 0.3, 0.01)
      evo.sweep_toward("reverb_mix", 0.25 + energy * 0.3, 0.008)

      -- cutoffs wander
      for i = 1, 4 do
        local pre = "t" .. i .. "_"
        local ok, cur = pcall(function() return params:get(pre .. "cutoff") end)
        if ok then
          local drift = (math.random() - 0.5) * 0.02
          evo.sweep_toward(pre .. "cutoff", cur * (1 + drift), 0.008)
        end
      end
    end,

    -- CURRENT: polyrhythmic — tracks rotate at different rates
    current = function(evo, tracks, progress, energy)
      local sc = tracks._scale_notes or {}

      -- 15%: replace notes across tracks (keeps it moving)
      if math.random() < 0.15 and #sc > 0 then
        evo.pattern_mutate(tracks, math.random(1, 4), "replace_one", {scale_notes = sc})
      end

      -- different tracks rotate at different probabilities = polyrhythmic drift
      if math.random() < 0.08 then
        evo.pattern_mutate(tracks, 2, "rotate", {n = 1})  -- bass shifts right
      end
      if math.random() < 0.05 then
        evo.pattern_mutate(tracks, 3, "rotate", {n = -1}) -- melody shifts left
      end
      if math.random() < 0.06 then
        evo.pattern_mutate(tracks, 4, "rotate", {n = ({1, 2, -1})[math.random(3)]})
      end

      -- density changes
      if math.random() < 0.07 * energy then
        evo.pattern_mutate(tracks, math.random(1, 4), "thicken")
      end
      if math.random() < 0.04 then
        evo.pattern_mutate(tracks, math.random(1, 4), "velocity_drift")
      end

      -- 4%: harmonic shift (whole track transposes)
      if math.random() < 0.04 then
        evo.pattern_mutate(tracks, math.random(1, 3), "shift",
          {interval = ({2, 5, 7, -5, -7, 12})[math.random(6)]})
      end

      -- params
      local wave = math.sin(progress * 5.3) * 0.5 + 0.5
      evo.sweep_toward("t2_cutoff", 400 + (energy * wave) * 3000, 0.015)
      evo.sweep_toward("t2_accent", 0.3 + energy * wave * 0.5, 0.015)
      evo.sweep_toward("t3_cutoff", 3000 + energy * 5000, 0.01)
      evo.sweep_toward("t3_fmamt", energy * 0.35, 0.01)
    end,

    -- ERUPTION: aggressive — patterns get rewritten, engines switch, chaos
    eruption = function(evo, tracks, progress, energy)
      local sc = tracks._scale_notes or {}

      -- 10%: full pattern regeneration on one track (THIS is what keeps it fresh)
      if math.random() < 0.1 and #sc > 0 then
        local t = math.random(1, 4)
        local density = 0.4 + energy * 0.4
        evo.generate_pattern(tracks, t, sc, density, 0.5, 1.0)
      end

      -- 15%: replace individual notes
      if math.random() < 0.15 and #sc > 0 then
        evo.pattern_mutate(tracks, math.random(1, 4), "replace_one", {scale_notes = sc})
      end

      -- 8%: rotate patterns
      if math.random() < 0.08 then
        evo.pattern_mutate(tracks, math.random(1, 4), "rotate",
          {n = math.random(-3, 3)})
      end

      -- 6%: bzzt engine switch
      if math.random() < 0.06 then
        pcall(function() params:set("t4_engine", math.random(1, 4)) end)
      end

      -- 10%: accent random track
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, math.random(1, 4), "accent")
      end

      -- acid screams
      if math.random() < 0.12 then
        evo.sweep_toward("t2_cutoff", 2000 + math.random() * 6000, 0.06)
        evo.sweep_toward("t2_accent", 0.7 + math.random() * 0.3, 0.06)
      end
      evo.sweep_toward("t2_res", 0.6 + energy * 0.25, 0.02)
      evo.sweep_toward("t3_morph", 0.5 + energy * 0.4, 0.02)
      evo.sweep_toward("t3_fmamt", energy * 0.5, 0.02)
      evo.sweep_toward("t1_cutoff", 3000 + energy * 6000, 0.02)
      evo.sweep_toward("reverb_mix", 0.15, 0.02)
    end,

    -- HOLLOW: patterns dissolve — notes removed, velocities drop, spaces open
    hollow = function(evo, tracks, progress, energy)
      local sc = tracks._scale_notes or {}

      -- 10%: thin a track (remove notes)
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, math.random(1, 4), "thin")
      end

      -- 8%: ghost notes (reduce velocity)
      if math.random() < 0.08 then
        evo.pattern_mutate(tracks, math.random(1, 4), "ghost")
      end

      -- 5%: replace a note with something distant
      if math.random() < 0.05 and #sc > 0 then
        evo.pattern_mutate(tracks, math.random(1, 3), "replace_one", {scale_notes = sc})
      end

      -- 3%: dramatic octave shift on one track
      if math.random() < 0.03 then
        evo.pattern_mutate(tracks, math.random(1, 4), "shift",
          {interval = ({12, -12, 7, -7})[math.random(4)]})
      end

      -- filters close
      for i = 1, 4 do
        local pre = "t" .. i .. "_"
        local ok, cur = pcall(function() return params:get(pre .. "cutoff") end)
        if ok then evo.sweep_toward(pre .. "cutoff", cur * 0.995, 0.01) end
      end

      evo.sweep_toward("reverb_mix", 0.35 + (1 - energy) * 0.3, 0.01)
      evo.sweep_toward("reverb_room", 0.7 + (1 - energy) * 0.25, 0.008)
      evo.sweep_toward("t1_gate", 0.9, 0.01)
      evo.sweep_toward("t1_spread", 0.5 + (1 - energy) * 0.3, 0.008)
    end,

    -- SPORE: minimal — but notes still change when they appear
    spore = function(evo, tracks, progress, energy)
      local sc = tracks._scale_notes or {}

      -- keep thinning until sparse
      if math.random() < 0.08 then
        evo.pattern_mutate(tracks, math.random(2, 4), "thin")
      end

      -- but occasionally add one note back (the "spore")
      if math.random() < 0.05 then
        local t = ({1, 3})[math.random(2)]
        evo.pattern_mutate(tracks, t, "thicken", {count = 1})
      end

      -- 8%: change the notes that exist
      if math.random() < 0.08 and #sc > 0 then
        evo.pattern_mutate(tracks, math.random(1, 3), "replace_one", {scale_notes = sc})
      end

      -- velocity drift keeps micro-dynamics alive
      if math.random() < 0.1 then
        evo.pattern_mutate(tracks, math.random(1, 4), "velocity_drift")
      end

      -- 3%: transpose fragments
      if math.random() < 0.03 then
        evo.pattern_mutate(tracks, ({1, 3})[math.random(2)], "shift",
          {interval = ({5, 7, -5, 12})[math.random(4)]})
      end

      evo.sweep_toward("t2_gate", 0.2, 0.01)
      evo.sweep_toward("t4_gate", 0.1, 0.01)
      evo.sweep_toward("t1_gate", 0.85, 0.01)
      evo.sweep_toward("t1_cutoff", 1500 + energy * 2500, 0.008)
      evo.sweep_toward("reverb_mix", 0.45, 0.01)
      evo.sweep_toward("reverb_room", 0.85, 0.006)
    end,

    -- TIDE: everything moves in complex overlapping waves
    tide = function(evo, tracks, progress, energy)
      local sc = tracks._scale_notes or {}
      local wave1 = math.sin(progress * 4.1) * 0.3
      local wave2 = math.sin(progress * 7.3) * 0.15
      local wave3 = math.sin(progress * 2.7) * 0.2
      local composite = util.clamp(energy + wave1 + wave2 + wave3, 0.05, 0.95)

      -- pattern mutations follow the composite wave
      -- at peaks: thicken + accent. at troughs: thin + ghost
      if composite > 0.65 then
        if math.random() < 0.1 then
          evo.pattern_mutate(tracks, math.random(1, 4), "thicken")
        end
        if math.random() < 0.08 then
          evo.pattern_mutate(tracks, math.random(1, 4), "accent")
        end
      elseif composite < 0.35 then
        if math.random() < 0.08 then
          evo.pattern_mutate(tracks, math.random(1, 4), "thin")
        end
        if math.random() < 0.06 then
          evo.pattern_mutate(tracks, math.random(1, 4), "ghost")
        end
      end

      -- 10%: note replacements (constant melodic drift)
      if math.random() < 0.1 and #sc > 0 then
        evo.pattern_mutate(tracks, math.random(1, 4), "replace_one", {scale_notes = sc})
      end

      -- 5%: rotate for polyrhythmic phase shift
      if math.random() < 0.05 then
        evo.pattern_mutate(tracks, math.random(1, 4), "rotate",
          {n = ({1, -1, 2, -2})[math.random(4)]})
      end

      -- 3%: harmonic shift
      if math.random() < 0.03 then
        evo.pattern_mutate(tracks, math.random(1, 3), "shift",
          {interval = ({5, 7, -5, -7, 12})[math.random(5)]})
      end

      -- 5%: regenerate one track entirely at wave peak
      if composite > 0.8 and math.random() < 0.05 and #sc > 0 then
        local t = math.random(1, 4)
        evo.generate_pattern(tracks, t, sc, 0.4 + composite * 0.3, 0.4, 0.9)
      end

      -- cutoffs follow composite
      evo.sweep_toward("t1_cutoff", 1500 + composite * 5000, 0.01)
      evo.sweep_toward("t2_cutoff", 400 + composite * 3000, 0.01)
      evo.sweep_toward("t3_cutoff", 2000 + composite * 5000, 0.01)
      evo.sweep_toward("t4_cutoff", 3000 + composite * 5000, 0.01)
      evo.sweep_toward("t2_accent", 0.3 + composite * 0.5, 0.012)
      evo.sweep_toward("t3_morph", 0.2 + (energy + wave2) * 0.5, 0.01)
      evo.sweep_toward("t3_fmamt", composite * 0.3, 0.008)
      evo.sweep_toward("reverb_mix", 0.2 + (1 - composite) * 0.3, 0.008)
    end,
  },
}

return P
